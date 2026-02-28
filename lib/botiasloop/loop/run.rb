# frozen_string_literal: true

require "securerandom"

module Botiasloop
  class Loop
    class Run
      attr_reader :id, :conversation

      def initialize(provider:, model:, registry:, max_iterations:, conversation:, user_input:, callback:, error_callback:, completion_callback: nil, chat: nil)
        @id = SecureRandom.uuid
        @conversation = conversation
        @status = :running
        @thread = nil
        @mutex = Mutex.new

        @provider = provider
        @model = model
        @registry = registry
        @max_iterations = max_iterations
        @user_input = user_input
        @callback = callback
        @error_callback = error_callback
        @completion_callback = completion_callback
        @chat = chat
      end

      def status
        @mutex.synchronize { @status }
      end

      def start
        @thread = Thread.new do
          loop = Loop.new(@provider, @model, @registry, max_iterations: @max_iterations)

          begin
            result = loop.run(@conversation, @user_input, callback: @callback, error_callback: @error_callback, chat: @chat)
            @callback&.call(result)
          rescue MaxIterationsExceeded => e
            @error_callback&.call(e.message)
          rescue => e
            @error_callback&.call(e.message)
          ensure
            mark_completed
            Agent.active_loop_runs&.delete(self)
            @completion_callback&.call
          end
        end

        self
      end

      def interrupt!
        @mutex.synchronize do
          return unless @status == :running

          @status = :interrupted
          @thread&.kill
          Agent.active_loop_runs&.delete(self)
        end
      end

      def wait
        @thread&.join
      end

      private

      def mark_completed
        @mutex.synchronize { @status = :completed }
      end
    end
  end
end
