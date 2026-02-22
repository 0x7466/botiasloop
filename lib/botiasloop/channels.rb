# frozen_string_literal: true

module Botiasloop
  module Channels
    # Registry for channel classes
    #
    # The Registry maintains a static mapping of channel identifiers to
    # channel classes. It does not manage runtime instances - that is handled
    # by ChannelsManager.
    #
    class Registry
      attr_reader :channels

      def initialize
        @channels = {}
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

      # Clear all registered channels
      # Useful for testing to prevent state leakage
      def clear
        @channels.clear
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
