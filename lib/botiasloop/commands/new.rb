# frozen_string_literal: true

require "securerandom"

module Botiasloop
  module Commands
    # New command - creates a new conversation
    class New < Base
      command :new
      description "Start a new conversation"

      def execute(context, _args = nil)
        new_uuid = SecureRandom.uuid

        "New conversation started (UUID: #{new_uuid}).\n" \
        "Use `/switch #{new_uuid}` to return to this conversation later."
      end
    end
  end
end
