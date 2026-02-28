# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Switch do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123", label: "current-label", label?: true) }
  let(:chat) { instance_double(Botiasloop::Chat) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, chat: chat, user_id: "test-user") }

  describe ".command_name" do
    it "returns :switch" do
      expect(described_class.command_name).to eq(:switch)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Switch to a different conversation by label or ID")
    end
  end

  describe "#execute" do
    context "when called without arguments" do
      it "returns error message" do
        result = command.execute(context, nil)
        expect(result).to eq("Usage: /switch <label-or-id>")
      end

      it "returns error for empty string" do
        result = command.execute(context, "   ")
        expect(result).to eq("Usage: /switch <label-or-id>")
      end
    end

    context "when switching by label" do
      let(:target_conversation) { instance_double(Botiasloop::Conversation, uuid: "target-uuid-456", label: "my-project", label?: true) }

      before do
        allow(chat).to receive(:switch_conversation)
          .with("my-project")
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
        expect(result).to include("**Conversation switched**")
        expect(result).to include("target-uuid-456")
        expect(result).to include("my-project")
        expect(result).to include("Messages: 5")
      end

      it "trims whitespace from the identifier" do
        expect(chat).to receive(:switch_conversation)
          .with("my-project")
          .and_return(target_conversation)
        command.execute(context, "  my-project  ")
      end
    end

    context "when switching by UUID" do
      let(:target_conversation) { instance_double(Botiasloop::Conversation, uuid: "abc-123-xyz", label: nil, label?: false) }

      before do
        allow(chat).to receive(:switch_conversation)
          .with("abc-123-xyz")
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
        allow(chat).to receive(:switch_conversation)
          .with("non-existent")
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
        allow(chat).to receive(:switch_conversation)
          .and_raise(Botiasloop::Error, "Invalid identifier")
        result = command.execute(context, "bad@label")
        expect(result).to include("Error")
      end
    end

    context "format_time_ago" do
      let(:target_conversation) { instance_double(Botiasloop::Conversation, uuid: "test-uuid", label: nil, label?: false) }

      before do
        allow(chat).to receive(:switch_conversation).and_return(target_conversation)
        allow(target_conversation).to receive(:message_count).and_return(1)
        allow(target_conversation).to receive(:label).and_return(nil)
        allow(target_conversation).to receive(:label?).and_return(false)
      end

      it "shows 'just now' for recent times" do
        allow(target_conversation).to receive(:last_activity).and_return(Time.now.utc.iso8601)
        result = command.execute(context, "test-uuid")
        expect(result).to include("just now")
      end

      it "shows minutes ago for times within an hour" do
        allow(target_conversation).to receive(:last_activity).and_return((Time.now.utc - 1800).iso8601)
        result = command.execute(context, "test-uuid")
        expect(result).to include("minutes ago")
      end

      it "shows hours ago for times within a day" do
        allow(target_conversation).to receive(:last_activity).and_return((Time.now.utc - 7200).iso8601)
        result = command.execute(context, "test-uuid")
        expect(result).to include("hours ago")
      end

      it "shows days ago for times within a week" do
        allow(target_conversation).to receive(:last_activity).and_return((Time.now.utc - 172_800).iso8601)
        result = command.execute(context, "test-uuid")
        expect(result).to include("days ago")
      end

      it "shows formatted date for times older than a week" do
        allow(target_conversation).to receive(:last_activity).and_return((Time.now.utc - 604_800 * 2).iso8601)
        result = command.execute(context, "test-uuid")
        expect(result).to include("UTC")
      end

      it "handles invalid timestamp gracefully" do
        allow(target_conversation).to receive(:last_activity).and_return("invalid-timestamp")
        result = command.execute(context, "test-uuid")
        expect(result).to include("invalid-timestamp")
      end
    end
  end
end
