# frozen_string_literal: true

module Botiasloop
  module Commands
    # System prompt command - displays the current system prompt
    class SystemPrompt < Base
      command :systemprompt
      description "Display the system prompt"

      # Execute the systemprompt command
      #
      # @param context [Context] Execution context
      # @param _args [String, nil] Unused - command takes no arguments
      # @return [String] The system prompt
      def execute(context, _args = nil)
        context.conversation.system_prompt(chat: context.chat)
      end
    end
  end
end
