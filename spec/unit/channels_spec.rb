# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Channels do
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

  before do
    # Clear singleton registry before each test
    described_class.instance_variable_set(:@registry, nil)
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

  describe ".deregister" do
    it "removes a registered channel" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.deregister(:test_channel_one)

      expect(registry[:test_channel_one]).to be_nil
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

  describe ".clear" do
    it "removes all registered channels" do
      registry = described_class::Registry.new
      registry.register(channel_one_class)
      registry.register(channel_two_class)

      registry.clear

      expect(registry.names).to be_empty
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
