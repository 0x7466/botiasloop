# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Archive do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123", label: "current-label", label?: true) }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: "test-user") }

  describe ".command_name" do
    it "returns :archive" do
      expect(described_class.command_name).to eq(:archive)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Archive current conversation (no args) or a specific conversation by label/UUID")
    end
  end

  describe "#execute" do
    context "when called without arguments (archive current)" do
      let(:archived_conversation) { instance_double(Botiasloop::Conversation, uuid: "archived-uuid-456", label: "my-project", label?: true, message_count: 5, last_activity: "2 hours ago") }
      let(:new_conversation) { instance_double(Botiasloop::Conversation, uuid: "new-uuid-789", label: nil, label?: false) }

      before do
        allow(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", nil)
          .and_return({archived: archived_conversation, new_conversation: new_conversation})
        allow(archived_conversation).to receive(:message_count).and_return(5)
        allow(archived_conversation).to receive(:last_activity).and_return("2 hours ago")
      end

      it "archives current conversation and creates a new one" do
        expect(context).to receive(:conversation=).with(new_conversation)
        command.execute(context, nil)
      end

      it "returns success message with both conversations" do
        allow(context).to receive(:conversation=)
        result = command.execute(context, nil)
        expect(result).to include("Current conversation archived and new conversation started")
        expect(result).to include("archived-uuid-456")
        expect(result).to include("new-uuid-789")
        expect(result).to include("my-project")
        expect(result).to include("Messages: 5")
      end

      it "handles empty string the same as nil" do
        allow(context).to receive(:conversation=)
        result = command.execute(context, "   ")
        expect(result).to include("Current conversation archived")
      end
    end

    context "when archiving by label" do
      let(:archived_conversation) { instance_double(Botiasloop::Conversation, uuid: "target-uuid-456", label: "my-project", label?: true, message_count: 5, last_activity: "2 hours ago") }

      before do
        allow(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", "my-project")
          .and_return({archived: archived_conversation})
      end

      it "archives the conversation" do
        command.execute(context, "my-project")
      end

      it "returns success message with conversation details" do
        result = command.execute(context, "my-project")
        expect(result).to include("Conversation archived successfully")
        expect(result).to include("target-uuid-456")
        expect(result).to include("my-project")
        expect(result).to include("Messages: 5")
      end

      it "trims whitespace from the identifier" do
        expect(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", "my-project")
          .and_return({archived: archived_conversation})
        command.execute(context, "  my-project  ")
      end
    end

    context "when archiving by UUID" do
      let(:archived_conversation) { instance_double(Botiasloop::Conversation, uuid: "abc-123-xyz", label: nil, label?: false, message_count: 0, last_activity: nil) }

      before do
        allow(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", "abc-123-xyz")
          .and_return({archived: archived_conversation})
      end

      it "archives the conversation by UUID" do
        command.execute(context, "abc-123-xyz")
      end

      it "shows '(no label)' for unlabeled conversation" do
        result = command.execute(context, "abc-123-xyz")
        expect(result).to include("(no label)")
      end

      it "handles empty conversation" do
        result = command.execute(context, "abc-123-xyz")
        expect(result).to include("Messages: 0")
        expect(result).to include("no activity")
      end
    end

    context "when conversation is not found" do
      before do
        allow(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", "non-existent")
          .and_raise(Botiasloop::Error, "Conversation not found")
      end

      it "returns error message" do
        result = command.execute(context, "non-existent")
        expect(result).to include("Error: Conversation not found")
      end
    end

    context "when trying to archive current conversation with explicit identifier" do
      before do
        allow(Botiasloop::ConversationManager).to receive(:archive)
          .with("test-user", "current-label")
          .and_raise(Botiasloop::Error, "Cannot archive the current conversation. Use /archive without arguments to archive current and start new.")
      end

      it "returns helpful error message" do
        result = command.execute(context, "current-label")
        expect(result).to include("Error: Cannot archive the current conversation")
        expect(result).to include("Use /archive without arguments")
      end
    end
  end
end
