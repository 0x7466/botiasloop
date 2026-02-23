# frozen_string_literal: true

module Botiasloop
  module Commands
    # Status command - shows current conversation status
    class Status < Base
      command :status
      description "Show current conversation status"

      def execute(context, _args = nil)
        conversation = context.conversation
        config = Config.instance

        lines = ["**Conversation Status**"]
        lines << "ID: #{conversation.uuid}"
        lines << "Label: #{format_label(conversation)}"
        lines << "Model: #{config.providers["openrouter"]["model"]}"
        lines << "Max iterations: #{config.max_iterations}"
        lines << "Messages: #{conversation.history.length}"
        lines << "Tokens: #{conversation.total_tokens} (#{conversation.input_tokens || 0} in / #{conversation.output_tokens || 0} out)"

        lines.join("\n")
      end

      private

      def format_label(conversation)
        conversation.label? ? conversation.label : "(none - use /label <name> to set)"
      end
    end
  end
end
