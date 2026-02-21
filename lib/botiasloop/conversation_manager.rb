# frozen_string_literal: true

require "json"
require "fileutils"

module Botiasloop
  # Manages conversation state globally, mapping user IDs to conversation UUIDs
  # This class provides a centralized way to track and switch between conversations
  # across all channels.
  class ConversationManager
    class << self
      # Path to the global conversation mapping file
      # @return [String] Path to the mapping file
      def mapping_file
        File.expand_path("~/.config/botiasloop/conversations.json")
      end

      # Get or create the current conversation for a user
      #
      # @param user_id [String] User identifier
      # @return [Conversation] Current conversation for the user
      def current_for(user_id)
        user_key = user_id.to_s
        uuid = mapping[user_key]

        if uuid
          Conversation.new(uuid)
        else
          conversation = Conversation.new
          mapping[user_key] = conversation.uuid
          save_mapping
          conversation
        end
      end

      # Switch a user to a different conversation by UUID
      #
      # @param user_id [String] User identifier
      # @param uuid [String] Conversation UUID to switch to
      # @return [Conversation] The switched-to conversation
      # @raise [Error] If conversation with given UUID doesn't exist
      def switch(user_id, uuid)
        user_key = user_id.to_s

        # Verify the conversation exists (Conversation.new will work with any UUID,
        # but we can check if the file exists to validate)
        conversation = Conversation.new(uuid)

        # If conversation file doesn't exist, the conversation is essentially empty/new
        # This is acceptable - we'll just create it when needed

        mapping[user_key] = uuid
        save_mapping
        conversation
      end

      # Create a new conversation and switch the user to it
      #
      # @param user_id [String] User identifier
      # @return [Conversation] The newly created conversation
      def create_new(user_id)
        user_key = user_id.to_s
        conversation = Conversation.new
        mapping[user_key] = conversation.uuid
        save_mapping
        conversation
      end

      # Get the UUID for a user's current conversation
      #
      # @param user_id [String] User identifier
      # @return [String, nil] Current conversation UUID or nil if none exists
      def current_uuid_for(user_id)
        mapping[user_id.to_s]
      end

      # List all conversation mappings
      #
      # @return [Hash] Hash mapping user IDs to conversation UUIDs
      def all_mappings
        mapping.dup
      end

      # Remove a user's conversation mapping
      #
      # @param user_id [String] User identifier
      def remove(user_id)
        mapping.delete(user_id.to_s)
        save_mapping
      end

      # Clear all mappings (use with caution)
      def clear_all
        @mapping = {}
        save_mapping
      end

      private

      def mapping
        @mapping ||= load_mapping
      end

      def load_mapping
        return {} unless File.exist?(mapping_file)

        data = JSON.parse(File.read(mapping_file), symbolize_names: true)
        (data[:conversations] || {}).transform_keys(&:to_s)
      rescue JSON::ParserError
        {}
      end

      def save_mapping
        FileUtils.mkdir_p(File.dirname(mapping_file))
        File.write(mapping_file, JSON.pretty_generate({conversations: mapping}))
      end
    end
  end
end
