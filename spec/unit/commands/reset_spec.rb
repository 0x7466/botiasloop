# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Reset do
  let(:command) { described_class.new }
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      uuid: "test-uuid-123",
      reset!: nil)
  end
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config) }

  describe ".command_name" do
    it "returns :reset" do
      expect(described_class.command_name).to eq(:reset)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Clear conversation history")
    end
  end

  describe "#execute" do
    it "calls reset! on conversation" do
      expect(conversation).to receive(:reset!)
      command.execute(context)
    end

    it "returns confirmation message" do
      allow(conversation).to receive(:reset!)
      result = command.execute(context)
      expect(result).to include("test-uuid-123")
      expect(result).to include("cleared")
    end
  end
end
