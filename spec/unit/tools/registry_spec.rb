# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Tools::Registry do
  let(:registry) { described_class.new }

  describe "#initialize" do
    it "creates an empty registry" do
      expect(registry.tools.keys).to eq([])
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
      expect(registry.tools.keys).to include("test_tool")
    end

    it "allows registering multiple tools" do
      tool2 = Class.new do
        def self.tool_name
          "tool2"
        end
      end

      registry.register(mock_tool_class)
      registry.register(tool2)

      expect(registry.tools.keys).to contain_exactly("test_tool", "tool2")
    end
  end

  describe "#schemas" do
    let(:mock_tool_class) do
      Class.new do
        def self.tool_name
          "test_tool"
        end

        def initialize(arg1: nil)
          @arg1 = arg1
        end

        def schema
          {"type" => "object", "properties" => {}}
        end
      end
    end

    it "returns hash of tool instances" do
      expect(registry.schemas).to be_a(Hash)
    end

    it "creates tool instances without arguments" do
      registry.register(mock_tool_class)
      schemas = registry.schemas
      expect(schemas["test_tool"]).to be_a(mock_tool_class)
    end

    it "creates tool instances with arguments" do
      registry.register(mock_tool_class, arg1: "value")
      schemas = registry.schemas
      expect(schemas["test_tool"]).to be_a(mock_tool_class)
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

  describe "#deregister" do
    let(:mock_tool_class) do
      Class.new do
        def self.tool_name
          "test_tool"
        end
      end
    end

    it "removes a registered tool" do
      registry.register(mock_tool_class)
      registry.deregister("test_tool")
      expect(registry.tools.keys).to eq([])
    end

    it "is a no-op for unknown tool" do
      registry.deregister("unknown_tool")
      expect(registry.tools.keys).to eq([])
    end
  end
end
