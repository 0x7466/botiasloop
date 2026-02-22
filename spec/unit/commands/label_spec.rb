# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Label do
  let(:command) { described_class.new }
  let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "test-uuid-123", label: nil, label?: false) }
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: "test-user") }

  describe ".command_name" do
    it "returns :label" do
      expect(described_class.command_name).to eq(:label)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Set or show conversation label")
    end
  end

  describe "#execute" do
    context "when called without arguments" do
      context "and conversation has no label" do
        before do
          allow(conversation).to receive(:label?).and_return(false)
        end

        it "shows message about no label set" do
          result = command.execute(context, nil)
          expect(result).to eq("No label set. Use /label <name> to set one.")
        end
      end

      context "and conversation has a label" do
        before do
          allow(conversation).to receive(:label?).and_return(true)
          allow(conversation).to receive(:label).and_return("my-project")
        end

        it "shows the current label" do
          result = command.execute(context, nil)
          expect(result).to eq("Current label: my-project")
        end
      end

      context "with empty string argument" do
        before do
          allow(conversation).to receive(:label?).and_return(false)
        end

        it "treats empty string as no argument" do
          result = command.execute(context, "   ")
          expect(result).to eq("No label set. Use /label <name> to set one.")
        end
      end
    end

    context "when called with a label value" do
      it "sets the label on the conversation" do
        expect(conversation).to receive(:label=).with("my-label")
        command.execute(context, "my-label")
      end

      it "returns success message with the label" do
        allow(conversation).to receive(:label=).with("my-label")
        result = command.execute(context, "my-label")
        expect(result).to eq("Label set to: my-label")
      end

      it "trims whitespace from the label" do
        allow(conversation).to receive(:label=).with("my-label")
        result = command.execute(context, "  my-label  ")
        expect(result).to eq("Label set to: my-label")
      end
    end

    context "with invalid label format" do
      it "rejects labels with spaces" do
        result = command.execute(context, "my label")
        expect(result).to include("Invalid label format")
      end

      it "rejects labels with special characters" do
        result = command.execute(context, "my@label")
        expect(result).to include("Invalid label format")
      end

      it "rejects labels with dots" do
        result = command.execute(context, "my.label")
        expect(result).to include("Invalid label format")
      end

      it "rejects labels with slashes" do
        result = command.execute(context, "my/label")
        expect(result).to include("Invalid label format")
      end
    end

    context "with valid label characters" do
      it "accepts alphanumeric characters" do
        allow(conversation).to receive(:label=)
        result = command.execute(context, "myproject123")
        expect(result).to eq("Label set to: myproject123")
      end

      it "accepts dashes" do
        allow(conversation).to receive(:label=)
        result = command.execute(context, "my-project")
        expect(result).to eq("Label set to: my-project")
      end

      it "accepts underscores" do
        allow(conversation).to receive(:label=)
        result = command.execute(context, "my_project")
        expect(result).to eq("Label set to: my_project")
      end

      it "accepts mixed valid characters" do
        allow(conversation).to receive(:label=)
        result = command.execute(context, "my-project_123")
        expect(result).to eq("Label set to: my-project_123")
      end
    end

    context "when label is already in use" do
      before do
        allow(Botiasloop::ConversationManager).to receive(:find_by_label)
          .with("test-user", "existing-label")
          .and_return("other-uuid")
      end

      it "returns error message" do
        result = command.execute(context, "existing-label")
        expect(result).to include("already in use")
      end
    end

    context "when conversation already has the label" do
      before do
        allow(Botiasloop::ConversationManager).to receive(:find_by_label)
          .with("test-user", "my-label")
          .and_return("test-uuid-123")
      end

      it "allows setting the same label" do
        allow(conversation).to receive(:label=).with("my-label")
        result = command.execute(context, "my-label")
        expect(result).to eq("Label set to: my-label")
      end
    end

    context "when label raises an error" do
      before do
        allow(conversation).to receive(:label=).and_raise(Botiasloop::Error, "Some error")
      end

      it "returns error message" do
        result = command.execute(context, "label")
        expect(result).to include("Error setting label")
      end
    end

    context "without user_id" do
      let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config, user_id: nil) }

      it "sets label without checking uniqueness" do
        allow(conversation).to receive(:label=).with("my-label")
        result = command.execute(context, "my-label")
        expect(result).to eq("Label set to: my-label")
      end
    end
  end
end
