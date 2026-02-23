# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Compact do
  let(:command) { described_class.new }
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      uuid: "test-uuid-123",
      history: [],
      compact!: nil)
  end
  let(:config) do
    instance_double(Botiasloop::Config,
      providers: {
        "openrouter" => {"model" => "moonshotai/kimi-k2.5"}
      },
      commands: {
        "summarize" => {}
      })
  end
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:add_message)
    allow(mock_chat).to receive(:complete).and_return(
      instance_double(RubyLLM::Message, content: "Summary of conversation")
    )
  end

  describe ".command_name" do
    it "returns :compact" do
      expect(described_class.command_name).to eq(:compact)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Compress conversation by summarizing older messages")
    end
  end

  describe "#execute" do
    context "with fewer than 10 messages" do
      before do
        allow(conversation).to receive(:history).and_return(
          (1..8).map { |i| {role: "user", content: "Message #{i}"} }
        )
      end

      it "returns message that not enough messages" do
        result = command.execute(context)
        expect(result).to include("Need at least 10 messages")
        expect(result).to include("8")
      end
    end

    context "with 10 or more messages" do
      let(:messages) do
        (1..12).map { |i| {role: i.even? ? "assistant" : "user", content: "Message #{i}"} }
      end

      before do
        allow(conversation).to receive(:history).and_return(messages)
      end

      it "summarizes older messages" do
        expect(mock_chat).to receive(:add_message).with(
          hash_including(role: :user, content: /Please summarize the following conversation/)
        )
        expect(mock_chat).to receive(:complete)

        command.execute(context)
      end

      it "calls compact! on conversation with summary and recent messages" do
        allow(mock_chat).to receive(:complete).and_return(
          instance_double(RubyLLM::Message, content: "Generated summary")
        )

        expect(conversation).to receive(:compact!).with(
          "Generated summary",
          messages.last(5)
        )

        command.execute(context)
      end

      it "returns confirmation message" do
        allow(conversation).to receive(:compact!)

        result = command.execute(context)
        expect(result).to include("test-uuid-123")
        expect(result).to include("compacted")
        expect(result).to include("7 messages")
      end
    end

    context "with custom summarize config" do
      let(:custom_config) do
        Botiasloop::Config.new({
          "providers" => {
            "openrouter" => {"model" => "moonshotai/kimi-k2.5"},
            "custom" => {"model" => "custom-model"}
          },
          "commands" => {
            "summarize" => {
              "provider" => "custom",
              "model" => "custom-model"
            }
          }
        })
      end

      before do
        Botiasloop::Config.instance = custom_config
        allow(conversation).to receive(:history).and_return(
          (1..12).map { |i| {role: "user", content: "Message #{i}"} }
        )
      end

      after do
        Botiasloop::Config.instance = nil
      end

      it "uses configured provider and model" do
        expect(RubyLLM).to receive(:chat).with(model: "custom-model")

        command.execute(context)
      end
    end
  end
end
