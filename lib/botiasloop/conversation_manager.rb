# frozen_string_literal: true

module Botiasloop
  # Manages conversation state globally, mapping user IDs to conversation UUIDs
  # Handles all business logic: switching, finding current, labeling, etc.
  class ConversationManager
    # Valid label format: alphanumeric, dashes, and underscores
    LABEL_REGEX = /\A[a-zA-Z0-9_-]+\z/

    class << self
      # Get or create the current conversation for a user
      #
      # @param user_id [String] User identifier
      # @return [Conversation] Current conversation for the user
      def current_for(user_id)
        user_key = user_id.to_s
        conversation = Models::Conversation.where(user_id: user_key, is_current: true).first

        if conversation
          Conversation.new(conversation.id)
        else
          create_new(user_key)
        end
      end

      # Switch a user to a different conversation by label or UUID
      #
      # @param user_id [String] User identifier
      # @param identifier [String] Conversation label or UUID to switch to
      # @return [Conversation] The switched-to conversation
      # @raise [Error] If conversation with given identifier doesn't exist
      def switch(user_id, identifier)
        user_key = user_id.to_s
        identifier = identifier.to_s.strip

        raise Error, "Usage: /switch <label-or-uuid>" if identifier.empty?

        # First try to find by label
        conversation = Models::Conversation.where(user_id: user_key, label: identifier).first

        # If not found by label, treat as UUID
        conversation ||= Models::Conversation.find(id: identifier, user_id: user_key)

        raise Error, "Conversation '#{identifier}' not found" unless conversation

        # Clear current flag from all user's conversations
        Models::Conversation.where(user_id: user_key).update(is_current: false)

        # Set new conversation as current
        conversation.update(is_current: true)
        Conversation.new(conversation.id)
      end

      # Create a new conversation and switch the user to it
      #
      # @param user_id [String] User identifier
      # @return [Conversation] The newly created conversation
      def create_new(user_id)
        user_key = user_id.to_s

        # Clear current flag from all user's conversations
        Models::Conversation.where(user_id: user_key).update(is_current: false)

        # Create new conversation as current
        conversation = Models::Conversation.create(user_id: user_key, is_current: true)
        Conversation.new(conversation.id)
      end

      # Get the UUID for a user's current conversation
      #
      # @param user_id [String] User identifier
      # @return [String, nil] Current conversation UUID or nil if none exists
      def current_uuid_for(user_id)
        conversation = Models::Conversation.where(user_id: user_id.to_s, is_current: true).first
        conversation&.id
      end

      # List all conversation mappings
      #
      # @return [Hash] Hash mapping UUIDs to {user_id, label} hashes
      def all_mappings
        Models::Conversation.all.map do |conv|
          [conv.id, {"user_id" => conv.user_id, "label" => conv.label}]
        end.to_h
      end

      # Remove a user's current conversation
      #
      # @param user_id [String] User identifier
      def remove(user_id)
        conversation = Models::Conversation.where(user_id: user_id.to_s, is_current: true).first
        return unless conversation

        conversation.destroy
      end

      # Clear all conversations (use with caution)
      def clear_all
        Models::Conversation.db[:conversations].delete
      end

      # Get the label for a conversation
      #
      # @param uuid [String] Conversation UUID
      # @return [String, nil] Label value or nil
      def label(uuid)
        conversation = Models::Conversation.find(id: uuid)
        conversation&.label
      end

      # Set the label for a conversation
      #
      # @param uuid [String] Conversation UUID
      # @param value [String] Label value
      # @return [String] The label value
      # @raise [Error] If label format is invalid or already in use
      def set_label(uuid, value)
        conversation = Models::Conversation.find(id: uuid)
        raise Error, "Conversation not found" unless conversation

        # Validate label format
        unless value.nil? || value.to_s.empty? || value.to_s.match?(LABEL_REGEX)
          raise Error, "Invalid label format. Use only letters, numbers, dashes, and underscores."
        end

        # Check uniqueness per user (excluding current conversation)
        user_id = conversation.user_id
        if value && !value.to_s.empty? && label_exists?(user_id, value, exclude_uuid: uuid)
          raise Error, "Label '#{value}' already in use by another conversation"
        end

        # Allow empty string to be treated as nil (clearing the label)
        value = nil if value.to_s.empty?

        conversation.update(label: value)
        value
      end

      # Check if a label exists for a user
      #
      # @param user_id [String] User identifier
      # @param label [String] Label to check
      # @param exclude_uuid [String, nil] UUID to exclude from check
      # @return [Boolean] True if label exists for user
      def label_exists?(user_id, label, exclude_uuid: nil)
        return false unless label

        query = Models::Conversation.where(user_id: user_id.to_s, label: label)
        query = query.exclude(id: exclude_uuid) if exclude_uuid
        query.count > 0
      end

      # List all conversations for a user
      #
      # @param user_id [String] User identifier
      # @return [Array<Hash>] Array of {uuid, label} hashes
      def list_by_user(user_id)
        Models::Conversation.where(user_id: user_id.to_s).all.map do |conv|
          {uuid: conv.id, label: conv.label}
        end
      end

      # Find conversation UUID by label for a user
      #
      # @param user_id [String] User identifier
      # @param label [String] Label to search for
      # @return [String, nil] UUID or nil if not found
      def find_by_label(user_id, label)
        conversation = Models::Conversation.where(user_id: user_id.to_s, label: label).first
        conversation&.id
      end
    end
  end
end
