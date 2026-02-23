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
    # @param verbose_callback [Proc, nil] Callback for verbose messages
    # @return [String] Final response
    # @raise [Error] If max iterations exceeded
    def run(conversation, user_input, verbose_callback = nil)
      @conversation = conversation
      @verbose_callback = verbose_callback
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
          conversation.add("assistant", response.content, input_tokens: total_input_tokens,
            output_tokens: total_output_tokens)
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

      if @conversation.verbose && @verbose_callback
        verbose_content = format_tool_message(tool_call)
        @verbose_callback.call(verbose_content)
      end

      retries = 0
      begin
        result = @registry.execute(tool_call.name, tool_call.arguments)
        observation = build_observation(result)

        if @conversation.verbose && @verbose_callback
          result_content = format_result_message(observation)
          @verbose_callback.call(result_content)
        end

        observation
      rescue Error => e
        retries += 1
        retry if retries < MAX_TOOL_RETRIES
        "Error: #{e.message}"
      end
    end

    def format_tool_message(tool_call)
      tool_msg = "🔧 **Tool** `#{tool_call.name}`"

      if tool_call.arguments && !tool_call.arguments.empty?
        args_display = JSON.pretty_generate(tool_call.arguments)
        args_display = args_display[0..500] + "..." if args_display.length > 500
        tool_msg += "```\n#{args_display}\n```"
      end

      tool_msg
    end

    def format_result_message(observation)
      result_msg = "📥 **Result**"

      if observation && !observation.empty?
        result_display = observation.to_s
        result_display = result_display[0..500] + "..." if result_display.length > 500
        result_msg += "```\n#{result_display}\n```"
      else
        result_msg += " (empty)"
      end

      result_msg
    end

    def build_observation(result)
      result.to_s
    end
  end
end
