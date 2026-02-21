# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Context do
  let(:conversation) { instance_double(Botiasloop::Conversation) }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:channel) { instance_double(Botiasloop::Channels::Base) }
  let(:user_id) { "user123" }

  describe "#initialize" do
    it "accepts all context parameters" do
      context = described_class.new(
        conversation: conversation,
        config: config,
        channel: channel,
        user_id: user_id
      )

      expect(context.conversation).to eq(conversation)
      expect(context.config).to eq(config)
      expect(context.channel).to eq(channel)
      expect(context.user_id).to eq(user_id)
    end

    it "works with minimal parameters" do
      context = described_class.new(
        conversation: conversation,
        config: config
      )

      expect(context.conversation).to eq(conversation)
      expect(context.config).to eq(config)
      expect(context.channel).to be_nil
      expect(context.user_id).to be_nil
    end
  end

  describe "#conversation" do
    it "returns the conversation" do
      context = described_class.new(conversation: conversation, config: config)
      expect(context.conversation).to eq(conversation)
    end

    it "allows setting a new conversation" do
      context = described_class.new(conversation: conversation, config: config)
      new_conversation = instance_double(Botiasloop::Conversation)

      context.conversation = new_conversation

      expect(context.conversation).to eq(new_conversation)
    end
  end

  describe "#config" do
    it "returns the config" do
      context = described_class.new(conversation: conversation, config: config)
      expect(context.config).to eq(config)
    end
  end

  describe "#channel" do
    it "returns the channel" do
      context = described_class.new(
        conversation: conversation,
        config: config,
        channel: channel
      )
      expect(context.channel).to eq(channel)
    end

    it "returns nil when not set" do
      context = described_class.new(conversation: conversation, config: config)
      expect(context.channel).to be_nil
    end
  end

  describe "#user_id" do
    it "returns the user_id" do
      context = described_class.new(
        conversation: conversation,
        config: config,
        user_id: user_id
      )
      expect(context.user_id).to eq(user_id)
    end

    it "returns nil when not set" do
      context = described_class.new(conversation: conversation, config: config)
      expect(context.user_id).to be_nil
    end
  end
end
