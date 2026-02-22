# frozen_string_literal: true

module Botiasloop
  # Conversation class wraps the Sequel model for backward compatibility
  # Provides the same interface as the original file-based implementation
  class Conversation
    # @return [String] UUID of the conversation
    attr_reader :uuid

    # Initialize a conversation
    #
    # @param uuid [String, nil] UUID for the conversation (generates new if nil)
    def initialize(uuid = nil)
      if uuid
        @model = Models::Conversation.find(id: uuid)
        raise Error, "Conversation not found: #{uuid}" unless @model
        @uuid = uuid
      else
        @model = Models::Conversation.create(user_id: "default")
        @uuid = @model.id
      end
    end

    # Get the label for this conversation
    #
    # @return [String, nil] Label or nil if not set
    def label
      @model.label
    end

    # Set the label for this conversation
    #
    # @param value [String] Label value
    # @return [String] The label value
    # @raise [Error] If label format is invalid or already in use
    def label=(value)
      ConversationManager.set_label(@uuid, value)
      @model.refresh
    end

    # Check if this conversation has a label
    #
    # @return [Boolean] True if label is set
    def label?
      !@model.label.nil? && !@model.label.to_s.empty?
    end

    # Get the number of messages in the conversation
    #
    # @return [Integer] Message count
    def message_count
      @model.message_count
    end

    # Get the timestamp of the last activity in the conversation
    #
    # @return [String, nil] ISO8601 timestamp of last message, or nil if no messages
    def last_activity
      @model.last_activity
    end

    # Add a message to the conversation
    #
    # @param role [String] Role of the message sender (user, assistant, system)
    # @param content [String] Message content
    def add(role, content)
      @model.add_message(role: role, content: content)
    end

    # @return [Array<Hash>] Array of message hashes
    def history
      @model.history
    end

    # @return [String] Path to the conversation file (deprecated, returns model ID)
    def path
      @uuid
    end

    # Reset conversation - clear all messages
    def reset!
      @model.reset!
    end

    # Compact conversation by replacing old messages with a summary
    #
    # @param summary [String] Summary of older messages
    # @param recent_messages [Array<Hash>] Recent messages to keep
    def compact!(summary, recent_messages)
      @model.compact!(summary, recent_messages)
    end

    # @return [Models::Conversation] The underlying model
    attr_reader :model
  end
end
