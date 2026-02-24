# frozen_string_literal: true

module Botiasloop
  module Commands
    # Context object passed to command executions
    # Provides access to conversation, chat, config, channel, and user info
    class Context
      # @return [Conversation] The current conversation
      attr_accessor :conversation

      # @return [Chat] The chat this conversation belongs to
      attr_reader :chat

      # @return [Channels::Base, nil] The channel instance (nil in CLI)
      attr_reader :channel

      # @return [String, nil] The user/source identifier
      attr_reader :user_id

      # Initialize context
      #
      # @param conversation [Conversation] The current conversation
      # @param chat [Chat] The chat this conversation belongs to
      # @param channel [Channels::Base, nil] The channel instance (nil in CLI)
      # @param user_id [String, nil] The user/source identifier
      def initialize(conversation:, chat:, channel: nil, user_id: nil)
        @conversation = conversation
        @chat = chat
        @channel = channel
        @user_id = user_id
      end
    end
  end
end
