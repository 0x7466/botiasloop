# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Conversations do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123", id: "current-uuid-123") }
  let(:chat) { instance_double(Botiasloop::Chat) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, chat: chat, user_id: "test-user") }

  describe ".command_name" do
    it "returns :conversations" do
      expect(described_class.command_name).to eq(:conversations)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("List all conversations (use '/conversations archived' to list archived)")
    end
  end

  describe "#execute" do
    context "when there are no conversations" do
      before do
        allow(chat).to receive(:active_conversations).and_return([])
      end

      it "shows no conversations message" do
        result = command.execute(context, nil)
        expect(result).to eq("**Conversations**\nNo conversations found.")
      end
    end

    context "when there are conversations" do
      let(:conv1) { instance_double(Botiasloop::Conversation, id: "current-uuid-123", label: "my-project") }
      let(:conv2) { instance_double(Botiasloop::Conversation, id: "other-uuid-456", label: nil) }
      let(:conv3) { instance_double(Botiasloop::Conversation, id: "another-uuid-789", label: "another-label") }

      before do
        allow(chat).to receive(:active_conversations).and_return([conv3, conv2, conv1])
      end

      it "lists all conversations" do
        result = command.execute(context, nil)
        expect(result).to include("current-uuid-123")
        expect(result).to include("other-uuid-456")
        expect(result).to include("another-uuid-789")
      end

      it "marks current conversation with [current] prefix" do
        result = command.execute(context, nil)
        expect(result).to include("[current] current-uuid-123")
      end

      it "shows label for labeled conversations" do
        result = command.execute(context, nil)
        expect(result).to include("current-uuid-123 (my-project)")
        expect(result).to include("another-uuid-789 (another-label)")
      end

      it "does not show label for unlabeled conversations" do
        result = command.execute(context, nil)
        expect(result).not_to include("other-uuid-456 ()")
        expect(result).to match(/other-uuid-456[^\n]*$/)
      end
    end

    context "when listing archived conversations" do
      before do
        allow(chat).to receive(:archived_conversations).and_return([])
      end

      it "shows no archived conversations message" do
        result = command.execute(context, "archived")
        expect(result).to eq("**Archived Conversations**\nNo archived conversations found.")
      end
    end
  end
end
