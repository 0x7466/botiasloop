# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::New do
  let(:command) { described_class.new }
  let(:config) { instance_double(Botiasloop::Config) }

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
    it "returns message with new conversation UUID" do
      allow(SecureRandom).to receive(:uuid).and_return("new-uuid-456")
      context = Botiasloop::Commands::Context.new(conversation: nil, config: config)

      result = command.execute(context)

      expect(result).to include("new-uuid-456")
      expect(result).to include("New conversation started")
      expect(result).to include("/switch")
    end

    it "includes instructions to switch back" do
      allow(SecureRandom).to receive(:uuid).and_return("test-uuid")
      context = Botiasloop::Commands::Context.new(conversation: nil, config: config)

      result = command.execute(context)

      expect(result).to match(/use `\/switch test-uuid` to return/i)
    end
  end
end
