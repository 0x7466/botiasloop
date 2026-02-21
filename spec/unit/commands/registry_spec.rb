# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Commands::Registry do
  let(:registry) { described_class.new }

  let(:test_command_class) do
    Class.new(Botiasloop::Commands::Base) do
      command :test
      description "A test command"

      def execute(context, _args = nil)
        "test executed"
      end
    end
  end

  let(:another_command_class) do
    Class.new(Botiasloop::Commands::Base) do
      command :another
      description "Another command"

      def execute(context, _args = nil)
        "another executed"
      end
    end
  end

  describe "#register" do
    it "registers a command class by name" do
      registry.register(test_command_class)
      expect(registry[:test]).to eq(test_command_class)
    end

    it "raises error if command name is not set" do
      invalid_class = Class.new(Botiasloop::Commands::Base)
      expect { registry.register(invalid_class) }.to raise_error(Botiasloop::Error)
    end

    it "overwrites existing command" do
      registry.register(test_command_class)

      new_class = Class.new(Botiasloop::Commands::Base) do
        command :test
        description "New test command"

        def execute(context)
          "new test"
        end
      end

      registry.register(new_class)
      expect(registry[:test]).to eq(new_class)
    end
  end

  describe "#[]" do
    it "returns nil for unregistered command" do
      expect(registry[:unknown]).to be_nil
    end

    it "returns the command class" do
      registry.register(test_command_class)
      expect(registry[:test]).to eq(test_command_class)
    end
  end

  describe "#all" do
    it "returns empty array when no commands registered" do
      expect(registry.all).to be_empty
    end

    it "returns all registered commands sorted by name" do
      registry.register(test_command_class)
      registry.register(another_command_class)

      expect(registry.all).to eq([another_command_class, test_command_class])
    end
  end

  describe "#names" do
    it "returns empty array when no commands registered" do
      expect(registry.names).to be_empty
    end

    it "returns all command names sorted" do
      registry.register(test_command_class)
      registry.register(another_command_class)

      expect(registry.names).to eq([:another, :test])
    end
  end

  describe "#execute" do
    let(:context) { instance_double(Botiasloop::Commands::Context) }

    it "executes command by name" do
      registry.register(test_command_class)
      result = registry.execute("/test", context)
      expect(result).to eq("test executed")
    end

    it "passes arguments to command" do
      cmd_class = Class.new(Botiasloop::Commands::Base) do
        command :greet
        description "Greet someone"

        def execute(context, args)
          "Hello, #{args}!"
        end
      end

      registry.register(cmd_class)
      result = registry.execute("/greet World", context)
      expect(result).to eq("Hello, World!")
    end

    it "returns error message for unknown command" do
      result = registry.execute("/unknown", context)
      expect(result).to include("Unknown command: /unknown")
      expect(result).to include("/help")
    end

    it "handles commands without arguments" do
      registry.register(test_command_class)
      result = registry.execute("/test", context)
      expect(result).to eq("test executed")
    end

    it "preserves arguments with spaces" do
      cmd_class = Class.new(Botiasloop::Commands::Base) do
        command :echo
        description "Echo text"

        def execute(context, text)
          "Echo: #{text}"
        end
      end

      registry.register(cmd_class)
      result = registry.execute("/echo hello world", context)
      expect(result).to eq("Echo: hello world")
    end
  end

  describe "#command?" do
    it "returns true for registered command" do
      registry.register(test_command_class)
      expect(registry.command?("/test")).to be true
    end

    it "returns false for unregistered command" do
      expect(registry.command?("/unknown")).to be false
    end

    it "returns false for non-command text" do
      expect(registry.command?("hello /test world")).to be false
    end

    it "returns false for command not at start" do
      registry.register(test_command_class)
      expect(registry.command?("tell me about /test")).to be false
    end
  end
end
