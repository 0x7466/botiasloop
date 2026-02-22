# frozen_string_literal: true

require "ruby_llm"

module Botiasloop
  class Tool < RubyLLM::Tool
    # Auto-generate tool name from class name in snake_case
    # Example: WebSearch -> "web_search", MyCustomTool -> "my_custom_tool"
    def self.tool_name
      name
        .split("::")
        .last
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .downcase
    end

    # Override RubyLLM's name method to use our tool_name
    # This ensures the provider receives the correct tool name in schemas
    def name
      self.class.tool_name
    end
  end
end
