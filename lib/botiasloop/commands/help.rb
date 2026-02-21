# frozen_string_literal: true

module Botiasloop
  module Commands
    # Help command - displays available slash commands
    class Help < Base
      command :help
      description "Show available commands"

      # Execute the help command
      #
      # @param context [Context] Execution context
      # @param _args [String, nil] Unused arguments
      # @return [String] Formatted list of commands
      def execute(context, _args = nil)
        commands = Botiasloop::Commands.registry.all

        lines = ["**Available commands**"]

        commands.each do |cmd_class|
          name = cmd_class.command_name
          desc = cmd_class.description || "No description"
          lines << "/#{name} - #{desc}"
        end

        lines.join("\n")
      end
    end
  end
end
