# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::New do
  let(:command) { described_class.new }
  let(:config) { instance_double(Botiasloop::Config) }

  before do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end

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
      allow(Botiasloop::HumanId).to receive(:generate).and_return("blue-dog-456")
      chat = Botiasloop::Chat.create(channel: "test", external_id: "test-123")
      original_conversation = chat.current_conversation
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, chat: chat, user_id: "test-user")

      result = command.execute(context)

      expect(result).to be_a(String)
    end

    it "updates context.conversation to a new conversation" do
      allow(Botiasloop::HumanId).to receive(:generate).and_return("blue-dog-456")
      chat = Botiasloop::Chat.create(channel: "test", external_id: "test-123")
      original_conversation = chat.current_conversation
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, chat: chat, user_id: "test-user")

      command.execute(context)

      expect(context.conversation).not_to eq(original_conversation)
      expect(context.conversation).to be_a(Botiasloop::Conversation)
      expect(context.conversation.uuid).to eq("blue-dog-456")
    end

    it "returns message with new conversation UUID" do
      allow(Botiasloop::HumanId).to receive(:generate).and_return("blue-dog-456")
      chat = Botiasloop::Chat.create(channel: "test", external_id: "test-123")
      original_conversation = chat.current_conversation
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, chat: chat, user_id: "test-user")

      result = command.execute(context)

      expect(result).to include("blue-dog-456")
      expect(result).to include("New conversation started")
      expect(result).to include("/switch")
    end

    it "includes instructions to switch back" do
      allow(Botiasloop::HumanId).to receive(:generate).and_return("red-cat-789")
      chat = Botiasloop::Chat.create(channel: "test", external_id: "test-123")
      original_conversation = chat.current_conversation
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, chat: chat, user_id: "test-user")

      result = command.execute(context)

      expect(result).to match(%r{use `/switch red-cat-789` to return later}i)
    end

    it "context.conversation has a different UUID than the original" do
      chat = Botiasloop::Chat.create(channel: "test", external_id: "test-123")
      original_conversation = chat.current_conversation
      context = Botiasloop::Commands::Context.new(conversation: original_conversation, chat: chat, user_id: "test-user")

      command.execute(context)

      expect(context.conversation.uuid).not_to eq(original_conversation.uuid)
    end
  end
end
