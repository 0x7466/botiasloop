# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::AutoLabel do
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      uuid: "test-conversation-uuid",
      history: messages,
      label?: has_label,
      message_count: messages.count,
      label: current_label)
  end
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:mock_message) { instance_double(RubyLLM::Message, content: generated_label) }
  let(:messages) { generate_messages(6) }
  let(:has_label) { false }
  let(:current_label) { nil }
  let(:generated_label) { "coding-help" }
  let(:default_model) { "moonshotai/kimi-k2.5" }
  let(:config) do
    instance_double(Botiasloop::Config,
      features: {"auto_labelling" => feature_config},
      providers: {"openrouter" => {"model" => default_model}})
  end
  let(:feature_config) { {} }

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:add_message)
    allow(mock_chat).to receive(:complete).and_return(mock_message)
  end

  describe ".should_generate?" do
    context "with all conditions met" do
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }

      it "returns true" do
        expect(described_class.should_generate?(conversation, config)).to be true
      end
    end

    context "when auto-labelling is disabled" do
      let(:feature_config) { {"enabled" => false} }

      it "returns false" do
        expect(described_class.should_generate?(conversation, config)).to be false
      end
    end

    context "when conversation already has a label" do
      let(:has_label) { true }
      let(:current_label) { "existing-label" }

      it "returns false" do
        expect(described_class.should_generate?(conversation, config)).to be false
      end
    end

    context "when conversation has fewer than 6 messages" do
      let(:messages) { generate_messages(5) }

      it "returns false" do
        expect(described_class.should_generate?(conversation, config)).to be false
      end
    end

    context "when conversation has exactly 6 messages" do
      let(:messages) { generate_messages(6) }

      it "returns true" do
        expect(described_class.should_generate?(conversation, config)).to be true
      end
    end

    context "when conversation has more than 6 messages" do
      let(:messages) { generate_messages(10) }

      it "returns true" do
        expect(described_class.should_generate?(conversation, config)).to be true
      end
    end

    context "with nil feature config" do
      let(:config) do
        instance_double(Botiasloop::Config,
          features: nil,
          providers: {"openrouter" => {"model" => default_model}})
      end

      it "returns true (defaults to enabled)" do
        expect(described_class.should_generate?(conversation, config)).to be true
      end
    end
  end

  describe ".generate" do
    context "when conditions are not met" do
      let(:has_label) { true }
      let(:current_label) { "already-labeled" }

      it "returns nil" do
        expect(described_class.generate(conversation, config)).to be_nil
      end

      it "does not interact with LLM" do
        expect(RubyLLM).not_to receive(:chat)
        described_class.generate(conversation, config)
      end
    end

    context "when conditions are met" do
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }

      it "generates a label" do
        result = described_class.generate(conversation, config)
        expect(result).to eq("coding-help")
      end

      it "logs the generated label" do
        expect(Botiasloop::Logger).to receive(:info).with("[AutoLabel] Generated label 'coding-help' for conversation test-conversation-uuid")
        described_class.generate(conversation, config)
      end

      it "uses RubyLLM chat with default model" do
        expect(RubyLLM).to receive(:chat).with(model: default_model).and_return(mock_chat)
        described_class.generate(conversation, config)
      end

      it "sends a prompt to the LLM" do
        expect(mock_chat).to receive(:add_message).with(
          hash_including(role: :user, content: /Based on the following conversation/)
        )
        described_class.generate(conversation, config)
      end

      it "includes conversation text in the prompt" do
        expect(mock_chat).to receive(:add_message).with(
          hash_including(content: /Message 1 content/)
        )
        described_class.generate(conversation, config)
      end

      it "only uses first 6 messages in prompt" do
        expect(mock_chat).to receive(:add_message) do |params|
          content = params[:content]
          expect(content).to include("Message 1")
          expect(content).to include("Message 6")
          expect(content).not_to include("Message 7") if messages.count > 6
        end
        described_class.generate(conversation, config)
      end
    end

    context "with custom model configuration" do
      let(:feature_config) { {"model" => "custom-model"} }
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }

      it "uses the configured model" do
        expect(RubyLLM).to receive(:chat).with(model: "custom-model").and_return(mock_chat)
        described_class.generate(conversation, config)
      end
    end

    context "when auto-labelling is explicitly enabled" do
      let(:feature_config) { {"enabled" => true} }
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }

      it "generates a label" do
        expect(described_class.generate(conversation, config)).to eq("coding-help")
      end
    end
  end

  describe "#generate_label" do
    let(:auto_label) { described_class.new(config) }
    let(:messages) { generate_messages(6) }
    let(:has_label) { false }

    it "formats multi-word labels with dashes" do
      allow(mock_message).to receive(:content).and_return("Travel Planning")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("travel-planning")
    end

    it "handles labels with special characters" do
      allow(mock_message).to receive(:content).and_return("$Debug & Error#123!")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("debug-error123")
    end

    it "converts uppercase to lowercase" do
      allow(mock_message).to receive(:content).and_return("CODE REVIEW")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("code-review")
    end

    it "handles extra whitespace" do
      allow(mock_message).to receive(:content).and_return("  Recipe   Ideas  ")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("recipe-ideas")
    end

    it "limits to maximum 2 words" do
      allow(mock_message).to receive(:content).and_return("One Two Three Four")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("one-two")
    end

    it "handles single word labels" do
      allow(mock_message).to receive(:content).and_return("Debugging")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("debugging")
    end

    it "handles labels with existing dashes" do
      allow(mock_message).to receive(:content).and_return("travel-planning")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("travel-planning")
    end

    it "returns nil for empty LLM response" do
      allow(mock_message).to receive(:content).and_return("   ")
      result = auto_label.generate_label(conversation)
      expect(result).to be_nil
    end

    it "returns nil for nil LLM response" do
      allow(mock_message).to receive(:content).and_return(nil)
      result = auto_label.generate_label(conversation)
      expect(result).to be_nil
    end

    it "returns nil for invalid label format" do
      allow(mock_message).to receive(:content).and_return("@\#$%")
      result = auto_label.generate_label(conversation)
      expect(result).to be_nil
    end

    it "returns nil when LLM raises an error" do
      allow(mock_chat).to receive(:complete).and_raise(StandardError.new("LLM error"))
      result = auto_label.generate_label(conversation)
      expect(result).to be_nil
    end

    it "accepts labels with underscores" do
      allow(mock_message).to receive(:content).and_return("code_review")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("code_review")
    end

    it "accepts labels with numbers" do
      allow(mock_message).to receive(:content).and_return("debug-123")
      result = auto_label.generate_label(conversation)
      expect(result).to eq("debug-123")
    end
  end

  describe "error handling" do
    context "when LLM complete fails" do
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }

      before do
        allow(mock_chat).to receive(:complete).and_raise(StandardError.new("Network error"))
      end

      it "returns nil instead of raising" do
        result = described_class.generate(conversation, config)
        expect(result).to be_nil
      end
    end

    context "when LLM returns empty content" do
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }
      let(:mock_message) { instance_double(RubyLLM::Message, content: "") }

      it "returns nil" do
        result = described_class.generate(conversation, config)
        expect(result).to be_nil
      end
    end

    context "when LLM returns only special characters" do
      let(:messages) { generate_messages(6) }
      let(:has_label) { false }
      let(:mock_message) { instance_double(RubyLLM::Message, content: "@\#$%") }

      it "returns nil after formatting removes all valid characters" do
        result = described_class.generate(conversation, config)
        expect(result).to be_nil
      end
    end
  end

  describe "MIN_MESSAGES_FOR_AUTO_LABEL constant" do
    it "is set to 6" do
      expect(described_class::MIN_MESSAGES_FOR_AUTO_LABEL).to eq(6)
    end
  end

  # Helper method to generate mock messages
  def generate_messages(count)
    (1..count).map do |i|
      {
        role: i.even? ? "assistant" : "user",
        content: "Message #{i} content",
        input_tokens: 10,
        output_tokens: 20,
        timestamp: Time.now.utc.iso8601
      }
    end
  end
end
