# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Verbose do
  let(:command) { described_class.new }
  let(:conversation) do
    instance_double(Botiasloop::Conversation,
      uuid: "test-uuid-123",
      verbose: false)
  end
  let(:config) { instance_double(Botiasloop::Config) }
  let(:context) { Botiasloop::Commands::Context.new(conversation: conversation, config: config) }

  describe ".command_name" do
    it "returns :verbose" do
      expect(described_class.command_name).to eq(:verbose)
    end
  end

  describe ".description" do
    it "returns command description" do
      expect(described_class.description).to eq("Toggle verbose mode (shows reasoning and tool calls). Usage: /verbose [on|off]")
    end
  end

  describe "#execute" do
    context "without arguments" do
      it "returns current status when verbose is off" do
        allow(conversation).to receive(:verbose).and_return(false)

        result = command.execute(context)
        expect(result).to include("Verbose mode is currently off")
        expect(result).to include("Usage: /verbose [on|off]")
      end

      it "returns current status when verbose is on" do
        allow(conversation).to receive(:verbose).and_return(true)

        result = command.execute(context)
        expect(result).to include("Verbose mode is currently on")
        expect(result).to include("Usage: /verbose [on|off]")
      end
    end

    context "with 'on' argument" do
      it "enables verbose mode" do
        expect(conversation).to receive(:update).with(verbose: true)

        result = command.execute(context, "on")
        expect(result).to eq("Verbose mode enabled. Tool calls will be shown.")
      end
    end

    context "with 'off' argument" do
      it "disables verbose mode" do
        expect(conversation).to receive(:update).with(verbose: false)

        result = command.execute(context, "off")
        expect(result).to eq("Verbose mode disabled. Tool calls will be hidden.")
      end
    end

    context "with invalid argument" do
      it "returns error message" do
        result = command.execute(context, "invalid")
        expect(result).to include("Unknown argument: invalid")
        expect(result).to include("Usage: /verbose [on|off]")
      end
    end
  end
end
