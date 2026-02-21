# frozen_string_literal: true

module Botiasloop
  module Commands
    # Base class for all slash commands
    # Provides DSL for defining command metadata
    class Base
      class << self
        # Get or set the command name
        # Automatically registers the command when name is set
        #
        # @param name [Symbol, nil] Command name to set
        # @return [Symbol, nil] The command name
        def command(name = nil)
          if name
            @command_name = name
            # Auto-register when command name is set
            Botiasloop::Commands.registry.register(self)
          end
          @command_name
        end

        alias_method :command_name, :command

        # Get or set the command description
        #
        # @param text [String, nil] Description text to set
        # @return [String, nil] The command description
        def description(text = nil)
          if text
            @description = text
          end
          @description
        end

        # Called when a subclass is defined
        # No-op - registration happens when command() is called
        def inherited(subclass)
          super
        end
      end

      # Execute the command
      #
      # @param context [Context] Execution context
      # @param args [String, nil] Command arguments
      # @return [String] Command response
      # @raise [NotImplementedError] Subclass must implement
      def execute(context, args = nil)
        raise NotImplementedError, "Subclass must implement #execute"
      end
    end
  end
end
