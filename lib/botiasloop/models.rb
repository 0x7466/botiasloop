# frozen_string_literal: true

require "securerandom"
require "time"

module Botiasloop
  module Models
    # Conversation model - represents a chat conversation
    # Pure database model - no business logic, only CRUD and relations
    class Conversation < Sequel::Model(:conversations)
      one_to_many :messages, class: "Botiasloop::Models::Message", key: :conversation_id

      # Set up validations
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Allow setting primary key (id) for UUID
      unrestrict_primary_key

      # Auto-generate UUID if not provided
      def initialize(values = {})
        values[:id] ||= SecureRandom.uuid
        super
      end

      # Validations
      def validate
        super
        validates_presence [:user_id]

        if label && !label.to_s.empty?
          validates_format Botiasloop::ConversationManager::LABEL_REGEX, :label, message: "Invalid label format. Use only letters, numbers, dashes, and underscores."
        end
      end

      # Instance methods for message management

      # Get the timestamp of the last activity in the conversation
      # @return [String, nil] ISO8601 timestamp of last message, or nil if no messages
      def last_activity
        return nil if messages.empty?

        messages_dataset.order(:timestamp).last.timestamp.utc.iso8601
      end

      # Get conversation history as array of message hashes
      # @return [Array<Hash>] Array of message hashes with role, content, timestamp
      def history
        messages_dataset.order(:timestamp).map(&:to_hash)
      end

      # Add a message to the conversation
      # @param role [String] Role of the message sender (user, assistant, system)
      # @param content [String] Message content
      # @param timestamp [Time, nil] Optional timestamp (defaults to now)
      def add_message(role:, content:, timestamp: nil)
        timestamp ||= Time.now.utc
        Message.create(
          conversation_id: id,
          role: role,
          content: content,
          timestamp: timestamp
        )
      end

      # Reset conversation - clear all messages
      def reset!
        messages_dataset.delete
      end

      # Compact conversation by replacing old messages with a summary
      # @param summary [String] Summary of older messages
      # @param recent_messages [Array<Hash>] Recent messages to keep
      def compact!(summary, recent_messages)
        reset!
        add_message(role: "system", content: summary)
        recent_messages.each do |msg|
          add_message(role: msg[:role], content: msg[:content])
        end
      end

      # Get the number of messages in the conversation
      # @return [Integer] Message count
      def message_count
        messages.count
      end
    end

    # Message model - represents a single message in a conversation
    class Message < Sequel::Model(:messages)
      many_to_one :conversation, class: "Botiasloop::Models::Conversation", key: :conversation_id

      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      # Validations
      def validate
        super
        validates_presence [:conversation_id, :role, :content]
      end

      # Convert message to hash for API compatibility
      # @return [Hash] Message as hash with symbol keys
      def to_hash
        {
          role: role,
          content: content,
          timestamp: timestamp.iso8601
        }
      end
    end
  end
end
