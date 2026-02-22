# frozen_string_literal: true

require "securerandom"

module Botiasloop
  module Commands
    # New command - creates a new conversation
    class New < Base
      command :new
      description "Start a new conversation"

      def execute(context, _args = nil)
        new_conversation = ConversationManager.create_new(context.user_id)
        context.conversation = new_conversation

        "**New conversation started (UUID: #{new_conversation.uuid}).**\n" \
        "Use `/switch #{new_conversation.uuid}` to return later."
      end
    end
  end
end
