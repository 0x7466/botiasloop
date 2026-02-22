# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Tool do
  describe ".tool_name" do
    context "with simple class names" do
      it "converts single word to snake_case" do
        simple_tool = Class.new(described_class) do
          def self.name
            "Simple"
          end
        end
        expect(simple_tool.tool_name).to eq("simple")
      end

      it "converts camelCase to snake_case" do
        camel_tool = Class.new(described_class) do
          def self.name
            "MyTool"
          end
        end
        expect(camel_tool.tool_name).to eq("my_tool")
      end
    end

    context "with namespaced classes" do
      it "strips namespace and converts to snake_case" do
        namespaced_tool = Class.new(described_class) do
          def self.name
            "Botiasloop::Tools::CustomTool"
          end
        end
        expect(namespaced_tool.tool_name).to eq("custom_tool")
      end
    end

    context "with acronym handling" do
      it "handles consecutive capitals" do
        http_tool = Class.new(described_class) do
          def self.name
            "HTTPRequestTool"
          end
        end
        expect(http_tool.tool_name).to eq("http_request_tool")
      end

      it "handles all caps acronyms" do
        api_tool = Class.new(described_class) do
          def self.name
            "APIClientTool"
          end
        end
        expect(api_tool.tool_name).to eq("api_client_tool")
      end

      it "handles mixed acronyms and words" do
        mixed_tool = Class.new(described_class) do
          def self.name
            "XMLHttpRequest"
          end
        end
        expect(mixed_tool.tool_name).to eq("xml_http_request")
      end
    end

    context "with complex names" do
      it "handles multiple word boundaries" do
        complex_tool = Class.new(described_class) do
          def self.name
            "MyVeryCustomTool"
          end
        end
        expect(complex_tool.tool_name).to eq("my_very_custom_tool")
      end

      it "handles names with numbers" do
        numbered_tool = Class.new(described_class) do
          def self.name
            "Tool2Handler"
          end
        end
        expect(numbered_tool.tool_name).to eq("tool2_handler")
      end
    end
  end

  describe "actual tool classes" do
    it "generates correct name for Shell" do
      expect(Botiasloop::Tools::Shell.tool_name).to eq("shell")
    end

    it "generates correct name for WebSearch" do
      expect(Botiasloop::Tools::WebSearch.tool_name).to eq("web_search")
    end
  end

  describe "#name" do
    context "on instances" do
      it "returns the same value as class tool_name" do
        test_tool = Class.new(described_class) do
          description "A test tool"

          def self.name
            "MyTestTool"
          end
        end
        instance = test_tool.new
        expect(instance.name).to eq("my_test_tool")
        expect(instance.name).to eq(test_tool.tool_name)
      end

      it "returns short name for namespaced classes" do
        expect(Botiasloop::Tools::Shell.new.name).to eq("shell")
        expect(Botiasloop::Tools::WebSearch.new("http://test.com").name).to eq("web_search")
      end

      it "does not include namespace in name" do
        shell_instance = Botiasloop::Tools::Shell.new
        expect(shell_instance.name).not_to include("botiasloop")
        expect(shell_instance.name).not_to include("tools")
      end
    end
  end

  describe "inheritance" do
    it "inherits from RubyLLM::Tool" do
      expect(described_class.superclass).to eq(RubyLLM::Tool)
    end

    it "provides description DSL" do
      test_tool = Class.new(described_class) do
        description "A test tool"
      end
      instance = test_tool.new
      expect(instance.description).to eq("A test tool")
    end

    it "provides param DSL" do
      test_tool = Class.new(described_class) do
        description "A test tool"
        param :query, type: :string, desc: "Search query", required: true
      end
      instance = test_tool.new
      expect(instance.params_schema).to have_key("properties")
      expect(instance.params_schema["properties"]).to have_key("query")
    end
  end
end
