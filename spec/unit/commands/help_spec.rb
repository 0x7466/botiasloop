# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Help do
  let(:help_command) { described_class.new }
  let(:context) { instance_double(Botiasloop::Commands::Context) }
  let(:registry) { Botiasloop::Commands::Registry.new }

  before do
    allow(Botiasloop::Commands).to receive(:registry).and_return(registry)
    # Register the Help command in the test registry
    registry.register(described_class)
  end

  describe "#execute" do
    it "returns header for available commands" do
      result = help_command.execute(context)
      expect(result).to include("Available commands:")
    end

    it "lists all registered commands" do
      # Register some test commands
      cmd1 = Class.new(Botiasloop::Commands::Base) do
        command :reset
        description "Clear conversation history"

        def execute(context, _args = nil)
          "reset"
        end
      end

      cmd2 = Class.new(Botiasloop::Commands::Base) do
        command :status
        description "Show current status"

        def execute(context, _args = nil)
          "status"
        end
      end

      registry.register(cmd1)
      registry.register(cmd2)

      result = help_command.execute(context)

      expect(result).to include("/help - Show available commands")
      expect(result).to include("/reset - Clear conversation history")
      expect(result).to include("/status - Show current status")
    end

    it "sorts commands alphabetically" do
      # Register commands in non-alphabetical order
      cmd_z = Class.new(Botiasloop::Commands::Base) do
        command :zoo
        description "Zoo command"

        def execute(context, _args = nil)
          "zoo"
        end
      end

      cmd_a = Class.new(Botiasloop::Commands::Base) do
        command :apple
        description "Apple command"

        def execute(context, _args = nil)
          "apple"
        end
      end

      registry.register(cmd_z)
      registry.register(cmd_a)

      result = help_command.execute(context)
      lines = result.split("\n").reject(&:empty?)

      # Find positions of apple and zoo in output
      apple_index = lines.find_index { |l| l.include?("/apple") }
      zoo_index = lines.find_index { |l| l.include?("/zoo") }

      expect(apple_index).to be < zoo_index
    end

    it "formats each command with name and description" do
      cmd = Class.new(Botiasloop::Commands::Base) do
        command :test
        description "Test description"

        def execute(context, _args = nil)
          "test"
        end
      end

      registry.register(cmd)

      result = help_command.execute(context)
      expect(result).to match(%r{/test - Test description})
    end

    it "handles commands without description" do
      cmd = Class.new(Botiasloop::Commands::Base) do
        command :nodescription

        def execute(context, _args = nil)
          "test"
        end
      end

      registry.register(cmd)

      result = help_command.execute(context)
      expect(result).to include("/nodescription - No description")
    end

    it "handles empty registry" do
      # Clear the registry for this test
      registry.instance_variable_set(:@commands, {})

      result = help_command.execute(context)
      expect(result).to eq("Available commands:")
    end
  end

  describe ".command_name" do
    it "returns :help" do
      expect(described_class.command_name).to eq(:help)
    end
  end

  describe ".description" do
    it "returns description" do
      expect(described_class.description).to eq("Show available commands")
    end
  end
end
