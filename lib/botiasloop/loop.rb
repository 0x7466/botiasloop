# frozen_string_literal: true

require "logger"
require "json"

module Botiasloop
  class Loop
    MAX_TOOL_RETRIES = 3

    # Initialize the ReAct loop
    #
    # @param provider [RubyLLM::Provider] Provider instance
    # @param model [RubyLLM::Model] Model instance
    # @param registry [Tools::Registry] Tool registry
    # @param max_iterations [Integer] Maximum ReAct iterations
    def initialize(provider, model, registry, max_iterations: 20)
      @provider = provider
      @model = model
      @registry = registry
      @max_iterations = max_iterations
      @logger = Logger.new($stderr)
    end

    # Run the ReAct loop
    #
    # @param conversation [Conversation] Conversation instance
    # @param user_input [String] User input
    # @return [String] Final response
    # @raise [Error] If max iterations exceeded
    def run(conversation, user_input)
      conversation.add("user", user_input)
      messages = build_messages(conversation)

      # Track accumulated tokens across all iterations
      total_input_tokens = 0
      total_output_tokens = 0

      @max_iterations.times do
        response = iterate(messages)

        # Accumulate tokens from this response
        total_input_tokens += response.input_tokens || 0
        total_output_tokens += response.output_tokens || 0

        if response.tool_call?
          # Add the assistant's message with tool_calls first
          messages << response

          response.tool_calls.each_value do |tool_call|
            observation = execute_tool(tool_call)
            messages << build_tool_result_message(tool_call.id, observation)
          end
        else
          conversation.add("assistant", response.content, input_tokens: total_input_tokens, output_tokens: total_output_tokens)
          return response.content
        end
      end

      raise MaxIterationsExceeded.new(@max_iterations)
    end

    private

    def build_messages(conversation)
      system_prompt = [RubyLLM::Message.new(
        role: :system,
        content: conversation.system_prompt
      )]

      system_prompt + conversation.history.map do |msg|
        role = msg[:role] || msg["role"]
        content = msg[:content] || msg["content"]
        RubyLLM::Message.new(
          role: role.to_sym,
          content: content
        )
      end
    end

    def iterate(messages)
      tool_schemas = @registry.schemas
      @provider.complete(
        messages,
        tools: tool_schemas,
        temperature: nil,
        model: @model
      )
    end

    def build_tool_result_message(tool_call_id, content)
      RubyLLM::Message.new(
        role: :tool,
        content: content,
        tool_call_id: tool_call_id
      )
    end

    def execute_tool(tool_call)
      @logger.info "[Tool] Executing #{tool_call.name} with arguments: #{tool_call.arguments}"
      retries = 0
      begin
        result = @registry.execute(tool_call.name, tool_call.arguments)
        build_observation(result)
      rescue Error => e
        retries += 1
        retry if retries < MAX_TOOL_RETRIES
        "Error: #{e.message}"
      end
    end

    def build_observation(result)
      result.to_s
    end
  end
end
