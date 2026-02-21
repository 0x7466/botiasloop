# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Channels do
  let(:config) do
    Botiasloop::Config.new({
      "channels" => {
        "test_channel_one" => {"token" => "token1"},
        "test_channel_two" => {"token" => "token2"},
        "telegram" => {"bot_token" => "test-token"},
        "failing_channel" => {"token" => "token3"}
      },
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  before do
    # Clear singleton registry before each test
    described_class.instance_variable_set(:@registry, nil)
  end

  # Create test channel classes
  let(:channel_one_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :test_channel_one
      requires_config :token

      attr_reader :started, :stopped

      def initialize(config)
        super
        @started = false
        @stopped = false
        @running = false
      end

      def start
        @started = true
        @running = true
      end

      def stop
        @stopped = true
        @running = false
      end

      def running?
        @running
      end

      def process_message(source_id, content, metadata = {})
        # noop
      end
    end
  end

  let(:channel_two_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :test_channel_two
      requires_config :token

      attr_reader :started, :stopped

      def initialize(config)
        super
        @started = false
        @stopped = false
        @running = false
      end

      def start
        @started = true
        @running = true
      end

      def stop
        @stopped = true
        @running = false
      end

      def running?
        @running
      end

      def process_message(source_id, content, metadata = {})
        # noop
      end
    end
  end

  let(:failing_channel_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :failing_channel
      requires_config :token

      def initialize(config)
        super
      end

      def start
        raise Botiasloop::Error, "Failed to start channel"
      end

      def stop
        # noop
      end

      def running?
        false
      end

      def process_message(source_id, content, metadata = {})
        # noop
      end
    end
  end

  let(:missing_config_channel_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :missing_config_channel
      requires_config :unconfigured_key

      def initialize(config)
        super
      end

      def start
        @running = true
      end

      def stop
        @running = false
      end

      def running?
        @running ||= false
      end

      def process_message(source_id, content, metadata = {})
        # noop
      end
    end
  end

  describe ".register" do
    it "registers a channel class" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)

      expect(registry[:test_channel_one]).to eq(channel_one_class)
    end

    it "allows registering multiple channels" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(channel_two_class)

      expect(registry.names).to contain_exactly(:test_channel_one, :test_channel_two)
    end

    it "overwrites existing registration with same name" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)

      new_class = Class.new(channel_one_class) do
        # Copy channel_name from parent class
        channel_name :test_channel_one
      end
      registry.register(new_class)

      expect(registry[:test_channel_one]).to eq(new_class)
    end
  end

  describe ".auto_start" do
    it "starts all registered channels" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(channel_two_class)

      registry.auto_start(config)

      channel_one = registry.instances[:test_channel_one]
      channel_two = registry.instances[:test_channel_two]

      expect(channel_one.started).to be true
      expect(channel_two.started).to be true
    end

    it "stores channel instances" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.auto_start(config)

      expect(registry.instances[:test_channel_one]).to be_a(channel_one_class)
    end

    it "skips channels with missing required configuration" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(missing_config_channel_class)

      # Config with only channel_one configured
      partial_config = Botiasloop::Config.new({
        "channels" => {
          "test_channel_one" => {"token" => "token1"}
        },
        "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
      })

      registry.auto_start(partial_config)

      expect(registry.instances).to have_key(:test_channel_one)
      expect(registry.instances).not_to have_key(:missing_config_channel)
    end

    it "exits on channel startup failure (non-config errors)" do
      registry = described_class::Registry.new
      registry.register(failing_channel_class)

      expect { registry.auto_start(config) }.to raise_error(Botiasloop::Error, /Failed to start/)
    end

    it "stops previously started channels on failure" do
      # Create a channel class that tracks if stop was called
      stopped_channels = []
      trackable_class = Class.new(channel_one_class) do
        channel_name :test_channel_one

        define_method(:stop) do
          stopped_channels << self
          super()
        end
      end

      registry = described_class::Registry.new
      registry.register(trackable_class)
      registry.register(failing_channel_class)

      begin
        registry.auto_start(config)
      rescue Botiasloop::Error
        # Expected
      end

      # Verify that the first channel was stopped due to the failure
      expect(stopped_channels.length).to eq(1)
      expect(stopped_channels.first).to be_a(trackable_class)
    end
  end

  describe ".stop_all" do
    it "stops all running channels" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(channel_two_class)

      registry.auto_start(config)

      # Get references before stop_all clears instances
      channel_one = registry.instances[:test_channel_one]
      channel_two = registry.instances[:test_channel_two]

      registry.stop_all

      expect(channel_one.stopped).to be true
      expect(channel_two.stopped).to be true
    end

    it "handles channels that are not running" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      # Don't start, just stop

      expect { registry.stop_all }.not_to raise_error
    end
  end

  describe ".running?" do
    it "returns false when no channels are running" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)

      expect(registry.running?).to be false
    end

    it "returns true when any channel is running" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.auto_start(config)

      expect(registry.running?).to be true
    end

    it "returns false when all channels are stopped" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.auto_start(config)
      registry.stop_all

      expect(registry.running?).to be false
    end
  end

  describe ".[]" do
    it "returns channel class by name" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)

      expect(registry[:test_channel_one]).to eq(channel_one_class)
    end

    it "returns nil for unregistered channel" do
      registry = described_class::Registry.new

      expect(registry[:unknown]).to be_nil
    end
  end

  describe ".names" do
    it "returns empty array when no channels registered" do
      registry = described_class::Registry.new
      expect(registry.names).to be_empty
    end

    it "returns all registered channel names" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(channel_two_class)

      expect(registry.names).to contain_exactly(:test_channel_one, :test_channel_two)
    end
  end

  describe ".instances" do
    it "returns empty hash before auto_start" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)

      expect(registry.instances).to be_empty
    end

    it "returns started channel instances" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.auto_start(config)

      expect(registry.instances.keys).to contain_exactly(:test_channel_one)
      expect(registry.instances[:test_channel_one]).to be_a(channel_one_class)
    end
  end

  describe "module-level access" do
    before do
      # Clear any previously registered channels
      described_class.instance_variable_set(:@registry, nil)
    end

    it "provides singleton registry access" do
      expect(described_class.registry).to be_a(described_class::Registry)
    end

    it "returns same registry on multiple calls" do
      registry1 = described_class.registry
      registry2 = described_class.registry

      expect(registry1).to be(registry2)
    end
  end
end
