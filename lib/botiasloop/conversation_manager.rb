# frozen_string_literal: true

require "json"
require "fileutils"

module Botiasloop
  # Manages conversation state globally, mapping user IDs to conversation UUIDs
  # This class provides a centralized way to track and switch between conversations
  # across all channels.
  class ConversationManager
    # Valid label format: alphanumeric, dashes, and underscores
    LABEL_REGEX = /\A[a-zA-Z0-9_-]+\z/

    class << self
      # Path to the global conversation mapping file
      # @return [String] Path to the mapping file
      def mapping_file
        File.expand_path("~/.config/botiasloop/conversations.json")
      end

      # Path to the current conversation tracking file
      # @return [String] Path to the current tracking file
      def current_file
        File.expand_path("~/.config/botiasloop/current.json")
      end

      # Get or create the current conversation for a user
      #
      # @param user_id [String] User identifier
      # @return [Conversation] Current conversation for the user
      def current_for(user_id)
        user_key = user_id.to_s
        uuid = current_uuid_for(user_key)

        if uuid
          Conversation.new(uuid)
        else
          conversation = Conversation.new
          create_mapping_entry(conversation.uuid, user_key)
          set_current_uuid(user_key, conversation.uuid)
          conversation
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
        uuid = find_by_label(user_key, identifier)

        # If not found by label, treat as UUID
        uuid ||= identifier

        # Ensure the conversation exists in mapping (create if not)
        unless mapping.key?(uuid)
          create_mapping_entry(uuid, user_key)
        end

        # Update the user_id for this conversation if switching ownership
        entry = mapping[uuid]
        entry["user_id"] = user_key
        save_mapping

        set_current_uuid(user_key, uuid)
        Conversation.new(uuid)
      end

      # Create a new conversation and switch the user to it
      #
      # @param user_id [String] User identifier
      # @return [Conversation] The newly created conversation
      def create_new(user_id)
        user_key = user_id.to_s
        conversation = Conversation.new
        create_mapping_entry(conversation.uuid, user_key)
        set_current_uuid(user_key, conversation.uuid)
        conversation
      end

      # Get the UUID for a user's current conversation
      #
      # @param user_id [String] User identifier
      # @return [String, nil] Current conversation UUID or nil if none exists
      def current_uuid_for(user_id)
        user_key = user_id.to_s
        current_data[user_key]
      end

      # List all conversation mappings
      #
      # @return [Hash] Hash mapping UUIDs to {user_id, label} hashes
      def all_mappings
        mapping.dup.transform_values(&:dup)
      end

      # Remove a user's conversation mapping
      #
      # @param user_id [String] User identifier
      def remove(user_id)
        user_key = user_id.to_s
        uuid = current_uuid_for(user_key)
        return unless uuid

        mapping.delete(uuid)
        save_mapping

        current_data.delete(user_key)
        save_current
      end

      # Clear all mappings (use with caution)
      def clear_all
        @mapping = {}
        @current = {}
        save_mapping
        save_current
      end

      # Get or set the label for a conversation
      # Called as label(uuid) to get, label(uuid, value) to set
      #
      # @param uuid [String] Conversation UUID
      # @param value [String, nil] Label value to set (optional)
      # @return [String, nil] Label value or nil
      # @raise [Error] If setting and label format is invalid or already in use
      def label(uuid, value = nil)
        if value.nil? && !block_given?
          # Getter mode
          entry = mapping[uuid]
          entry&.dig("label")
        else
          # Setter mode
          set_label(uuid, value)
        end
      end

      # Set the label for a conversation (explicit setter)
      #
      # @param uuid [String] Conversation UUID
      # @param value [String] Label value
      # @return [String] The label value
      # @raise [Error] If label format is invalid or already in use by same user
      def set_label(uuid, value)
        # Validate conversation exists
        entry = mapping[uuid]
        raise Error, "Conversation not found" unless entry

        user_id = entry["user_id"]
        current_label = entry["label"]

        # If setting same label, no-op
        return value if current_label == value

        # Validate label format
        unless value.nil? || value.to_s.match?(LABEL_REGEX)
          raise Error, "Invalid label format. Use only letters, numbers, dashes, and underscores."
        end

        # Check uniqueness per user (excluding current conversation)
        if value && label_exists?(user_id, value, exclude_uuid: uuid)
          raise Error, "Label '#{value}' already in use by another conversation"
        end

        entry["label"] = value
        save_mapping
        value
      end

      # Check if a label exists for a user
      #
      # @param user_id [String] User identifier
      # @param label [String] Label to check
      # @param exclude_uuid [String, nil] UUID to exclude from check
      # @return [Boolean] True if label exists for user
      def label_exists?(user_id, label, exclude_uuid: nil)
        user_key = user_id.to_s
        mapping.any? do |uuid, data|
          next if exclude_uuid && uuid == exclude_uuid
          data["user_id"] == user_key && data["label"] == label
        end
      end

      # List all conversations for a user
      #
      # @param user_id [String] User identifier
      # @return [Array<Hash>] Array of {uuid, label} hashes
      def list_by_user(user_id)
        user_key = user_id.to_s
        mapping.filter_map do |uuid, data|
          next unless data["user_id"] == user_key
          {uuid: uuid, label: data["label"]}
        end
      end

      # Find conversation UUID by label for a user
      #
      # @param user_id [String] User identifier
      # @param label [String] Label to search for
      # @return [String, nil] UUID or nil if not found
      def find_by_label(user_id, label)
        user_key = user_id.to_s
        entry = mapping.find do |_uuid, data|
          data["user_id"] == user_key && data["label"] == label
        end
        entry&.first
      end

      private

      def mapping
        @mapping ||= load_mapping
      end

      def current_data
        @current ||= load_current
      end

      def load_mapping
        return {} unless File.exist?(mapping_file)

        data = JSON.parse(File.read(mapping_file), symbolize_names: false)
        # Handle old format migration
        if data.is_a?(Hash) && data.key?("conversations")
          migrate_old_format(data["conversations"])
        else
          data || {}
        end
      rescue JSON::ParserError
        {}
      end

      def load_current
        return {} unless File.exist?(current_file)

        JSON.parse(File.read(current_file), symbolize_names: false) || {}
      rescue JSON::ParserError
        {}
      end

      def migrate_old_format(old_conversations)
        # Old format was { "user_id": "uuid" }
        # New format is { "uuid": { "user_id": "xxx", "label": "xxx" } }
        new_mapping = {}
        old_conversations.each do |user_id, uuid|
          new_mapping[uuid] = {"user_id" => user_id.to_s, "label" => nil}
        end
        new_mapping
      end

      def save_mapping
        FileUtils.mkdir_p(File.dirname(mapping_file))
        File.write(mapping_file, JSON.pretty_generate(mapping))
      end

      def save_current
        FileUtils.mkdir_p(File.dirname(current_file))
        File.write(current_file, JSON.pretty_generate(current_data))
      end

      def create_mapping_entry(uuid, user_id)
        mapping[uuid] = {"user_id" => user_id.to_s, "label" => nil}
        save_mapping
      end

      def set_current_uuid(user_id, uuid)
        current_data[user_id.to_s] = uuid
        save_current
      end
    end
  end
end
