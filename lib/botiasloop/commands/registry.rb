# frozen_string_literal: true

module Botiasloop
  module Commands
    # Registry for slash commands
    # Manages command registration, lookup, and execution
    class Registry
      # Regex pattern to match slash commands at the start of a message
      # Captures command name and optional arguments
      COMMAND_PATTERN = /^\/([a-zA-Z0-9_]+)(?:\s+(.+))?$/

      def initialize
        @commands = {}
      end

      # Register a command class
      #
      # @param command_class [Class] Command class inheriting from Base
      # @raise [Error] If command class doesn't have a command_name
      def register(command_class)
        name = command_class.command_name
        raise Error, "Command class must define command name" unless name

        @commands[name] = command_class
      end

      # Get a command class by name
      #
      # @param name [Symbol] Command name
      # @return [Class, nil] Command class or nil if not found
      def [](name)
        @commands[name]
      end

      # Get all registered command classes
      #
      # @return [Array<Class>] Array of command classes sorted by name
      def all
        @commands.values.sort_by(&:command_name)
      end

      # Get all registered command names
      #
      # @return [Array<Symbol>] Array of command names sorted
      def names
        @commands.keys.sort
      end

      # Check if a message is a valid command
      # Must start with / and be a registered command
      #
      # @param message [String] Message text to check
      # @return [Boolean] True if message is a registered command
      def command?(message)
        return false unless message.is_a?(String)

        match = message.match(COMMAND_PATTERN)
        return false unless match

        name = match[1]&.to_sym
        @commands.key?(name)
      end

      # Execute a command from a message
      #
      # @param message [String] Full command message (e.g., "/help" or "/switch label")
      # @param context [Context] Execution context
      # @return [String] Command response or error message
      def execute(message, context)
        match = message.match(COMMAND_PATTERN)
        return unknown_command_response(message) unless match

        name = match[1]&.to_sym
        args = match[2]

        command_class = @commands[name]
        return unknown_command_response(message) unless command_class

        command = command_class.new
        command.execute(context, args)
      end

      private

      def unknown_command_response(message)
        name = message.match(COMMAND_PATTERN)&.[](1) || "unknown"
        "Unknown command: /#{name}. Type /help for available commands."
      end
    end

    # Singleton registry instance
    #
    # @return [Registry] The global command registry
    def self.registry
      @registry ||= Registry.new
    end

    # Check if a message is a command
    #
    # @param message [String] Message to check
    # @return [Boolean] True if message is a registered command
    def self.command?(message)
      registry.command?(message)
    end

    # Execute a command from a message
    #
    # @param message [String] Full command message
    # @param context [Context] Execution context
    # @return [String] Command response or error message
    def self.execute(message, context)
      registry.execute(message, context)
    end
  end
end
