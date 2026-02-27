# frozen_string_literal: true

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
          # Send reasoning to verbose callback if verbose mode enabled
          if @conversation.verbose && @verbose_callback && response.content && !response.content.empty?
            reasoning_content = format_reasoning_message(response.content)
            @verbose_callback.call(reasoning_content)
          end

          # Add the assistant's message as a RubyLLM::Message object
          messages << RubyLLM::Message.new(
            role: :assistant,
            content: response.content || ""
          )

          response.tool_calls.each_value do |tool_call|
            observation = execute_tool(tool_call)
            messages << build_tool_result_message(tool_call.id, observation)
          end
        else
          conversation.add("assistant", response.content, input_tokens: total_input_tokens,
            output_tokens: total_output_tokens)
          maybe_auto_label(conversation)
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
      Logger.info "[Tool] Executing #{tool_call.name} with arguments: #{tool_call.arguments}"

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
        error_content = "Error: #{e.message}"
        @verbose_callback.call(format_error_message(error_content)) if @conversation.verbose && @verbose_callback
        error_content
      end
    end

    def format_error_message(error_content)
      error_msg = "⚠️ **Error**"

      if error_content && !error_content.empty?
        error_display = error_content.to_s
        error_display = error_display[0..500] + "..." if error_display.length > 500
        error_msg += "\n```\n#{error_display}\n```"
      end

      error_msg
    end

    def format_reasoning_message(content)
      reasoning_msg = "💭 **Reasoning**"

      if content && !content.empty?
        reasoning_display = content.to_s
        reasoning_display = reasoning_display[0..500] + "..." if reasoning_display.length > 500
        reasoning_msg += "```\n#{reasoning_display}\n```"
      end

      reasoning_msg
    end

    def format_tool_message(tool_call)
      tool_msg = "🔧 **Tool** `#{tool_call.name}`"

      if tool_call.arguments && !tool_call.arguments.empty?
        args_display = JSON.pretty_generate(tool_call.arguments)
        args_display = args_display[0..500] + "..." if args_display.length > 500
        tool_msg += "\n```\n#{args_display}\n```"
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

    def maybe_auto_label(conversation)
      label = AutoLabel.generate(conversation)
      return unless label

      conversation.update(label: label)
    end
  end
end
