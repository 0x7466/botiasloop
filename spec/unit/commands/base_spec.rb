# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Base do
  let(:test_command_class) do
    Class.new(described_class) do
      command :test
      description "A test command"

      def execute(context, args = nil)
        "Executed test with args: #{args}"
      end
    end
  end

  describe ".command" do
    it "sets the command name" do
      expect(test_command_class.command_name).to eq(:test)
    end

    it "returns nil if not set" do
      empty_class = Class.new(described_class)
      expect(empty_class.command_name).to be_nil
    end
  end

  describe ".description" do
    it "sets the command description" do
      expect(test_command_class.description).to eq("A test command")
    end

    it "returns nil if not set" do
      empty_class = Class.new(described_class)
      expect(empty_class.description).to be_nil
    end
  end

  describe "#execute" do
    it "must be implemented by subclasses" do
      base_instance = described_class.new
      context = instance_double(Botiasloop::Commands::Context)

      expect { base_instance.execute(context) }.to raise_error(NotImplementedError)
    end

    it "executes the subclass implementation" do
      cmd = test_command_class.new
      context = instance_double(Botiasloop::Commands::Context)

      result = cmd.execute(context, "some args")
      expect(result).to eq("Executed test with args: some args")
    end
  end

  describe ".inherited" do
    it "automatically registers subclasses in the registry" do
      # Create a test command class - it auto-registers when command() is called
      Class.new(described_class) do
        command :autoregister
        description "Auto-registered command"

        def execute(context, _args = nil)
          "auto"
        end
      end

      expect(Botiasloop::Commands.registry).to have_command(:autoregister)
    end
  end
end
