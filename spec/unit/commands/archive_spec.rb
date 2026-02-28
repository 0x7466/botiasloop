# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Archive do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123", label: "current-label", label?: true) }
  let(:chat) { instance_double(Botiasloop::Chat) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, chat: chat, user_id: "test-user") }

  describe ".command_name" do
    it "returns :archive" do
      expect(described_class.command_name).to eq(:archive)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Archive current conversation (no args) or a specific conversation by label/ID")
    end
  end

  describe "#execute" do
    context "when called without arguments (archive current)" do
      let(:archived_conversation) { instance_double(Botiasloop::Conversation, uuid: "archived-uuid-456", label: "my-project", label?: true, message_count: 5, last_activity: "2 hours ago") }
      let(:new_conversation) { instance_double(Botiasloop::Conversation, uuid: "new-uuid-789", label: nil, label?: false) }

      before do
        allow(chat).to receive(:archive_current)
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
      let(:other_conversation) { instance_double(Botiasloop::Conversation, uuid: "other-uuid", label: "my-project", id: "other-uuid", label?: true) }

      before do
        allow(Botiasloop::Conversation).to receive(:find).with(label: "my-project").and_return(other_conversation)
        allow(other_conversation).to receive(:id).and_return("other-uuid")
        allow(other_conversation).to receive(:label).and_return("my-project")
        allow(other_conversation).to receive(:label?).and_return(true)
        allow(other_conversation).to receive(:archive!).and_return(other_conversation)
        allow(other_conversation).to receive(:message_count).and_return(5)
        allow(other_conversation).to receive(:last_activity).and_return("2 hours ago")
      end

      it "archives the conversation" do
        allow(conversation).to receive(:id).and_return("current-uuid-123")
        command.execute(context, "my-project")
      end

      it "returns success message with conversation details" do
        allow(conversation).to receive(:id).and_return("current-uuid-123")
        result = command.execute(context, "my-project")
        expect(result).to include("Conversation archived successfully")
      end
    end

    context "when archiving by ID" do
      let(:other_conversation) { instance_double(Botiasloop::Conversation, uuid: "target-uuid-456", label: nil, id: "target-uuid-456", label?: false) }

      before do
        allow(Botiasloop::Conversation).to receive(:find).with(label: "target-uuid-456").and_return(nil)
        allow(Botiasloop::Conversation).to receive(:all).and_return([other_conversation])
        allow(other_conversation).to receive(:id).and_return("target-uuid-456")
        allow(other_conversation).to receive(:label).and_return(nil)
        allow(other_conversation).to receive(:label?).and_return(false)
        allow(other_conversation).to receive(:archive!).and_return(other_conversation)
        allow(other_conversation).to receive(:message_count).and_return(3)
        allow(other_conversation).to receive(:last_activity).and_return("1 hour ago")
      end

      it "archives the conversation by ID" do
        allow(conversation).to receive(:id).and_return("current-uuid-123")
        result = command.execute(context, "target-uuid-456")
        expect(result).to include("Conversation archived successfully")
      end
    end

    context "when conversation is not found" do
      before do
        allow(Botiasloop::Conversation).to receive(:find).with(label: "non-existent").and_return(nil)
        allow(Botiasloop::Conversation).to receive(:all).and_return([])
      end

      it "returns error message" do
        result = command.execute(context, "non-existent")
        expect(result).to include("Error: Conversation 'non-existent' not found")
      end
    end

    context "when trying to archive current conversation with explicit identifier" do
      before do
        allow(Botiasloop::Conversation).to receive(:find).with(label: "current-label").and_return(conversation)
        allow(conversation).to receive(:id).and_return("current-uuid-123")
        allow(conversation).to receive(:label).and_return("current-label")
      end

      it "returns helpful error message" do
        result = command.execute(context, "current-label")
        expect(result).to include("Error: Cannot archive the current conversation")
        expect(result).to include("Use /archive without arguments")
      end
    end

    context "format_time_ago" do
      let(:other_conversation) { instance_double(Botiasloop::Conversation, uuid: "other-uuid", label: "test", id: "other-uuid", label?: true) }

      before do
        allow(Botiasloop::Conversation).to receive(:find).with(label: "test").and_return(other_conversation)
        allow(other_conversation).to receive(:id).and_return("other-uuid")
        allow(other_conversation).to receive(:label).and_return("test")
        allow(other_conversation).to receive(:label?).and_return(true)
        allow(other_conversation).to receive(:archive!).and_return(other_conversation)
        allow(conversation).to receive(:id).and_return("current-uuid-123")
      end

      it "shows 'just now' for recent times" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return(Time.now.utc.iso8601)
        result = command.execute(context, "test")
        expect(result).to include("just now")
      end

      it "shows minutes ago for times within an hour" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return((Time.now.utc - 1800).iso8601)
        result = command.execute(context, "test")
        expect(result).to include("minutes ago")
      end

      it "shows hours ago for times within a day" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return((Time.now.utc - 7200).iso8601)
        result = command.execute(context, "test")
        expect(result).to include("hours ago")
      end

      it "shows days ago for times within a week" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return((Time.now.utc - 172_800).iso8601)
        result = command.execute(context, "test")
        expect(result).to include("days ago")
      end

      it "shows formatted date for times older than a week" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return((Time.now.utc - 604_800 * 2).iso8601)
        result = command.execute(context, "test")
        expect(result).to include("UTC")
      end

      it "handles invalid timestamp gracefully" do
        allow(other_conversation).to receive(:message_count).and_return(1)
        allow(other_conversation).to receive(:last_activity).and_return("invalid-timestamp")
        result = command.execute(context, "test")
        expect(result).to include("invalid-timestamp")
      end
    end
  end
end
