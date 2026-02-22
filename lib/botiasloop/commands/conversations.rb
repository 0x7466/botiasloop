# frozen_string_literal: true

module Botiasloop
  module Commands
    # Conversations command - lists all conversations
    class Conversations < Base
      command :conversations
      description "List all conversations"

      # Execute the conversations command
      #
      # @param context [Context] Execution context
      # @param _args [String, nil] Unused arguments
      # @return [String] Formatted list of conversations
      def execute(context, _args = nil)
        mappings = ConversationManager.all_mappings
        current_uuid = ConversationManager.current_uuid_for(context.user_id)

        lines = ["**Conversations**"]

        if mappings.empty?
          lines << "No conversations found."
          return lines.join("\n")
        end

        mappings.each do |uuid, data|
          prefix = (uuid == current_uuid) ? "[current] " : ""
          label = data["label"]
          suffix = label ? " (#{label})" : ""
          lines << "#{prefix}#{uuid}#{suffix}"
        end

        lines.join("\n")
      end
    end
  end
end
