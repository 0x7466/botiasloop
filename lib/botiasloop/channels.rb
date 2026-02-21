# frozen_string_literal: true

module Botiasloop
  module Channels
    class Registry
      attr_reader :channels, :instances

      def initialize
        @channels = {}
        @instances = {}
      end

      # Register a channel class
      #
      # @param channel_class [Class] Channel class inheriting from Base
      def register(channel_class)
        identifier = channel_class.channel_identifier
        raise Error, "Channel class must define channel_name" unless identifier

        @channels[identifier] = channel_class
      end

      # Deregister a channel by name
      #
      # @param name [Symbol] Channel identifier
      def deregister(name)
        @channels.delete(name)
        @instances.delete(name)
      end

      # Auto-start all registered channels
      #
      # @param config [Config] Configuration instance
      # @raise [Error] If any channel fails to start
      def auto_start(config)
        started_channels = []

        @channels.each do |identifier, channel_class|
          instance = channel_class.new(config)
          instance.start
          @instances[identifier] = instance
          started_channels << instance
        rescue => e
          # Stop any channels that were already started
          started_channels.each(&:stop)
          @instances.clear
          raise Error, "Failed to start #{identifier}: #{e.message}"
        end
      end

      # Stop all running channels
      def stop_all
        @instances.each do |_identifier, instance|
          instance.stop if instance.running?
        rescue => e
          # Log error but continue stopping other channels
          warn "Error stopping channel: #{e.message}"
        end
        @instances.clear
      end

      # Check if any channels are running
      #
      # @return [Boolean] True if any channel is running
      def running?
        @instances.any? do |_identifier, instance|
          instance.running?
        end
      end

      # Get channel class by name
      #
      # @param name [Symbol] Channel identifier
      # @return [Class, nil] Channel class or nil if not found
      def [](name)
        @channels[name]
      end

      # Get all registered channel names
      #
      # @return [Array<Symbol>] Channel identifiers
      def names
        @channels.keys
      end
    end

    # Singleton registry instance
    #
    # @return [Registry] The global channel registry
    def self.registry
      @registry ||= Registry.new
    end
  end
end
