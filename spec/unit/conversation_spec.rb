# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Conversation do
  before do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end

  describe "#initialize" do
    context "with no id provided" do
      it "generates a new human-readable id" do
        conversation = described_class.new
        expect(conversation.uuid).to match(/\A[a-z]+(-[a-z]+)+-[0-9]{3}\z/)
      end

      it "creates a new conversation in the database" do
        conversation = described_class.new
        conversation.user_id = "default"
        conversation.save
        expect(conversation).not_to be_nil
        expect(conversation.user_id).to eq("default")
      end
    end

    context "with id provided" do
      it "uses the provided id when conversation exists" do
        # Create a conversation first
        model = described_class.create(user_id: "test")
        conversation = described_class[model.id]
        expect(conversation.id).to eq(model.id)
      end

      it "returns nil when conversation does not exist" do
        conversation = described_class["nonexistent-id-999"]
        expect(conversation).to be_nil
      end
    end
  end

  describe "#add" do
    let(:conversation) { described_class.create(user_id: "test") }

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

    it "tracks input and output tokens" do
      conversation.add("assistant", "Hello", input_tokens: 100, output_tokens: 50)

      message = conversation.history.first
      expect(message[:input_tokens]).to eq(100)
      expect(message[:output_tokens]).to eq(50)
    end

    it "updates conversation token totals when adding messages" do
      conversation.add("user", "Hello", input_tokens: 10, output_tokens: 0)
      conversation.add("assistant", "Hi!", input_tokens: 100, output_tokens: 50)

      expect(conversation.input_tokens).to eq(110)
      expect(conversation.output_tokens).to eq(50)
      expect(conversation.total_tokens).to eq(160)
    end

    it "defaults to zero tokens when not specified" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      expect(conversation.input_tokens).to eq(0)
      expect(conversation.output_tokens).to eq(0)
    end

    it "handles nil token values" do
      conversation.add("assistant", "Hi!", input_tokens: nil, output_tokens: nil)

      message = conversation.history.first
      expect(message[:input_tokens]).to eq(0)
      expect(message[:output_tokens]).to eq(0)
      expect(conversation.input_tokens).to eq(0)
      expect(conversation.output_tokens).to eq(0)
    end
  end

  describe "#history" do
    let(:conversation) { described_class.create(user_id: "test") }

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

    it "includes token counts in message hashes" do
      conversation.add("assistant", "Response", input_tokens: 150, output_tokens: 75)

      message = conversation.history.first
      expect(message).to include(:input_tokens, :output_tokens)
      expect(message[:input_tokens]).to eq(150)
      expect(message[:output_tokens]).to eq(75)
    end
  end

  describe "#reset!" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "clears all messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      conversation.reset!

      expect(conversation.history).to be_empty
      expect(conversation.message_count).to eq(0)
    end

    it "resets token counts" do
      conversation.add("user", "Hello", input_tokens: 10, output_tokens: 0)
      conversation.add("assistant", "Hi!", input_tokens: 100, output_tokens: 50)

      conversation.reset!

      expect(conversation.input_tokens).to eq(0)
      expect(conversation.output_tokens).to eq(0)
      expect(conversation.total_tokens).to eq(0)
    end
  end

  describe "#compact!" do
    let(:conversation) { described_class.create(user_id: "test") }

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
      conversation2 = described_class[uuid]
      expect(conversation2.history.length).to eq(2)
      expect(conversation2.history[0][:content]).to eq("Summary")
    end
  end

  describe "#label" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "returns nil when conversation has no label" do
      expect(conversation.label).to be_nil
    end

    it "returns the label when set" do
      conversation.label = "my-project"
      expect(conversation.label).to eq("my-project")
    end
  end

  describe "#label=" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "sets the label" do
      conversation.label = "my-label"
      expect(conversation.label).to eq("my-label")
    end

    it "persists the label" do
      uuid = conversation.uuid
      conversation.update(label: "persisted-label")

      # Load existing conversation
      conversation2 = described_class[uuid]
      expect(conversation2.label).to eq("persisted-label")
    end

    it "raises error for invalid label format" do
      conversation.label = "invalid label"
      expect do
        conversation.save
      end.to raise_error(Sequel::ValidationFailed, /Invalid label format/)
    end
  end

  describe "#label?" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "returns false when no label is set" do
      expect(conversation.label?).to be false
    end

    it "returns true when label is set" do
      conversation.label = "my-label"
      expect(conversation.label?).to be true
    end
  end

  describe "#message_count" do
    let(:conversation) { described_class.create(user_id: "test") }

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

      # Load existing conversation
      conversation2 = described_class[uuid]
      expect(conversation2.message_count).to eq(2)
    end
  end

  describe "#total_tokens" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "returns 0 for new conversation" do
      expect(conversation.total_tokens).to eq(0)
    end

    it "returns sum of input and output tokens" do
      conversation.add("assistant", "Response", input_tokens: 100, output_tokens: 50)
      expect(conversation.total_tokens).to eq(150)
    end

    it "accumulates tokens across multiple messages" do
      conversation.add("user", "Hello", input_tokens: 10, output_tokens: 0)
      conversation.add("assistant", "Hi!", input_tokens: 100, output_tokens: 50)
      conversation.add("user", "Bye", input_tokens: 5, output_tokens: 0)

      expect(conversation.total_tokens).to eq(165)
    end

    it "handles nil token values" do
      conversation.input_tokens = nil
      conversation.output_tokens = 50
      expect(conversation.total_tokens).to eq(50)
    end
  end

  describe "#last_activity" do
    let(:conversation) { described_class.create(user_id: "test") }
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

      # Load existing conversation
      conversation2 = described_class[uuid]
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

  describe "#system_prompt" do
    let(:conversation) { described_class.create(user_id: "test") }

    it "includes agent identity" do
      prompt = conversation.system_prompt
      expect(prompt).to include("You are Botias, an autonomous AI agent")
    end

    it "includes ReAct guidance" do
      prompt = conversation.system_prompt
      expect(prompt).to include("You operate in a ReAct loop")
      expect(prompt).to include("Reason about the task, Act using tools, Observe results")
    end

    it "includes environment information" do
      prompt = conversation.system_prompt
      expect(prompt).to include("Environment:")
      expect(prompt).to include("OS:")
      expect(prompt).to include("Shell:")
      expect(prompt).to include("Working Directory:")
      expect(prompt).to include("Date:")
      expect(prompt).to include("Time:")
    end

    it "generates fresh prompt with current date/time" do
      fixed_time = Time.parse("2026-02-20T10:30:45Z")
      allow(Time).to receive(:now).and_return(fixed_time)

      prompt = conversation.system_prompt
      expect(prompt).to include("Date: 2026-02-20")
      expect(prompt).to include("Time: 10:30:45")
    end

    context "with IDENTITY.md" do
      let(:identity_path) { File.expand_path("~/IDENTITY.md") }
      let(:operator_path) { File.expand_path("~/OPERATOR.md") }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:exist?).with(identity_path).and_return(false)
        allow(File).to receive(:exist?).with(operator_path).and_return(false)
      end

      it "includes creation instructions when file does not exist" do
        prompt = conversation.system_prompt
        expect(prompt).to include("IDENTITY.md")
        expect(prompt).to include("CRITICAL: This file does not exist")
        expect(prompt).to include("After setting up OPERATOR.md")
        expect(prompt).to include("Defines who you are")
      end

      it "includes 'ask questions' instructions when file is empty" do
        allow(File).to receive(:exist?).with(identity_path).and_return(true)
        allow(File).to receive(:read).with(identity_path).and_return("")

        prompt = conversation.system_prompt
        expect(prompt).to include("IDENTITY.md")
        expect(prompt).to include("CRITICAL: This file is empty")
        expect(prompt).to include("After setting up OPERATOR.md")
        expect(prompt).to include("What name should I use for myself?")
      end

      it "includes file content and update instructions when file has content" do
        allow(File).to receive(:exist?).with(identity_path).and_return(true)
        allow(File).to receive(:read).with(identity_path).and_return("My name is Botias and I am helpful.")

        prompt = conversation.system_prompt
        expect(prompt).to include("IDENTITY.md")
        expect(prompt).to include("My name is Botias and I am helpful.")
        expect(prompt).to include("You can update ~/IDENTITY.md")
      end
    end

    context "with OPERATOR.md" do
      let(:identity_path) { File.expand_path("~/IDENTITY.md") }
      let(:operator_path) { File.expand_path("~/OPERATOR.md") }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:exist?).with(identity_path).and_return(false)
        allow(File).to receive(:exist?).with(operator_path).and_return(false)
      end

      it "includes creation instructions when file does not exist" do
        prompt = conversation.system_prompt
        expect(prompt).to include("OPERATOR.md")
        expect(prompt).to include("CRITICAL: This file does not exist")
        expect(prompt).to include("Before helping with other tasks, you MUST")
        expect(prompt).to include("Information about the operator")
      end

      it "includes 'ask questions' instructions when file is empty" do
        allow(File).to receive(:exist?).with(operator_path).and_return(true)
        allow(File).to receive(:read).with(operator_path).and_return("")

        prompt = conversation.system_prompt
        expect(prompt).to include("OPERATOR.md")
        expect(prompt).to include("CRITICAL: This file is empty")
        expect(prompt).to include("Before helping with other tasks, you MUST")
        expect(prompt).to include("Ask the operator their name")
      end

      it "includes file content and update instructions when file has content" do
        allow(File).to receive(:exist?).with(operator_path).and_return(true)
        allow(File).to receive(:read).with(operator_path).and_return("Operator name is Alice, prefers concise responses.")

        prompt = conversation.system_prompt
        expect(prompt).to include("OPERATOR.md")
        expect(prompt).to include("Operator name is Alice")
        expect(prompt).to include("You can update ~/OPERATOR.md")
      end
    end
  end
end
