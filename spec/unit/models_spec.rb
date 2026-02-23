# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Conversation do
  before(:all) do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end

  before do
    # Ensure clean state for each test within the transaction
    Botiasloop::Conversation.dataset.delete
    Botiasloop::Conversation::Message.dataset.delete
  end

  describe "validations" do
    it "requires user_id" do
      conversation = described_class.new(label: "test")
      expect(conversation.valid?).to be false
    end

    it "generates a human-readable ID if not provided" do
      conversation = described_class.new(user_id: "user1")
      conversation.save
      expect(conversation.id).to match(/\A[a-z]+(-[a-z]+)+-[0-9]{3}\z/)
    end

    it "allows custom ID" do
      conversation = described_class.new(id: "custom-convo-123", user_id: "user1")
      expect(conversation.id).to eq("custom-convo-123")
    end
  end

  describe "associations" do
    it "has many messages" do
      conversation = described_class.create(user_id: "user1")
      conversation.add_message(role: "user", content: "hello", timestamp: Time.now)
      conversation.add_message(role: "assistant", content: "hi", timestamp: Time.now)
      expect(conversation.messages.count).to eq(2)
    end

    it "deletes messages when conversation is deleted" do
      conversation = described_class.create(user_id: "user1")
      conversation.add_message(role: "user", content: "hello", timestamp: Time.now)
      conversation.destroy
      expect(Botiasloop::Conversation::Message.count).to eq(0)
    end
  end

  describe "label uniqueness" do
    it "allows same label for different users" do
      described_class.create(user_id: "user1", label: "project")
      conversation2 = described_class.new(user_id: "user2", label: "project")
      expect { conversation2.save }.not_to raise_error
    end

    it "prevents duplicate labels for same user" do
      described_class.create(user_id: "user1", label: "project")
      conversation2 = described_class.new(user_id: "user1", label: "project")
      expect { conversation2.save }.to raise_error(Sequel::ValidationFailed)
    end
  end

  describe "instance methods" do
    describe "#last_activity" do
      it "returns timestamp of last message" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "hello", timestamp: Time.parse("2026-01-01T10:00:00Z"))
        conversation.add_message(role: "assistant", content: "hi", timestamp: Time.parse("2026-01-01T11:00:00Z"))
        expect(conversation.last_activity).to eq("2026-01-01T11:00:00Z")
      end

      it "returns nil if no messages" do
        conversation = described_class.create(user_id: "user1")
        expect(conversation.last_activity).to be_nil
      end
    end

    describe "#history" do
      it "returns messages as array of hashes" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "hello", timestamp: Time.parse("2026-01-01T10:00:00Z"))
        history = conversation.history
        expect(history).to be_an(Array)
        expect(history.first[:role]).to eq("user")
        expect(history.first[:content]).to eq("hello")
      end
    end

    describe "#add_message" do
      it "adds a message to the conversation" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "test message")
        expect(conversation.messages.count).to eq(1)
        message = conversation.messages.first
        expect(message.role).to eq("user")
        expect(message.content).to eq("test message")
      end

      it "sets timestamp automatically" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "test")
        message = conversation.messages.first
        expect(message.timestamp).to be_within(1).of(Time.now)
      end
    end

    describe "#reset!" do
      it "deletes all messages" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "hello")
        conversation.reset!
        expect(conversation.messages.count).to eq(0)
      end
    end

    describe "#compact!" do
      it "replaces all messages with summary and recent messages" do
        conversation = described_class.create(user_id: "user1")
        conversation.add_message(role: "user", content: "old1")
        conversation.add_message(role: "assistant", content: "old2")
        conversation.add_message(role: "user", content: "recent")
        conversation.compact!("summary text", [{role: "user", content: "recent"}])
        messages = conversation.reload.messages
        expect(messages.count).to eq(2)
        expect(messages.first.role).to eq("system")
        expect(messages.first.content).to eq("summary text")
      end
    end
  end
end

RSpec.describe Botiasloop::Conversation::Message do
  before(:all) do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end

  before do
    # Ensure clean state for each test within the transaction
    Botiasloop::Conversation.dataset.delete
    Botiasloop::Conversation::Message.dataset.delete
  end

  describe "validations" do
    it "requires conversation_id" do
      message = described_class.new(role: "user", content: "hello")
      expect(message.valid?).to be false
    end

    it "requires role" do
      conversation = Botiasloop::Conversation.create(user_id: "user1")
      message = described_class.new(conversation_id: conversation.id, content: "hello")
      expect(message.valid?).to be false
    end

    it "requires content" do
      conversation = Botiasloop::Conversation.create(user_id: "user1")
      message = described_class.new(conversation_id: conversation.id, role: "user")
      expect(message.valid?).to be false
    end
  end

  describe "associations" do
    it "belongs to conversation" do
      conversation = Botiasloop::Conversation.create(user_id: "user1")
      message = described_class.create(conversation_id: conversation.id, role: "user", content: "hello")
      expect(message.conversation.id).to eq(conversation.id)
    end
  end

  describe "to_hash" do
    it "returns message as hash with symbol keys" do
      conversation = Botiasloop::Conversation.create(user_id: "user1")
      message = described_class.create(
        conversation_id: conversation.id,
        role: "user",
        content: "hello",
        timestamp: Time.parse("2026-01-01T10:00:00Z")
      )
      hash = message.to_hash
      expect(hash[:role]).to eq("user")
      expect(hash[:content]).to eq("hello")
      expect(hash[:timestamp]).to match(/2026-01-01T10:00:00/)
    end
  end
end
