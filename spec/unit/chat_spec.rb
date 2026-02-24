# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Chat do
  # Generate unique external IDs for each test to avoid uniqueness conflicts
  def unique_external_id
    "test-#{SecureRandom.hex(8)}"
  end

  describe ".find_or_create" do
    it "creates a new chat if one does not exist" do
      chat = described_class.find_or_create("telegram", unique_external_id, user_identifier: "testuser")

      expect(chat).to be_a(described_class)
      expect(chat.channel).to eq("telegram")
      expect(chat.user_identifier).to eq("testuser")
      expect(chat.id).not_to be_nil
    end

    it "returns existing chat if one already exists for channel/external_id" do
      ext_id = unique_external_id
      chat1 = described_class.create(channel: "telegram", external_id: ext_id)
      chat2 = described_class.find_or_create("telegram", ext_id)

      expect(chat2.id).to eq(chat1.id)
    end

    it "creates different chats for different external_ids" do
      chat1 = described_class.find_or_create("telegram", unique_external_id)
      chat2 = described_class.find_or_create("telegram", unique_external_id)

      expect(chat1.id).not_to eq(chat2.id)
    end

    it "creates different chats for different channels" do
      ext_id = unique_external_id
      chat1 = described_class.find_or_create("telegram", ext_id)
      chat2 = described_class.find_or_create("cli", ext_id)

      expect(chat1.id).not_to eq(chat2.id)
    end

    it "allows nil user_identifier" do
      chat = described_class.find_or_create("cli", unique_external_id)

      expect(chat.user_identifier).to be_nil
    end
  end

  describe "#current_conversation" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "creates a new conversation if none exists" do
      conversation = chat.current_conversation

      expect(conversation).to be_a(Botiasloop::Conversation)
      expect(chat.reload.current_conversation_id).to eq(conversation.id)
    end

    it "returns existing conversation if one exists" do
      conversation1 = chat.current_conversation
      conversation2 = chat.current_conversation

      expect(conversation2.id).to eq(conversation1.id)
    end

    it "creates new conversation if current is archived" do
      conversation = chat.current_conversation
      conversation.archive!

      new_conversation = chat.current_conversation

      expect(new_conversation.id).not_to eq(conversation.id)
      expect(new_conversation).not_to be_archived
    end
  end

  describe "#switch_conversation" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }
    let!(:conversation1) { chat.create_new_conversation }
    let!(:conversation2) { chat.create_new_conversation }
    let(:unique_label) { "my-project-#{SecureRandom.hex(4)}" }

    before do
      conversation2.update(label: unique_label)
    end

    it "switches to conversation by label" do
      chat.update(current_conversation_id: conversation1.id)

      result = chat.switch_conversation(unique_label)

      expect(result.id).to eq(conversation2.id)
      expect(chat.reload.current_conversation_id).to eq(conversation2.id)
    end

    it "switches to conversation by ID" do
      chat.update(current_conversation_id: conversation1.id)

      result = chat.switch_conversation(conversation2.id)

      expect(result.id).to eq(conversation2.id)
      expect(chat.reload.current_conversation_id).to eq(conversation2.id)
    end

    it "is case-insensitive for ID matching" do
      chat.update(current_conversation_id: conversation1.id)

      result = chat.switch_conversation(conversation2.id.upcase)

      expect(result.id).to eq(conversation2.id)
    end

    it "auto-unarchives archived conversations when switching" do
      conversation2.update(archived: true)
      chat.update(current_conversation_id: conversation1.id)

      chat.switch_conversation(unique_label)

      expect(conversation2.reload).not_to be_archived
    end

    it "raises error when identifier is empty" do
      expect do
        chat.switch_conversation("")
      end.to raise_error(Botiasloop::Error, %r{Usage: /switch})
    end

    it "raises error when conversation not found" do
      expect do
        chat.switch_conversation("non-existent")
      end.to raise_error(Botiasloop::Error, /Conversation 'non-existent' not found/)
    end
  end

  describe "#create_new_conversation" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "creates a new conversation" do
      conversation = chat.create_new_conversation

      expect(conversation).to be_a(Botiasloop::Conversation)
    end

    it "sets the new conversation as current" do
      conversation = chat.create_new_conversation

      expect(chat.reload.current_conversation_id).to eq(conversation.id)
    end

    it "creates unique conversations each time" do
      conversation1 = chat.create_new_conversation
      conversation2 = chat.create_new_conversation

      expect(conversation1.id).not_to eq(conversation2.id)
      expect(chat.reload.current_conversation_id).to eq(conversation2.id)
    end
  end

  describe "#active_conversations" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "returns only non-archived conversations" do
      chat.create_new_conversation
      conversation2 = chat.create_new_conversation
      conversation2.archive!

      active = chat.active_conversations
      expect(active.length).to eq(1)
      expect(active.first).not_to be_archived
    end

    it "sorts by updated_at descending" do
      chat.create_new_conversation
      conversation2 = chat.create_new_conversation

      active = chat.active_conversations
      expect(active.first.id).to eq(conversation2.id)
    end
  end

  describe "#archived_conversations" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "returns only archived conversations" do
      chat.create_new_conversation
      conversation2 = chat.create_new_conversation
      conversation2.archive!

      archived = chat.archived_conversations
      expect(archived.length).to eq(1)
      expect(archived.first).to be_archived
    end

    it "returns empty array when no archived conversations" do
      chat.create_new_conversation

      expect(chat.archived_conversations).to be_empty
    end
  end

  describe "#archive_current" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "archives the current conversation" do
      old_conversation = chat.current_conversation

      result = chat.archive_current

      expect(result[:archived].id).to eq(old_conversation.id)
      expect(result[:archived]).to be_archived
    end

    it "creates a new conversation" do
      old_conversation = chat.current_conversation

      result = chat.archive_current

      expect(result[:new_conversation].id).not_to eq(old_conversation.id)
      expect(result[:new_conversation]).not_to be_archived
    end

    it "sets the new conversation as current" do
      chat.current_conversation

      result = chat.archive_current

      expect(chat.reload.current_conversation_id).to eq(result[:new_conversation].id)
    end

    it "raises error when no current conversation" do
      chat.update(current_conversation_id: nil)

      expect do
        chat.archive_current
      end.to raise_error(Botiasloop::Error, /No current conversation to archive/)
    end
  end

  describe "validations" do
    it "requires channel" do
      chat = described_class.new(external_id: unique_external_id)
      expect(chat.valid?).to be false
    end

    it "requires external_id" do
      chat = described_class.new(channel: "telegram")
      expect(chat.valid?).to be false
    end

    it "requires unique combination of channel and external_id" do
      ext_id = unique_external_id
      described_class.create(channel: "telegram", external_id: ext_id)
      chat = described_class.new(channel: "telegram", external_id: ext_id)

      expect(chat.valid?).to be false
    end
  end

  describe "timestamps" do
    let(:chat) { described_class.create(channel: "telegram", external_id: unique_external_id) }

    it "sets created_at on creation" do
      expect(chat.created_at).not_to be_nil
    end

    it "sets updated_at on creation" do
      expect(chat.updated_at).not_to be_nil
    end

    it "updates updated_at on modification" do
      original_time = chat.updated_at
      sleep(0.1)
      chat.update(user_identifier: "newuser")

      expect(chat.reload.updated_at).to be > original_time
    end
  end
end
