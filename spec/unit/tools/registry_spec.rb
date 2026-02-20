# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Tools::Registry do
  let(:registry) { described_class.new }

  describe "#initialize" do
    it "creates an empty registry" do
      expect(registry.names).to eq([])
    end
  end

  describe "#register" do
    let(:mock_tool_class) do
      Class.new do
        def self.tool_name
          "test_tool"
        end
      end
    end

    it "registers a tool" do
      registry.register(mock_tool_class)
      expect(registry.names).to include("test_tool")
    end

    it "allows registering multiple tools" do
      tool2 = Class.new do
        def self.tool_name
          "tool2"
        end
      end

      registry.register(mock_tool_class)
      registry.register(tool2)

      expect(registry.names).to contain_exactly("test_tool", "tool2")
    end
  end

  describe "#schemas" do
    it "returns array of tool schemas" do
      expect(registry.schemas).to be_an(Array)
    end
  end

  describe "#execute" do
    let(:mock_tool) do
      Class.new do
        def self.tool_name
          "mock_tool"
        end

        def execute(args)
          {result: "executed with #{args}"}
        end
      end
    end

    before do
      registry.register(mock_tool)
    end

    it "executes a registered tool" do
      result = registry.execute("mock_tool", {param: "value"})
      expect(result).to eq({result: "executed with {param: \"value\"}"})
    end

    it "raises for unknown tool" do
      expect { registry.execute("unknown", {}) }.to raise_error(Botiasloop::Error)
    end
  end

  describe "#names" do
    it "returns empty array for new registry" do
      expect(registry.names).to eq([])
    end

    it "returns registered tool names" do
      tool = Class.new do
        def self.tool_name
          "my_tool"
        end
      end

      registry.register(tool)
      expect(registry.names).to eq(["my_tool"])
    end
  end
end
