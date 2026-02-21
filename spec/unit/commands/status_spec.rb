# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Status do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "test-uuid-123", history: [{role: "user", content: "Hello"}]) }
  let(:config) do
    instance_double(Botiasloop::Config,
      max_iterations: 20,
      providers: {"openrouter" => {"model" => "moonshotai/kimi-k2.5"}})
  end
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config) }

  describe ".command_name" do
    it "returns :status" do
      expect(described_class.command_name).to eq(:status)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Show current conversation status")
    end
  end

  describe "#execute" do
    it "returns formatted status information" do
      result = command.execute(context)

      expect(result).to include("Conversation Status")
      expect(result).to include("test-uuid-123")
      expect(result).to include("moonshotai/kimi-k2.5")
      expect(result).to include("20")
      expect(result).to include("1")  # Message count
    end
  end
end
