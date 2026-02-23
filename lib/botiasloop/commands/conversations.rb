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
        conversations = ConversationManager.list_by_user(context.user_id, archived: show_archived)
        current_id = ConversationManager.current_id_for(context.user_id)

        lines = show_archived ? ["**Archived Conversations**"] : ["**Conversations**"]

        if conversations.empty?
          lines << (show_archived ? "No archived conversations found." : "No conversations found.")
          return lines.join("\n")
        end

        conversations.each do |conv|
          prefix = (conv[:id] == current_id) ? "[current] " : ""
          label = conv[:label]
          suffix = label ? " (#{label})" : ""
          lines << "#{prefix}#{conv[:id]}#{suffix}"
        end

        lines.join("\n")
      end
    end
  end
end
