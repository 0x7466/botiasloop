# frozen_string_literal: true

module Botiasloop
  class Loop
    MAX_TOOL_RETRIES = 3

    # Initialize the ReAct loop
    #
    # @param chat [RubyLLM::Chat] Chat instance
    # @param registry [Tools::Registry] Tool registry
    # @param max_iterations [Integer] Maximum ReAct iterations
    def initialize(chat, registry, max_iterations: 20)
      @chat = chat
      @registry = registry
      @max_iterations = max_iterations
    end

    # Run the ReAct loop
    #
    # @param conversation [Conversation] Conversation instance
    # @param user_input [String] User input
    # @return [String] Final response
    # @raise [Error] If max iterations exceeded
    def run(conversation, user_input)
      conversation.add("user", user_input)

      @max_iterations.times do
        response = iterate(conversation.history)

        if response.tool_call?
          tool_call = response.tool_call
          observation = execute_tool(tool_call)
          @chat.add_tool_result(tool_call.id, observation)
        else
          conversation.add("assistant", response.content)
          return response.content
        end
      end

      raise Error, "Max iterations (#{@max_iterations}) exceeded"
    end

    private

    def iterate(messages)
      @chat.ask(messages)
    end

    def execute_tool(tool_call)
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
