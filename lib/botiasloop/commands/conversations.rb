# frozen_string_literal: true

module Botiasloop
  module Commands
    # Conversations command - lists all conversations
    class Conversations < Base
      command :conversations
      description "List all conversations (use '/conversations archived' to list archived)"

      # Execute the conversations command
      # Lists non-archived conversations by default, or archived conversations when specified
      # Sorted by last updated (most recent first)
      #
      # @param context [Context] Execution context
      # @param args [String, nil] Arguments - 'archived' to list archived conversations
      # @return [String] Formatted list of conversations
      def execute(context, args = nil)
        show_archived = args.to_s.strip.downcase == "archived"
        current_conversation = context.conversation

        if show_archived
          conversations = context.chat.archived_conversations
          lines = ["**Archived Conversations**"]
        else
          conversations = context.chat.active_conversations
          lines = ["**Conversations**"]
        end

        if conversations.empty?
          lines << (show_archived ? "No archived conversations found." : "No conversations found.")
          return lines.join("\n")
        end

        conversations.each do |conv|
          prefix = (conv.id == current_conversation.id) ? "[current] " : ""
          label = conv.label
          suffix = label ? " (#{label})" : ""
          lines << "#{prefix}#{conv.id}#{suffix}"
        end

        lines.join("\n")
      end
    end
  end
end
