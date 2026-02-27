# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Status do
  let(:command) { described_class.new }
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      uuid: "test-uuid-123",
      history: [{role: "user", content: "Hello"}],
      label: nil,
      label?: false,
      input_tokens: 150,
      output_tokens: 75,
      total_tokens: 225)
  end
  let(:chat) { instance_double(Botiasloop::Chat) }
  let(:config) do
    instance_double(Botiasloop::Config,
      max_iterations: 20,
      providers: {"openrouter" => {"model" => "moonshotai/kimi-k2.5"}})
  end
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, chat: chat) }

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
      expect(result).to include("1") # Message count
      expect(result).to include("Tokens: 225 (150 in / 75 out)")
    end

    it "shows label when set" do
      allow(conversation).to receive(:label?).and_return(true)
      allow(conversation).to receive(:label).and_return("my-project")

      result = command.execute(context)
      expect(result).to include("Label: my-project")
    end

    it "shows prompt when label is not set" do
      allow(conversation).to receive(:label?).and_return(false)
      allow(conversation).to receive(:label).and_return(nil)

      result = command.execute(context)
      expect(result).to include("Label:")
      expect(result).to include("(none - use /label <name> to set)")
    end

    it "handles nil token values gracefully" do
      allow(conversation).to receive(:input_tokens).and_return(nil)
      allow(conversation).to receive(:output_tokens).and_return(nil)
      allow(conversation).to receive(:total_tokens).and_return(0)

      result = command.execute(context)
      expect(result).to include("Tokens: 0 (0 in / 0 out)")
    end
  end
end
