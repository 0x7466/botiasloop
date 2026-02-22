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
        conversation = Conversation.where(user_id: user_key, is_current: true, archived: false).first

        if conversation
          Conversation[conversation.id]
        else
          create_new(user_key)
        end
      end

      # Switch a user to a different conversation by label or UUID
      # Auto-unarchives archived conversations when switching to them
      #
      # @param user_id [String] User identifier
      # @param identifier [String] Conversation label or UUID to switch to
      # @return [Conversation] The switched-to conversation
      # @raise [Error] If conversation with given identifier doesn't exist
      def switch(user_id, identifier)
        user_key = user_id.to_s
        identifier = identifier.to_s.strip

        raise Error, "Usage: /switch <label-or-uuid>" if identifier.empty?

        # First try to find by label (include archived)
        conversation = Conversation.where(user_id: user_key, label: identifier).first

        # If not found by label, treat as UUID (include archived)
        conversation ||= Conversation.find(id: identifier, user_id: user_key)

        raise Error, "Conversation '#{identifier}' not found" unless conversation

        # Auto-unarchive if switching to an archived conversation
        conversation.update(archived: false) if conversation.archived

        # Clear current flag from all user's conversations
        Conversation.where(user_id: user_key).update(is_current: false)

        # Set new conversation as current
        conversation.update(is_current: true)
        Conversation[conversation.id]
      end

      # Create a new conversation and switch the user to it
      #
      # @param user_id [String] User identifier
      # @return [Conversation] The newly created conversation
      def create_new(user_id)
        user_key = user_id.to_s

        # Clear current flag from all user's conversations
        Conversation.where(user_id: user_key).update(is_current: false)

        # Create new conversation as current
        conversation = Conversation.create(user_id: user_key, is_current: true)
        Conversation[conversation.id]
      end

      # Get the UUID for a user's current conversation
      #
      # @param user_id [String] User identifier
      # @return [String, nil] Current conversation UUID or nil if none exists
      def current_uuid_for(user_id)
        conversation = Conversation.where(user_id: user_id.to_s, is_current: true).first
        conversation&.id
      end

      # List all conversation mappings (excluding archived by default)
      #
      # @param include_archived [Boolean] Whether to include archived conversations
      # @return [Hash] Hash mapping UUIDs to {user_id, label} hashes
      def all_mappings(include_archived: false)
        dataset = include_archived ? Conversation.dataset : Conversation.where(archived: false)
        dataset.all.map do |conv|
          [conv.id, {"user_id" => conv.user_id, "label" => conv.label}]
        end.to_h
      end

      # Remove a user's current conversation
      #
      # @param user_id [String] User identifier
      def remove(user_id)
        conversation = Conversation.where(user_id: user_id.to_s, is_current: true).first
        return unless conversation

        conversation.destroy
      end

      # Clear all conversations (use with caution)
      def clear_all
        Conversation.db[:conversations].delete
      end

      # Get the label for a conversation
      #
      # @param uuid [String] Conversation UUID
      # @return [String, nil] Label value or nil
      def label(uuid)
        conversation = Conversation.find(id: uuid)
        conversation&.label
      end

      # Set the label for a conversation
      #
      # @param uuid [String] Conversation UUID
      # @param value [String] Label value
      # @return [String] The label value
      # @raise [Error] If label format is invalid or already in use
      def set_label(uuid, value)
        conversation = Conversation.find(id: uuid)
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

        Conversation.where(id: uuid).update(label: value)
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

        query = Conversation.where(user_id: user_id.to_s, label: label)
        query = query.exclude(id: exclude_uuid) if exclude_uuid
        query.count > 0
      end

      # List all conversations for a user
      # Sorted by updated_at in descending order (most recently updated first)
      #
      # @param user_id [String] User identifier
      # @param archived [Boolean, nil] Filter by archived status (nil = all, true = archived only, false = unarchived only)
      # @return [Array<Hash>] Array of {uuid, label, updated_at} hashes
      def list_by_user(user_id, archived: false)
        dataset = Conversation.where(user_id: user_id.to_s)
        dataset = dataset.where(archived: archived) unless archived.nil?
        dataset.order(Sequel.desc(:updated_at)).all.map do |conv|
          {uuid: conv.id, label: conv.label, updated_at: conv.updated_at}
        end
      end

      # Find conversation UUID by label for a user
      #
      # @param user_id [String] User identifier
      # @param label [String] Label to search for
      # @return [String, nil] UUID or nil if not found
      def find_by_label(user_id, label)
        conversation = Conversation.where(user_id: user_id.to_s, label: label).first
        conversation&.id
      end

      # Archive a conversation by label or UUID, or archive current if no identifier given
      # When archiving current conversation, automatically creates a new one
      #
      # @param user_id [String] User identifier
      # @param identifier [String, nil] Conversation label or UUID to archive (nil = archive current)
      # @return [Hash] Hash with :archived and :new_conversation keys
      # @raise [Error] If conversation not found
      def archive(user_id, identifier = nil)
        user_key = user_id.to_s
        identifier = identifier.to_s.strip

        if identifier.empty?
          # Archive current conversation
          conversation = Conversation.where(user_id: user_key, is_current: true).first
          raise Error, "No current conversation to archive" unless conversation

          # Archive the current conversation
          conversation.update(archived: true, is_current: false)

          # Create a new conversation (becomes current)
          new_conversation = create_new(user_key)

          {
            archived: Conversation[conversation.id],
            new_conversation: new_conversation
          }
        else
          # Archive by label or UUID
          conversation = Conversation.where(user_id: user_key, label: identifier).first
          conversation ||= Conversation.find(id: identifier, user_id: user_key)

          raise Error, "Conversation '#{identifier}' not found" unless conversation

          # Cannot archive current conversation (must use archive without args)
          raise Error, "Cannot archive the current conversation. Use /archive without arguments to archive current and start new." if conversation.is_current

          conversation.update(archived: true, is_current: false)
          {archived: Conversation[conversation.id]}
        end
      end
    end
  end
end
