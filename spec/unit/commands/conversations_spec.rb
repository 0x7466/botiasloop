# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Conversations do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "current-uuid-123") }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: "test-user") }

  before do
    allow(Botiasloop::ConversationManager).to receive(:all_mappings).and_return({})
    allow(Botiasloop::ConversationManager).to receive(:current_uuid_for).with("test-user").and_return("current-uuid-123")
  end

  describe ".command_name" do
    it "returns :conversations" do
      expect(described_class.command_name).to eq(:conversations)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("List all conversations")
    end
  end

  describe "#execute" do
    context "when there are no conversations" do
      before do
        allow(Botiasloop::ConversationManager).to receive(:all_mappings).and_return({})
      end

      it "shows no conversations message" do
        result = command.execute(context, nil)
        expect(result).to eq("**Conversations**\nNo conversations found.")
      end
    end

    context "when there are conversations" do
      before do
        mappings = {
          "current-uuid-123" => {"user_id" => "test-user", "label" => "my-project"},
          "other-uuid-456" => {"user_id" => "test-user", "label" => nil},
          "another-uuid-789" => {"user_id" => "test-user", "label" => "another-label"}
        }
        allow(Botiasloop::ConversationManager).to receive(:all_mappings).and_return(mappings)
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

    context "when user_id is nil" do
      let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: nil) }

      before do
        mappings = {
          "conv-uuid-1" => {"user_id" => "any-user", "label" => "label1"}
        }
        allow(Botiasloop::ConversationManager).to receive(:all_mappings).and_return(mappings)
        allow(Botiasloop::ConversationManager).to receive(:current_uuid_for).with(nil).and_return(nil)
      end

      it "still lists conversations" do
        result = command.execute(context, nil)
        expect(result).to include("conv-uuid-1")
        expect(result).to include("(label1)")
      end

      it "does not mark any conversation as current" do
        result = command.execute(context, nil)
        expect(result).not_to include("[current]")
      end
    end
  end
end
