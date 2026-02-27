# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::SystemPrompt do
  let(:command) { described_class.new }
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      system_prompt: "Test system prompt content")
  end
  let(:chat) { instance_double(Botiasloop::Chat) }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, chat: chat) }

  describe ".command_name" do
    it "returns :systemprompt" do
      expect(described_class.command_name).to eq(:systemprompt)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Display the system prompt")
    end
  end

  describe "#execute" do
    it "returns the conversation's system prompt" do
      expect(conversation).to receive(:system_prompt).and_return("Test system prompt content")

      result = command.execute(context)
      expect(result).to eq("Test system prompt content")
    end

    it "returns empty string when system prompt is nil" do
      allow(conversation).to receive(:system_prompt).and_return(nil)

      result = command.execute(context)
      expect(result).to be_nil
    end
  end
end
