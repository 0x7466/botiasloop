# frozen_string_literal: true

require "logger"

module Botiasloop
  # Manages concurrent execution of multiple channels
  #
  # ChannelsManager provides a higher-level abstraction over the Channel Registry,
  # handling the threading and lifecycle management required to run multiple
  # channels simultaneously. Each channel runs in its own thread, allowing
  # independent operation and error isolation.
  #
  # @example Basic usage
  #   manager = Botiasloop::ChannelsManager.new
  #   manager.start_channels.wait
  #
  class ChannelsManager
    # Time to wait for graceful shutdown before force-killing threads
    SHUTDOWN_TIMEOUT = 5

    # Channels that should not be auto-started (interactive channels)
    EXCLUDED_CHANNELS = %i[cli].freeze

    # Initialize a new ChannelsManager
    def initialize
      @threads = {}
      @instances = {}
      @mutex = Mutex.new
      @running = false
      @shutdown_requested = false
    end

    # Start all configured channels in separate threads
    #
    # Each channel is spawned in its own thread, allowing concurrent
    # operation. Channels with missing configuration are skipped with
    # a warning. Startup failures are logged but don't prevent other
    # channels from starting.
    #
    # @return [ChannelsManager] self for method chaining
    # @raise [Error] If channels are already running
    def start_channels
      @mutex.synchronize do
        raise Error, "Channels are already running" if @running

        @running = true
        @shutdown_requested = false
      end

      setup_signal_handlers

      registry = Channels.registry
      registry.channels.each do |identifier, channel_class|
        next if EXCLUDED_CHANNELS.include?(identifier)

        begin
          instance = channel_class.new
        rescue Error => e
          if e.message.match?(/Missing required configuration/)
            Logger.warn "[ChannelsManager] Skipping #{identifier}: #{e.message}"
            next
          end
          raise
        end

        thread = spawn_channel_thread(identifier, instance)
        @mutex.synchronize do
          @threads[identifier] = thread
          @instances[identifier] = instance
        end

        Logger.info "[ChannelsManager] Started #{identifier} in thread #{thread.object_id}"
      end

      # Monitor threads for crashes
      spawn_monitor_thread unless @threads.empty?

      self
    end

    # Stop all running channels gracefully
    #
    # Sends stop signal to all channel instances and waits for threads
    # to complete. Force-kills threads that don't stop within timeout.
    #
    # @return [void]
    def stop_all
      @mutex.synchronize do
        return unless @running

        @shutdown_requested = true
        @running = false
      end

      Logger.info "[ChannelsManager] Stopping all channels..."

      # Stop all channel instances
      @instances.each do |identifier, instance|
        instance.stop if instance.running?
      rescue => e
        Logger.error "[ChannelsManager] Error stopping #{identifier}: #{e.message}"
      end

      # Wait for threads to complete
      @threads.each do |identifier, thread|
        unless thread.join(SHUTDOWN_TIMEOUT)
          Logger.warn "[ChannelsManager] Force-killing #{identifier} thread"
          thread.kill
        end
      end

      @mutex.synchronize do
        @threads.clear
        @instances.clear
      end

      Logger.info "[ChannelsManager] All channels stopped"
    end

    # Check if any channels are currently running
    #
    # @return [Boolean] True if any channel thread is alive
    def running?
      @mutex.synchronize do
        return false unless @running

        @threads.any? { |_, thread| thread.alive? }
      end
    end

    # Get the number of active channel threads
    #
    # @return [Integer] Count of alive threads
    def thread_count
      @mutex.synchronize do
        @threads.count { |_, thread| thread.alive? }
      end
    end

    # Get a specific channel instance
    #
    # @param identifier [Symbol] Channel identifier
    # @return [Base, nil] Channel instance or nil if not running
    def instance(identifier)
      @mutex.synchronize do
        @instances[identifier]
      end
    end

    # Get status information for a specific channel
    #
    # @param identifier [Symbol] Channel identifier
    # @return [Hash, nil] Status hash or nil if channel not found
    #   * :identifier [Symbol] Channel identifier
    #   * :running [Boolean] Whether channel instance reports running
    #   * :thread_alive [Boolean] Whether thread is alive
    #   * :thread_id [Integer] Thread object ID
    def channel_status(identifier)
      @mutex.synchronize do
        instance = @instances[identifier]
        thread = @threads[identifier]

        return nil unless instance

        {
          identifier: identifier,
          running: instance.running?,
          thread_alive: thread&.alive? || false,
          thread_id: thread&.object_id
        }
      end
    end

    # Get status for all running channels
    #
    # @return [Hash{Symbol => Hash}] Map of channel identifier to status
    def all_statuses
      @mutex.synchronize do
        @instances.transform_values do |instance|
          thread = @threads[instance.class.channel_identifier]
          {
            identifier: instance.class.channel_identifier,
            running: instance.running?,
            thread_alive: thread&.alive? || false,
            thread_id: thread&.object_id
          }
        end
      end
    end

    # Block until all channels have stopped
    #
    # Useful for daemon mode where the main thread should wait.
    # Returns immediately if no channels are running.
    #
    # @return [void]
    def wait
      return unless running?

      # Wait for all threads to complete
      loop do
        sleep 0.1
        break unless running?
      end
    end

    private

    # Spawn a thread to run a channel
    #
    # @param identifier [Symbol] Channel identifier
    # @param instance [Base] Channel instance
    # @return [Thread] The spawned thread
    def spawn_channel_thread(identifier, instance)
      Thread.new do
        Thread.current.name = "botiasloop-#{identifier}"

        begin
          instance.start
        rescue => e
          Logger.error "[ChannelsManager] Channel #{identifier} crashed: #{e.message}"
          Logger.error "[ChannelsManager] #{e.backtrace&.first(5)&.join("\n")}"
        end
      end
    end

    # Spawn a monitor thread to detect channel crashes
    #
    # @return [Thread] The monitor thread
    def spawn_monitor_thread
      Thread.new do
        Thread.current.name = "botiasloop-monitor"

        loop do
          sleep 1.0

          @mutex.synchronize do
            break if @shutdown_requested

            @threads.each do |identifier, thread|
              next if thread.alive?

              instance = @instances[identifier]
              next unless instance&.running?

              Logger.error "[ChannelsManager] Thread for #{identifier} died unexpectedly"
              @instances.delete(identifier)
              @threads.delete(identifier)
            end

            # Exit monitor if no more threads
            break if @threads.empty?
          end
        end
      end
    end

    # Set up signal handlers for graceful shutdown
    #
    # @return [void]
    def setup_signal_handlers
      # Store original handlers
      @original_int_handler = Signal.trap("INT") { handle_shutdown_signal("INT") }
      @original_term_handler = Signal.trap("TERM") { handle_shutdown_signal("TERM") }
    end

    # Handle shutdown signals
    #
    # Signals are handled in a separate thread to avoid
    # limitations of trap context (no Mutex operations).
    #
    # @param signal [String] Signal name
    # @return [void]
    def handle_shutdown_signal(signal)
      # Defer to separate thread to avoid trap context limitations
      Thread.new do
        Logger.info "[ChannelsManager] Received #{signal}, shutting down..."
        stop_all

        # Call original handler if it exists
        case signal
        when "INT"
          @original_int_handler&.call if @original_int_handler.respond_to?(:call)
        when "TERM"
          @original_term_handler&.call if @original_term_handler.respond_to?(:call)
        end

        exit(0)
      end.join
    end
  end
end
