# frozen_string_literal: true

module Botiasloop
  module Commands
    # Reset command - clears conversation history
    class Reset < Base
      command :reset
      description "Clear conversation history"

      def execute(context, _args = nil)
        conversation = context.conversation
        conversation.reset!

        "Conversation #{conversation.uuid} history and tokens cleared."
      end
    end
  end
end
