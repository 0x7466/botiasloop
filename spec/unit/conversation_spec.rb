# frozen_string_literal: true

require "spec_helper"
require "securerandom"
require "json"
require "time"
require "tmpdir"

RSpec.describe Botiasloop::Conversation do
  let(:temp_dir) { Dir.mktmpdir("conversations") }
  let(:fixed_uuid) { "550e8400-e29b-41d4-a716-446655440000" }

  before do
    # Mock all filesystem paths to use temp directory - NEVER touch real user directories
    allow(Dir).to receive(:home).and_return(temp_dir)
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with("~/conversations/#{fixed_uuid}.jsonl").and_return(File.join(temp_dir, "conversations", "#{fixed_uuid}.jsonl"))
    allow(File).to receive(:expand_path).with("~/.config/botiasloop/conversations.json").and_return(File.join(temp_dir, "conversations.json"))
    allow(File).to receive(:expand_path).with("~/.config/botiasloop/current.json").and_return(File.join(temp_dir, "current.json"))
    allow(Botiasloop::ConversationManager).to receive(:mapping_file).and_return(File.join(temp_dir, "conversations.json"))
    allow(Botiasloop::ConversationManager).to receive(:current_file).and_return(File.join(temp_dir, "current.json"))
    Botiasloop::ConversationManager.clear_all if Botiasloop::ConversationManager.respond_to?(:clear_all)
  end

  after do
    # Only cleanup temp directory - NEVER touch real user directories like ~/.config or ~/conversations
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    context "with no uuid provided" do
      it "generates a new uuid" do
        allow(SecureRandom).to receive(:uuid).and_return(fixed_uuid)
        conversation = described_class.new
        expect(conversation.uuid).to eq(fixed_uuid)
      end
    end

    context "with uuid provided" do
      it "uses the provided uuid" do
        conversation = described_class.new(fixed_uuid)
        expect(conversation.uuid).to eq(fixed_uuid)
      end
    end
  end

  describe "#path" do
    it "returns the correct path" do
      conversation = described_class.new(fixed_uuid)
      expect(conversation.path).to eq(File.join(temp_dir, "conversations", "#{fixed_uuid}.jsonl"))
    end
  end

  describe "#add" do
    let(:conversation) { described_class.new(fixed_uuid) }

    it "adds a message to the conversation" do
      conversation.add("user", "Hello")
      expect(conversation.history.length).to eq(1)
      expect(conversation.history.first[:role]).to eq("user")
      expect(conversation.history.first[:content]).to eq("Hello")
    end

    it "persists to file" do
      conversation.add("user", "Hello")
      expect(File.exist?(conversation.path)).to be true

      lines = File.readlines(conversation.path)
      expect(lines.length).to eq(1)

      data = JSON.parse(lines.first, symbolize_names: true)
      expect(data[:role]).to eq("user")
      expect(data[:content]).to eq("Hello")
      expect(data[:timestamp]).to be_a(String)
    end

    it "appends multiple messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi there!")

      lines = File.readlines(conversation.path)
      expect(lines.length).to eq(2)

      data1 = JSON.parse(lines[0], symbolize_names: true)
      data2 = JSON.parse(lines[1], symbolize_names: true)

      expect(data1[:role]).to eq("user")
      expect(data2[:role]).to eq("assistant")
    end
  end

  describe "#history" do
    let(:conversation) { described_class.new(fixed_uuid) }

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

    it "loads from file when conversation exists" do
      conversation.add("user", "Hello")

      # Create new instance with same uuid
      conversation2 = described_class.new(fixed_uuid)
      expect(conversation2.history.length).to eq(1)
      expect(conversation2.history.first[:content]).to eq("Hello")
    end

    it "returns a copy of messages" do
      conversation.add("user", "Hello")
      history = conversation.history
      history.clear
      expect(conversation.history.length).to eq(1)
    end
  end

  describe "timestamp" do
    let(:conversation) { described_class.new(fixed_uuid) }
    let(:fixed_time) { Time.parse("2026-02-20T10:00:00Z") }

    it "includes ISO8601 timestamp" do
      allow(Time).to receive(:now).and_return(fixed_time)
      conversation.add("user", "Hello")

      lines = File.readlines(conversation.path)
      data = JSON.parse(lines.first, symbolize_names: true)
      expect(data[:timestamp]).to eq("2026-02-20T10:00:00Z")
    end
  end

  describe "#reset!" do
    let(:conversation) { described_class.new(fixed_uuid) }

    it "clears all messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      conversation.reset!

      expect(conversation.history).to be_empty
    end

    it "clears the file" do
      conversation.add("user", "Hello")
      conversation.reset!

      expect(File.exist?(conversation.path)).to be true
      lines = File.readlines(conversation.path)
      expect(lines).to all(be_empty.or(be_nil))
    end
  end

  describe "#compact!" do
    let(:conversation) { described_class.new(fixed_uuid) }

    before do
      # Add some messages
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
      expect(history.length).to eq(3)  # summary system + 2 recent
      expect(history[0][:role]).to eq("system")
      expect(history[0][:content]).to eq("Summary of earlier discussion")
      expect(history[1][:content]).to eq("Recent 1")
      expect(history[2][:content]).to eq("Recent 2")
    end

    it "persists compacted history to file" do
      summary = "Summary"
      recent = [{role: "user", content: "Last message"}]

      conversation.compact!(summary, recent)

      # Reload from file
      conversation2 = described_class.new(fixed_uuid)
      expect(conversation2.history.length).to eq(2)
      expect(conversation2.history[0][:content]).to eq("Summary")
    end
  end

  describe "#label" do
    let(:conversation) { described_class.new(fixed_uuid) }

    before do
      # Set up the conversation in the manager
      Botiasloop::ConversationManager.switch("test-user", fixed_uuid)
    end

    it "returns nil when conversation has no label" do
      expect(conversation.label).to be_nil
    end

    it "returns the label when set via manager" do
      Botiasloop::ConversationManager.label(fixed_uuid, "my-project")
      expect(conversation.label).to eq("my-project")
    end
  end

  describe "#label=" do
    let(:conversation) { described_class.new(fixed_uuid) }

    before do
      Botiasloop::ConversationManager.switch("test-user", fixed_uuid)
    end

    it "sets the label via manager" do
      conversation.label = "my-label"
      expect(conversation.label).to eq("my-label")
    end

    it "persists the label" do
      conversation.label = "persisted-label"

      # Create new instance with same uuid
      conversation2 = described_class.new(fixed_uuid)
      expect(conversation2.label).to eq("persisted-label")
    end

    it "delegates validation to manager" do
      expect {
        conversation.label = "invalid label"
      }.to raise_error(Botiasloop::Error, /Invalid label format/)
    end
  end

  describe "#label?" do
    let(:conversation) { described_class.new(fixed_uuid) }

    before do
      Botiasloop::ConversationManager.switch("test-user", fixed_uuid)
    end

    it "returns false when no label is set" do
      expect(conversation.label?).to be false
    end

    it "returns true when label is set" do
      conversation.label = "my-label"
      expect(conversation.label?).to be true
    end
  end

  describe "#message_count" do
    let(:conversation) { described_class.new(fixed_uuid) }

    before do
      Botiasloop::ConversationManager.switch("test-user", fixed_uuid)
    end

    it "returns 0 for empty conversation" do
      expect(conversation.message_count).to eq(0)
    end

    it "returns the number of messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")
      conversation.add("user", "How are you?")

      expect(conversation.message_count).to eq(3)
    end

    it "returns correct count after loading from file" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      # Create new instance with same uuid
      conversation2 = described_class.new(fixed_uuid)
      expect(conversation2.message_count).to eq(2)
    end
  end

  describe "#last_activity" do
    let(:conversation) { described_class.new(fixed_uuid) }
    let(:fixed_time1) { Time.parse("2026-02-20T10:00:00Z") }
    let(:fixed_time2) { Time.parse("2026-02-20T11:30:00Z") }

    before do
      Botiasloop::ConversationManager.switch("test-user", fixed_uuid)
    end

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

    it "persists after loading from file" do
      allow(Time).to receive(:now).and_return(fixed_time1)
      conversation.add("user", "Hello")

      # Create new instance with same uuid
      conversation2 = described_class.new(fixed_uuid)
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
