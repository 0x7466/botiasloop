# frozen_string_literal: true

require "ruby_llm"

module Botiasloop
  module Commands
    # Compact command - compresses conversation by summarizing older messages
    class Compact < Base
      KEEP_RECENT = 5
      MIN_MESSAGES = 10

      command :compact
      description "Compress conversation by summarizing older messages"

      def execute(context, _args = nil)
        conversation = context.conversation
        config = context.config

        messages = conversation.history

        if messages.length < MIN_MESSAGES
          return "Need at least #{MIN_MESSAGES} messages to compact. Current: #{messages.length}"
        end

        # Split messages: older ones to summarize, recent ones to keep
        older_messages = messages[0...-KEEP_RECENT]
        recent_messages = messages.last(KEEP_RECENT)

        # Generate summary using LLM
        summary = summarize_messages(older_messages, config)

        # Replace conversation history
        conversation.compact!(summary, recent_messages)

        compacted_count = older_messages.length
        summary_preview = (summary.length > 100) ? "#{summary[0..100]}..." : summary
        "Conversation #{conversation.uuid} compacted.\n" \
        "#{compacted_count} messages summarized, #{recent_messages.length} recent messages kept.\n" \
        "Summary: #{summary_preview}"
      end

      private

      def summarize_messages(messages, config)
        chat = create_chat(config)

        # Format messages for summarization
        conversation_text = messages.map do |msg|
          "#{msg[:role]}: #{msg[:content]}"
        end.join("\n\n")

        prompt = <<~PROMPT
          Please summarize the following conversation, preserving key context, decisions, and facts. Be concise but comprehensive:

          #{conversation_text}
        PROMPT

        chat.add_message(role: :user, content: prompt)
        response = chat.complete

        response.content
      end

      def create_chat(config)
        summarize_config = config.commands["summarize"] || {}

        if summarize_config["provider"] && summarize_config["model"]
          # Use configured provider/model for summarization
          RubyLLM.chat(model: summarize_config["model"])
        else
          # Fall back to default model
          default_model = config.providers["openrouter"]["model"]
          RubyLLM.chat(model: default_model)
        end
      end
    end
  end
end
