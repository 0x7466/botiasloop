# frozen_string_literal: true

module Botiasloop
  module Tools
    class Registry
      attr_reader :tools

      EMPTY_PARAMETERS_SCHEMA = {
        "type" => "object",
        "properties" => {},
        "required" => [],
        "additionalProperties" => false,
        "strict" => true
      }.freeze

      def initialize
        @tools = {}
        @tool_instances = {}
      end

      # Register a tool class
      #
      # @param tool_class [Class] Tool class to register
      # @param args [Hash] Arguments to pass to tool constructor
      def register(tool_class, **args)
        @tools[tool_class.tool_name] = tool_class
        @tool_instances[tool_class.tool_name] = args
      end

      # Deregister a tool by name
      #
      # @param name [String] Tool name to deregister
      def deregister(name)
        @tools.delete(name)
        @tool_instances.delete(name)
      end

      # Generate OpenAI-compatible tool schemas
      # @return [Hash] Hash of tool instances keyed by tool name symbol
      def schemas
        @tools.transform_values do |tool_class|
          args = @tool_instances[tool_class.tool_name]
          args ? tool_class.new(**args) : tool_class.new
        end
      end

      # @return [Array<Class>] Array of registered tool classes
      def tool_classes
        @tools.values
      end

      # Execute a tool by name
      #
      # @param name [String] Tool name
      # @param arguments [Hash] Tool arguments
      # @return [Hash] Tool result
      # @raise [Error] If tool not found
      def execute(name, arguments)
        tool_class = @tools[name]
        raise Error, "Unknown tool: #{name}" unless tool_class

        args = @tool_instances[name]
        tool = args ? tool_class.new(**args) : tool_class.new
        tool.execute(**arguments.transform_keys(&:to_sym))
      end
    end
  end
end
