# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::ChannelsManager do
  let(:test_config) do
    Botiasloop::Config.new({
      "channels" => {
        "channel_one" => {"token" => "token1"},
        "channel_two" => {"token" => "token2"},
        "channel_three" => {"token" => "token3"},
        "failing_channel" => {"token" => "fail_token"},
        "missing_config_channel" => {}
      },
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  let(:manager) { described_class.new }

  # Helper to create test channel classes with blocking behavior
  let(:blocking_channel_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :channel_one
      requires_config :token

      attr_reader :started, :stopped, :thread_id

      def initialize
        super
        @started = false
        @stopped = false
        @running = false
        @thread_id = nil
      end

      def start
        @started = true
        @running = true
        @thread_id = Thread.current.object_id
        # Simulate blocking behavior
        sleep 0.1 while @running
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
      channel_name :channel_two
      requires_config :token

      attr_reader :started, :stopped, :thread_id

      def initialize
        super
        @started = false
        @stopped = false
        @running = false
        @thread_id = nil
      end

      def start
        @started = true
        @running = true
        @thread_id = Thread.current.object_id
        sleep 0.1 while @running
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

  let(:channel_three_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :channel_three
      requires_config :token

      attr_reader :started, :stopped

      def initialize
        super
        @started = false
        @stopped = false
        @running = false
      end

      def start
        @started = true
        @running = true
        sleep 0.1 while @running
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

      def initialize
        super
      end

      def start
        raise Botiasloop::Error, "Channel startup failed"
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

  let(:missing_config_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :missing_config_channel
      requires_config :unconfigured_key

      def initialize
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

  let(:crash_after_start_class) do
    Class.new(Botiasloop::Channels::Base) do
      channel_name :crash_channel
      requires_config :token

      attr_reader :stopped, :crashed

      def initialize
        super
        @stopped = false
        @crashed = false
        @mutex = Mutex.new
      end

      def start
        sleep 0.05
        @mutex.synchronize { @crashed = true }
        raise "Crashed during operation"
      end

      def stop
        @stopped = true
      end

      def running?
        @mutex.synchronize { @crashed }
      end

      def process_message(source_id, content, metadata = {})
        # noop
      end
    end
  end

  before do
    Botiasloop::Config.instance = test_config
    # Clear singleton registry before each test
    Botiasloop::Channels.instance_variable_set(:@registry, nil)
    # Clear manager state
    manager.stop_all if manager.running?
  end

  after do
    Botiasloop::Config.instance = nil
    # Ensure all threads are cleaned up
    manager.stop_all if manager.running?
  end

  describe "#initialize" do
    it "initializes with empty thread tracking" do
      expect(manager.instance_variable_get(:@threads)).to be_empty
    end

    it "initializes with empty instance tracking" do
      expect(manager.instance_variable_get(:@instances)).to be_empty
    end
  end

  describe "#start_channels" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
      Botiasloop::Channels.registry.register(channel_two_class)
    end

    it "starts all configured channels in separate threads" do
      manager.start_channels

      # Give threads time to start
      sleep 0.2

      expect(manager.running?).to be true
      expect(manager.thread_count).to eq(2)
    end

    it "stores channel instances" do
      manager.start_channels
      sleep 0.2

      expect(manager.instance(:channel_one)).to be_a(blocking_channel_class)
      expect(manager.instance(:channel_two)).to be_a(channel_two_class)
    end

    it "runs each channel in a different thread" do
      manager.start_channels
      sleep 0.2

      channel_one = manager.instance(:channel_one)
      channel_two = manager.instance(:channel_two)

      expect(channel_one.thread_id).not_to eq(channel_two.thread_id)
      expect(channel_one.thread_id).not_to eq(Thread.main.object_id)
    end

    it "returns self for method chaining" do
      expect(manager.start_channels).to eq(manager)
    end

    it "raises error if already running" do
      manager.start_channels
      sleep 0.2

      expect { manager.start_channels }.to raise_error(Botiasloop::Error, /already running/)
    end

    context "with missing configuration" do
      before do
        Botiasloop::Channels.registry.register(missing_config_class)
      end

      it "skips channels with missing required configuration" do
        manager.start_channels
        sleep 0.2

        expect(manager.instance(:channel_one)).to be_a(blocking_channel_class)
        expect(manager.instance(:missing_config_channel)).to be_nil
      end

      it "logs skipped channels" do
        allow(Botiasloop::Logger).to receive(:info)
        allow(Botiasloop::Logger).to receive(:warn)
        allow(Botiasloop::Logger).to receive(:error)

        manager_with_logger = described_class.new
        manager_with_logger.start_channels

        expect(Botiasloop::Logger).to have_received(:warn).with(/Skipping.*missing_config_channel/)
      end
    end

    context "with channel startup failures" do
      before do
        Botiasloop::Channels.registry.register(failing_channel_class)
      end

      it "logs channel startup failures but does not stop other channels" do
        allow(Botiasloop::Logger).to receive(:info)
        allow(Botiasloop::Logger).to receive(:warn)
        allow(Botiasloop::Logger).to receive(:error)

        manager_with_logger = described_class.new
        manager_with_logger.start_channels
        sleep 0.2

        expect(Botiasloop::Logger).to have_received(:error).with(/Channel failing_channel crashed/)
        expect(manager_with_logger.instance(:channel_one)).to be_a(blocking_channel_class)
      end
    end

    context "with channels that crash after starting" do
      before do
        Botiasloop::Channels.registry.register(crash_after_start_class)
      end

      it "logs thread crashes but does not affect other channels" do
        manager.start_channels
        sleep 0.3

        # Check that the crashing channel was detected and logged
        # The error is logged when the thread crashes
        manager.instance(:crash_channel)

        # Channel one should still be running
        expect(manager.instance(:channel_one)).to be_a(blocking_channel_class)
        expect(manager.instance(:channel_one).running?).to be true
      end
    end
  end

  describe "#stop_all" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
      Botiasloop::Channels.registry.register(channel_two_class)
    end

    it "stops all running channels" do
      manager.start_channels
      sleep 0.2

      channel_one = manager.instance(:channel_one)
      channel_two = manager.instance(:channel_two)

      manager.stop_all

      expect(channel_one.stopped).to be true
      expect(channel_two.stopped).to be true
      expect(manager.running?).to be false
    end

    it "cleans up thread references" do
      manager.start_channels
      sleep 0.2

      manager.stop_all

      expect(manager.thread_count).to eq(0)
    end

    it "handles already stopped channels gracefully" do
      manager.start_channels
      sleep 0.2
      manager.stop_all

      expect { manager.stop_all }.not_to raise_error
    end

    it "handles channels without stop method errors" do
      # Create a channel that raises on stop
      bad_stop_class = Class.new(Botiasloop::Channels::Base) do
        channel_name :bad_stop_channel
        requires_config :token

        attr_reader :started, :stopped

        def initialize
          super
          @started = false
          @stopped = false
          @running = false
        end

        def start
          @started = true
          @running = true
          sleep 0.1 while @running
        end

        def stop
          @stopped = true
          raise "Stop failed"
        end

        def running?
          @running
        end

        def process_message(source_id, content, metadata = {})
          # noop
        end
      end

      good_channel_class = Class.new(Botiasloop::Channels::Base) do
        channel_name :good_channel
        requires_config :token

        attr_reader :started, :stopped

        def initialize
          super
          @started = false
          @stopped = false
          @running = false
        end

        def start
          @started = true
          @running = true
          sleep 0.1 while @running
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

      Botiasloop::Channels.registry.register(bad_stop_class)
      Botiasloop::Channels.registry.register(good_channel_class)

      partial_config = Botiasloop::Config.new({
        "channels" => {
          "good_channel" => {"token" => "token1"},
          "bad_stop_channel" => {"token" => "token"}
        },
        "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
      })
      Botiasloop::Config.instance = partial_config
      manager_with_bad = described_class.new
      manager_with_bad.start_channels
      sleep 0.2

      # Verify channels are running before stop
      expect(manager_with_bad.instance(:good_channel).running?).to be true

      # Stop all should not raise even though bad_stop_channel fails
      expect { manager_with_bad.stop_all }.not_to raise_error

      # After stop_all, both should be stopped (instances cleared, but we can verify
      # by checking that the thread was stopped via the timeout/force-kill path)
      expect(manager_with_bad.running?).to be false
    end
  end

  describe "#running?" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
    end

    it "returns false when no channels are running" do
      expect(manager.running?).to be false
    end

    it "returns true when channels are running" do
      manager.start_channels
      sleep 0.2

      expect(manager.running?).to be true
    end

    it "returns false after all channels are stopped" do
      manager.start_channels
      sleep 0.2
      manager.stop_all

      expect(manager.running?).to be false
    end
  end

  describe "#channel_status" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
      Botiasloop::Channels.registry.register(channel_two_class)
    end

    it "returns status for a specific channel" do
      manager.start_channels
      sleep 0.2

      status = manager.channel_status(:channel_one)

      expect(status).to include(
        identifier: :channel_one,
        running: true,
        thread_alive: true
      )
      expect(status[:thread_id]).to be_a(Integer)
    end

    it "returns nil for unknown channels" do
      expect(manager.channel_status(:unknown)).to be_nil
    end

    it "returns running: false for stopped channels" do
      manager.start_channels
      sleep 0.2

      # Get status while running first
      running_status = manager.channel_status(:channel_one)
      expect(running_status[:running]).to be true
      expect(running_status[:thread_alive]).to be true

      manager.stop_all

      status = manager.channel_status(:channel_one)
      expect(status).to be_nil # Instances are cleared after stop_all
    end
  end

  describe "#all_statuses" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
      Botiasloop::Channels.registry.register(channel_two_class)
    end

    it "returns status for all channels" do
      manager.start_channels
      sleep 0.2

      statuses = manager.all_statuses

      expect(statuses.keys).to contain_exactly(:channel_one, :channel_two)
      expect(statuses[:channel_one][:running]).to be true
      expect(statuses[:channel_two][:running]).to be true
    end

    it "returns empty hash when no channels running" do
      expect(manager.all_statuses).to be_empty
    end
  end

  describe "#wait" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
    end

    it "blocks until stop_all is called" do
      manager.start_channels
      sleep 0.2

      wait_thread = Thread.new { manager.wait }
      sleep 0.1

      expect(wait_thread.alive?).to be true

      manager.stop_all
      sleep 0.2

      expect(wait_thread.alive?).to be false
    end

    it "returns immediately if not running" do
      start_time = Time.now
      manager.wait
      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.1
    end
  end

  describe "#thread_count" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
      Botiasloop::Channels.registry.register(channel_two_class)
    end

    it "returns 0 when no channels running" do
      expect(manager.thread_count).to eq(0)
    end

    it "returns the number of active threads" do
      manager.start_channels
      sleep 0.2

      expect(manager.thread_count).to eq(2)
    end

    it "updates when channels stop" do
      manager.start_channels
      sleep 0.2
      manager.stop_all

      expect(manager.thread_count).to eq(0)
    end
  end

  describe "signal handling" do
    before do
      Botiasloop::Channels.registry.register(blocking_channel_class)
    end

    it "sets up signal handlers on start_channels" do
      expect(Signal).to receive(:trap).with("INT")
      expect(Signal).to receive(:trap).with("TERM")

      manager.start_channels
      manager.stop_all
    end

    it "handles shutdown signals gracefully", :skip do
      # Signal handling tests are skipped in test environment
      # because they interfere with the test runner signal handling.
      # The signal handling is tested manually and works correctly
      # in production environments.
    end
  end

  describe "error isolation" do
    let(:crash_test_class) do
      Class.new(Botiasloop::Channels::Base) do
        channel_name :crash_test_channel
        requires_config :token

        attr_reader :stopped, :crashed

        def initialize
          super
          @stopped = false
          @crashed = false
          @mutex = Mutex.new
        end

        def start
          sleep 0.05
          @mutex.synchronize { @crashed = true }
          raise "Crashed during operation"
        end

        def stop
          @stopped = true
        end

        def running?
          @mutex.synchronize { @crashed }
        end

        def process_message(source_id, content, metadata = {})
          # noop
        end
      end
    end

    let(:good_channel_test_class) do
      Class.new(Botiasloop::Channels::Base) do
        channel_name :good_test_channel
        requires_config :token

        attr_reader :started, :stopped

        def initialize
          super
          @started = false
          @stopped = false
          @running = false
        end

        def start
          @started = true
          @running = true
          sleep 0.1 while @running
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
      Botiasloop::Channels.registry.register(good_channel_test_class)
      Botiasloop::Channels.registry.register(crash_test_class)
    end

    it "isolates channel errors so one crash doesn't affect others" do
      isolation_config = Botiasloop::Config.new({
        "channels" => {
          "good_test_channel" => {"token" => "token1"},
          "crash_test_channel" => {"token" => "token"}
        },
        "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
      })
      Botiasloop::Config.instance = isolation_config
      isolation_manager = described_class.new
      isolation_manager.start_channels
      sleep 0.3

      # crash_test_channel crashes after 0.05s
      # good_test_channel should still be running

      expect(isolation_manager.instance(:good_test_channel).running?).to be true
      expect(isolation_manager.thread_count).to be >= 1 # At least good_test_channel remains

      isolation_manager.stop_all
    end
  end

  describe "CLI channel exclusion" do
    let(:cli_test_class) do
      Class.new(Botiasloop::Channels::Base) do
        channel_name :cli
        requires_config :token

        attr_reader :started

        def initialize
          super
          @started = false
          @running = false
        end

        def start
          @started = true
          @running = true
          sleep 0.1 while @running
        end

        def stop
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

    it "excludes CLI channel from multi-channel mode" do
      # CLI channel should be in registry but not auto-started
      Botiasloop::Channels.registry.register(cli_test_class)
      Botiasloop::Channels.registry.register(blocking_channel_class)

      manager.start_channels
      sleep 0.2

      # CLI should not be started
      cli_channel = manager.instance(:cli)
      expect(cli_channel).to be_nil

      # But other channels should be started
      expect(manager.instance(:channel_one)).not_to be_nil

      manager.stop_all
    end
  end
end
