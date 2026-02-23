# frozen_string_literal: true

module Botiasloop
  module Commands
    # Verbose command - controls verbose mode for tool call output
    class Verbose < Base
      command :verbose
      description "Toggle verbose mode (tool call output). Usage: /verbose [on|off]"

      def execute(context, args = nil)
        conversation = context.conversation

        case args&.downcase&.strip
        when "on"
          conversation.update(verbose: true)
          "Verbose mode enabled. Tool calls will be shown."
        when "off"
          conversation.update(verbose: false)
          "Verbose mode disabled. Tool calls will be hidden."
        when nil, ""
          status = conversation.verbose ? "on" : "off"
          "Verbose mode is currently #{status}. Usage: /verbose [on|off]"
        else
          "Unknown argument: #{args}. Usage: /verbose [on|off]"
        end
      end
    end
  end
end
