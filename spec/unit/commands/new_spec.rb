# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::New do
  let(:command) { described_class.new }
  let(:config) { instance_double(Botiasloop::Config) }

  describe ".command_name" do
    it "returns :new" do
      expect(described_class.command_name).to eq(:new)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Start a new conversation")
    end
  end

  describe "#execute" do
    it "returns a string message" do
      allow(SecureRandom).to receive(:uuid).and_return("new-uuid-456")
      original_conversation = Botiasloop::Conversation.new
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, config: config)

      result = command.execute(context)

      expect(result).to be_a(String)
    end

    it "updates context.conversation to a new conversation" do
      allow(SecureRandom).to receive(:uuid).and_return("new-uuid-456")
      original_conversation = Botiasloop::Conversation.new
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, config: config)

      command.execute(context)

      expect(context.conversation).not_to eq(original_conversation)
      expect(context.conversation).to be_a(Botiasloop::Conversation)
      expect(context.conversation.uuid).to eq("new-uuid-456")
    end

    it "returns message with new conversation UUID" do
      allow(SecureRandom).to receive(:uuid).and_return("new-uuid-456")
      original_conversation = Botiasloop::Conversation.new
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, config: config)

      result = command.execute(context)

      expect(result).to include("new-uuid-456")
      expect(result).to include("New conversation started")
      expect(result).to include("/switch")
    end

    it "includes instructions to switch back" do
      allow(SecureRandom).to receive(:uuid).and_return("test-uuid")
      original_conversation = Botiasloop::Conversation.new
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, config: config)

      result = command.execute(context)

      expect(result).to match(/use `\/switch test-uuid` to return later/i)
    end

    it "context.conversation has a different UUID than the original" do
      original_conversation = Botiasloop::Conversation.new
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, config: config)

      command.execute(context)

      expect(context.conversation.uuid).not_to eq(original_conversation.uuid)
    end
  end
end
