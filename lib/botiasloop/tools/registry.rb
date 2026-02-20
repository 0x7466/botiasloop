# frozen_string_literal: true

require "ruby_llm"

module Botiasloop
  module Tools
    class Registry
      attr_reader :tools

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

      # @return [Array<Hash>] Array of tool schemas
      def schemas
        @tools.values.map do |tool_class|
          args = @tool_instances[tool_class.tool_name]
          tool = args ? tool_class.new(**args) : tool_class.new
          tool.class.schema
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
        tool.execute(arguments)
      end
    end
  end
end
