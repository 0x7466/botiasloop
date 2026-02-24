# frozen_string_literal: true

require "time"

module Botiasloop
  # Chat model - represents a communication channel between user(s) and agent
  # A chat belongs to a specific channel (telegram, cli) and external source (chat_id)
  # Each chat tracks its current conversation (which can be any conversation in the system)
  class Chat < Sequel::Model(:chats)
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true

    many_to_one :current_conversation, class: "Botiasloop::Conversation", key: :current_conversation_id

    # Validations
    def validate
      super
      validates_presence %i[channel external_id]
      validates_unique %i[channel external_id]
    end

    # Class method to find or create a chat by channel and external_id
    #
    # @param channel [String] Channel type (e.g., "telegram", "cli")
    # @param external_id [String] External identifier (e.g., chat_id, "cli")
    # @param user_identifier [String, nil] Optional user identifier (e.g., telegram username)
    # @return [Chat] Found or created chat
    def self.find_or_create(channel, external_id, user_identifier: nil)
      chat = find(channel: channel, external_id: external_id)
      return chat if chat

      create(
        channel: channel,
        external_id: external_id,
        user_identifier: user_identifier
      )
    end

    # Get the current conversation for this chat
    # Creates a new conversation if none exists or current is archived
    #
    # @return [Conversation] Current active conversation
    def current_conversation
      conv = super

      if conv.nil? || conv.archived
        conv = create_new_conversation
        update(current_conversation_id: conv.id)
      end

      conv
    end

    # Switch to a different conversation by label or conversation ID
    #
    # @param identifier [String] Conversation label or human-readable ID
    # @return [Conversation] The switched-to conversation
    # @raise [Error] If conversation not found
    def switch_conversation(identifier)
      identifier = identifier.to_s.strip
      raise Error, "Usage: /switch <label-or-id>" if identifier.empty?

      # First try to find by label
      conversation = Conversation.find(label: identifier)

      # If not found by label, treat as ID (case-insensitive)
      unless conversation
        normalized_id = HumanId.normalize(identifier)
        conversation = Conversation.all.find { |c| HumanId.normalize(c.id) == normalized_id }
      end

      raise Error, "Conversation '#{identifier}' not found" unless conversation

      # Auto-unarchive if switching to archived conversation
      conversation.update(archived: false) if conversation.archived

      update(current_conversation_id: conversation.id)
      conversation
    end

    # Create a new conversation and make it current for this chat
    #
    # @return [Conversation] The newly created conversation
    def create_new_conversation
      conversation = Conversation.create
      update(current_conversation_id: conversation.id)
      conversation
    end

    # List all non-archived conversations in the system
    # Sorted by updated_at in descending order (most recently updated first)
    #
    # @return [Array<Conversation>] Array of conversations
    def active_conversations
      Conversation.where(archived: false).order(Sequel.desc(:updated_at)).all
    end

    # List all archived conversations in the system
    #
    # @return [Array<Conversation>] Array of archived conversations
    def archived_conversations
      Conversation.where(archived: true).order(Sequel.desc(:updated_at)).all
    end

    # Archive the current conversation and create a new one
    #
    # @return [Hash] Hash with :archived and :new_conversation keys
    def archive_current
      current = current_conversation if current_conversation_id

      raise Error, "No current conversation to archive" unless current

      current.update(archived: true)
      new_conversation = create_new_conversation

      {
        archived: current,
        new_conversation: new_conversation
      }
    end
  end
end
