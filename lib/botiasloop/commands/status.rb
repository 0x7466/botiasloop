# frozen_string_literal: true

module Botiasloop
  module Commands
    # Status command - shows current conversation status
    class Status < Base
      command :status
      description "Show current conversation status"

      def execute(context, _args = nil)
        conversation = context.conversation
        config = context.config

        lines = ["**Conversation Status**"]
        
        lines << "UUID: #{conversation.uuid}"
        lines << "Model: #{config.providers["openrouter"]["model"]}"
        lines << "Max iterations: #{config.max_iterations}"
        lines << "Messages: #{conversation.history.length}"
        lines << ""
        lines << "**Token Usage:**"
        lines << "Input:  #{conversation.tokens_in}"
        lines << "Output: #{conversation.tokens_out}"
        lines << "Total:  #{conversation.tokens_in + conversation.tokens_out}"

        lines.join("\n")
      end
    end
  end
end
