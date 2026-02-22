# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Conversation do
  before do
    Botiasloop::Database.setup!
  end

  after do
    Botiasloop::Database.reset!
  end

  describe "#initialize" do
    context "with no uuid provided" do
      it "generates a new uuid" do
        conversation = described_class.new
        expect(conversation.uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      end

      it "creates a new conversation in the database" do
        conversation = described_class.new
        model = Botiasloop::Models::Conversation.find(id: conversation.uuid)
        expect(model).not_to be_nil
        expect(model.user_id).to eq("default")
      end
    end

    context "with uuid provided" do
      it "uses the provided uuid when conversation exists" do
        # Create a conversation first
        model = Botiasloop::Models::Conversation.create(user_id: "test")
        conversation = described_class.new(model.id)
        expect(conversation.uuid).to eq(model.id)
      end

      it "raises error when conversation does not exist" do
        expect {
          described_class.new("nonexistent-uuid")
        }.to raise_error(Botiasloop::Error, /Conversation not found/)
      end
    end
  end

  describe "#path" do
    it "returns the uuid (for backward compatibility)" do
      conversation = described_class.new
      expect(conversation.path).to eq(conversation.uuid)
    end
  end

  describe "#add" do
    let(:conversation) { described_class.new }

    it "adds a message to the conversation" do
      conversation.add("user", "Hello")
      expect(conversation.history.length).to eq(1)
      expect(conversation.history.first[:role]).to eq("user")
      expect(conversation.history.first[:content]).to eq("Hello")
    end

    it "adds multiple messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi there!")

      expect(conversation.history.length).to eq(2)
      expect(conversation.history[0][:role]).to eq("user")
      expect(conversation.history[1][:role]).to eq("assistant")
    end

    it "includes ISO8601 timestamp" do
      fixed_time = Time.parse("2026-02-20T10:00:00Z")
      allow(Time).to receive(:now).and_return(fixed_time)

      conversation.add("user", "Hello")
      expect(conversation.history.first[:timestamp]).to match(/2026-02-20T10:00:00/)
    end
  end

  describe "#history" do
    let(:conversation) { described_class.new }

    it "returns empty array for new conversation" do
      expect(conversation.history).to eq([])
    end

    it "returns all messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      history = conversation.history
      expect(history.length).to eq(2)
      expect(history[0][:content]).to eq("Hello")
      expect(history[1][:content]).to eq("Hi!")
    end

    it "returns a copy of messages" do
      conversation.add("user", "Hello")
      history = conversation.history
      history.clear
      expect(conversation.history.length).to eq(1)
    end
  end

  describe "#reset!" do
    let(:conversation) { described_class.new }

    it "clears all messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      conversation.reset!

      expect(conversation.history).to be_empty
      expect(conversation.message_count).to eq(0)
    end
  end

  describe "#compact!" do
    let(:conversation) { described_class.new }

    before do
      10.times do |i|
        conversation.add(i.even? ? "user" : "assistant", "Message #{i}")
      end
    end

    it "replaces old messages with summary" do
      summary = "Summary of earlier discussion"
      recent_messages = [
        {role: "user", content: "Recent 1"},
        {role: "assistant", content: "Recent 2"}
      ]

      conversation.compact!(summary, recent_messages)

      history = conversation.history
      expect(history.length).to eq(3)
      expect(history[0][:role]).to eq("system")
      expect(history[0][:content]).to eq("Summary of earlier discussion")
      expect(history[1][:content]).to eq("Recent 1")
      expect(history[2][:content]).to eq("Recent 2")
    end

    it "persists after reloading" do
      summary = "Summary"
      recent = [{role: "user", content: "Last message"}]
      uuid = conversation.uuid

      conversation.compact!(summary, recent)

      # Reload from database
      conversation2 = described_class.new(uuid)
      expect(conversation2.history.length).to eq(2)
      expect(conversation2.history[0][:content]).to eq("Summary")
    end
  end

  describe "#label" do
    let(:conversation) { described_class.new }

    it "returns nil when conversation has no label" do
      expect(conversation.label).to be_nil
    end

    it "returns the label when set" do
      conversation.label = "my-project"
      expect(conversation.label).to eq("my-project")
    end
  end

  describe "#label=" do
    let(:conversation) { described_class.new }

    it "sets the label" do
      conversation.label = "my-label"
      expect(conversation.label).to eq("my-label")
    end

    it "persists the label" do
      uuid = conversation.uuid
      conversation.label = "persisted-label"

      # Create new instance with same uuid
      conversation2 = described_class.new(uuid)
      expect(conversation2.label).to eq("persisted-label")
    end

    it "raises error for invalid label format" do
      expect {
        conversation.label = "invalid label"
      }.to raise_error(Botiasloop::Error, /Invalid label format/)
    end
  end

  describe "#label?" do
    let(:conversation) { described_class.new }

    it "returns false when no label is set" do
      expect(conversation.label?).to be false
    end

    it "returns true when label is set" do
      conversation.label = "my-label"
      expect(conversation.label?).to be true
    end
  end

  describe "#message_count" do
    let(:conversation) { described_class.new }

    it "returns 0 for empty conversation" do
      expect(conversation.message_count).to eq(0)
    end

    it "returns the number of messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")
      conversation.add("user", "How are you?")

      expect(conversation.message_count).to eq(3)
    end

    it "returns correct count after reloading" do
      uuid = conversation.uuid
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      # Create new instance with same uuid
      conversation2 = described_class.new(uuid)
      expect(conversation2.message_count).to eq(2)
    end
  end

  describe "#last_activity" do
    let(:conversation) { described_class.new }
    let(:fixed_time1) { Time.parse("2026-02-20T10:00:00Z") }
    let(:fixed_time2) { Time.parse("2026-02-20T11:30:00Z") }

    it "returns nil for empty conversation" do
      expect(conversation.last_activity).to be_nil
    end

    it "returns the timestamp of the last message" do
      allow(Time).to receive(:now).and_return(fixed_time1)
      conversation.add("user", "First message")

      allow(Time).to receive(:now).and_return(fixed_time2)
      conversation.add("assistant", "Second message")

      expect(conversation.last_activity).to eq("2026-02-20T11:30:00Z")
    end

    it "persists after reloading" do
      uuid = conversation.uuid
      allow(Time).to receive(:now).and_return(fixed_time1)
      conversation.add("user", "Hello")

      # Create new instance with same uuid
      conversation2 = described_class.new(uuid)
      expect(conversation2.last_activity).to eq("2026-02-20T10:00:00Z")
    end

    it "updates when new message is added" do
      allow(Time).to receive(:now).and_return(fixed_time1)
      conversation.add("user", "First")

      expect(conversation.last_activity).to eq("2026-02-20T10:00:00Z")

      allow(Time).to receive(:now).and_return(fixed_time2)
      conversation.add("assistant", "Second")

      expect(conversation.last_activity).to eq("2026-02-20T11:30:00Z")
    end
  end
end
