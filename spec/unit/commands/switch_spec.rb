# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Switch do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123", label: "current-label", label?: true) }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: "test-user") }

  describe ".command_name" do
    it "returns :switch" do
      expect(described_class.command_name).to eq(:switch)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Switch to a different conversation by label or UUID")
    end
  end

  describe "#execute" do
    context "when called without arguments" do
      it "returns error message" do
        result = command.execute(context, nil)
        expect(result).to eq("Usage: /switch <label-or-uuid>")
      end

      it "returns error for empty string" do
        result = command.execute(context, "   ")
        expect(result).to eq("Usage: /switch <label-or-uuid>")
      end
    end

    context "when switching by label" do
      let(:target_conversation) { instance_double(Botiasloop::Conversation, uuid: "target-uuid-456", label: "my-project", label?: true) }

      before do
        allow(Botiasloop::ConversationManager).to receive(:switch)
          .with("test-user", "my-project")
          .and_return(target_conversation)
        allow(target_conversation).to receive(:message_count).and_return(5)
        allow(target_conversation).to receive(:last_activity).and_return("2 hours ago")
      end

      it "switches to the conversation" do
        expect(context).to receive(:conversation=).with(target_conversation)
        command.execute(context, "my-project")
      end

      it "returns success message with conversation details" do
        result = command.execute(context, "my-project")
        expect(result).to include("Switched to conversation")
        expect(result).to include("target-uuid-456")
        expect(result).to include("my-project")
        expect(result).to include("Messages: 5")
      end

      it "trims whitespace from the identifier" do
        expect(Botiasloop::ConversationManager).to receive(:switch)
          .with("test-user", "my-project")
          .and_return(target_conversation)
        command.execute(context, "  my-project  ")
      end
    end

    context "when switching by UUID" do
      let(:target_conversation) { instance_double(Botiasloop::Conversation, uuid: "abc-123-xyz", label: nil, label?: false) }

      before do
        allow(Botiasloop::ConversationManager).to receive(:switch)
          .with("test-user", "abc-123-xyz")
          .and_return(target_conversation)
        allow(target_conversation).to receive(:message_count).and_return(0)
        allow(target_conversation).to receive(:last_activity).and_return(nil)
      end

      it "switches to the conversation by UUID" do
        expect(context).to receive(:conversation=).with(target_conversation)
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
        allow(Botiasloop::ConversationManager).to receive(:switch)
          .with("test-user", "non-existent")
          .and_raise(Botiasloop::Error, "Conversation not found")
      end

      it "returns error message" do
        result = command.execute(context, "non-existent")
        expect(result).to include("Error: Conversation not found")
      end

      it "does not update context" do
        expect(context).not_to receive(:conversation=)
        command.execute(context, "non-existent")
      end
    end

    context "when label format is invalid" do
      it "returns error for invalid characters" do
        allow(Botiasloop::ConversationManager).to receive(:switch)
          .and_raise(Botiasloop::Error, "Invalid identifier")
        result = command.execute(context, "bad@label")
        expect(result).to include("Error")
      end
    end
  end
end
