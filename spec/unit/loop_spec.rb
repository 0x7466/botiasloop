# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Loop do
  let(:mock_provider) { double("provider") }
  let(:mock_model) { double("model") }
  let(:mock_registry) { double("registry") }
  let(:loop) { described_class.new(mock_provider, mock_model, mock_registry, max_iterations: 5) }
  let(:conversation) { instance_double(Botiasloop::Conversation) }
  let(:callback) { proc { |msg| } }
  let(:error_callback) { proc { |msg| } }

  before do
    allow(conversation).to receive(:add)
    allow(conversation).to receive(:history).and_return([])
    allow(conversation).to receive(:system_prompt).and_return("System prompt")
    allow(conversation).to receive(:verbose).and_return(false)
    allow(conversation).to receive(:label?).and_return(false)
    allow(conversation).to receive(:message_count).and_return(2)
    allow(Botiasloop::Logger).to receive(:info)
    allow(mock_registry).to receive(:schemas).and_return({})
    Botiasloop::Config.instance = nil
  end

  describe "#initialize" do
    it "stores provider, model and registry" do
      expect(loop.instance_variable_get(:@provider)).to eq(mock_provider)
      expect(loop.instance_variable_get(:@model)).to eq(mock_model)
      expect(loop.instance_variable_get(:@registry)).to eq(mock_registry)
    end

    it "stores max_iterations" do
      expect(loop.instance_variable_get(:@max_iterations)).to eq(5)
    end
  end

  describe "#run" do
    context "with direct answer" do
      let(:response) do
        double("response",
          tool_call?: false,
          content: "This is the answer",
          role: :assistant,
          input_tokens: 100,
          output_tokens: 50)
      end

      before do
        allow(mock_provider).to receive(:complete).and_return(response)
      end

      it "returns the response content" do
        result = loop.run(conversation, "What is 2+2?", callback: callback)
        expect(result).to eq("This is the answer")
      end

      it "includes system message in provider call" do
        expect(mock_provider).to receive(:complete) do |messages, **_kwargs|
          expect(messages.first).to be_a(RubyLLM::Message)
          expect(messages.first.role).to eq(:system)
          expect(messages.first.content).to eq("System prompt")
          response
        end
        loop.run(conversation, "What is 2+2?", callback: callback)
      end

      it "adds user message to conversation" do
        expect(conversation).to receive(:add).with("user", "What is 2+2?")
        loop.run(conversation, "What is 2+2?", callback: callback)
      end

      it "adds assistant response to conversation with token counts" do
        expect(conversation).to receive(:add).with("assistant", "This is the answer", input_tokens: 100,
          output_tokens: 50)
        loop.run(conversation, "What is 2+2?", callback: callback)
      end
    end

    context "with tool call" do
      let(:tool_call) do
        double("tool_call",
          id: "call_123",
          name: "shell",
          arguments: {"command" => "echo hello"})
      end

      let(:first_response) do
        double("response",
          tool_call?: true,
          tool_calls: {"call_123" => tool_call},
          content: "",
          role: :assistant,
          input_tokens: 50,
          output_tokens: 25)
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "The output is hello",
          role: :assistant,
          input_tokens: 100,
          output_tokens: 50)
      end

      before do
        call_count = 0
        allow(mock_provider).to receive(:complete) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_return({stdout: "hello\n"})
      end

      it "executes the tool" do
        expect(mock_registry).to receive(:execute).with("shell", {"command" => "echo hello"})
        loop.run(conversation, "Run echo hello", callback: callback)
      end

      it "returns final answer after tool execution" do
        result = loop.run(conversation, "Run echo hello", callback: callback)
        expect(result).to eq("The output is hello")
      end

      it "logs the tool call" do
        expect(Botiasloop::Logger).to receive(:info).with(/\[Tool\] Executing shell/)
        loop.run(conversation, "Run echo hello", callback: callback)
      end
    end

    context "with max iterations exceeded" do
      let(:tool_call) do
        double("tool_call",
          id: "call_456",
          name: "shell",
          arguments: {"command" => "echo test"})
      end

      let(:response) do
        double("response",
          tool_call?: true,
          tool_calls: {"call_456" => tool_call},
          content: "",
          role: :assistant,
          input_tokens: 50,
          output_tokens: 25)
      end

      before do
        allow(mock_provider).to receive(:complete).and_return(response)
        allow(mock_registry).to receive(:execute).and_return({stdout: "test"})
      end

      it "raises MaxIterationsExceeded when max iterations reached" do
        expect { loop.run(conversation, "Test", callback: callback) }.to raise_error(Botiasloop::MaxIterationsExceeded)
      end
    end

    context "with tool execution error" do
      let(:tool_call) do
        double("tool_call",
          id: "call_789",
          name: "shell",
          arguments: {"command" => "invalid"})
      end

      let(:first_response) do
        double("response",
          tool_call?: true,
          tool_calls: {"call_789" => tool_call},
          content: "",
          role: :assistant,
          input_tokens: 50,
          output_tokens: 25)
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "There was an error",
          role: :assistant,
          input_tokens: 100,
          output_tokens: 50)
      end

      before do
        call_count = 0
        allow(mock_provider).to receive(:complete) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_raise(Botiasloop::Error, "Tool failed")
      end

      it "retries up to 3 times" do
        expect(mock_registry).to receive(:execute).exactly(3).times
        loop.run(conversation, "Test", callback: callback)
      end

      it "calls error_callback when retries exhausted" do
        error_called = false
        error_cb = proc { error_called = true }

        loop.run(conversation, "Test", callback: callback, error_callback: error_cb)

        expect(error_called).to be true
      end
    end

    context "with verbose mode enabled" do
      let(:tool_call) do
        double("tool_call",
          id: "call_verbose",
          name: "shell",
          arguments: {"command" => "echo test"})
      end

      let(:first_response) do
        double("response",
          tool_call?: true,
          tool_calls: {"call_verbose" => tool_call},
          content: "I need to run a shell command to test this",
          role: :assistant,
          input_tokens: 50,
          output_tokens: 25)
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "The output is test",
          role: :assistant,
          input_tokens: 100,
          output_tokens: 50)
      end

      before do
        call_count = 0
        allow(mock_provider).to receive(:complete) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_return({stdout: "test\n"})
        allow(conversation).to receive(:verbose).and_return(true)
      end

      it "calls callback with reasoning and tool calls" do
        callback_messages = []
        cb = proc { |msg| callback_messages << msg }

        loop.run(conversation, "Run test", callback: cb)

        expect(callback_messages).to include(/💭 \*\*Reasoning\*\*/)
        expect(callback_messages).to include(/I need to run a shell command/)
        expect(callback_messages).to include(/🔧 \*\*Tool\*\* `shell`/)
        expect(callback_messages).to include(/📥 \*\*Result\*\*/)
      end

      it "calls error_callback when tool fails" do
        allow(mock_registry).to receive(:execute).and_raise(Botiasloop::Error, "Command not found")

        callback_messages = []
        error_messages = []
        cb = proc { |msg| callback_messages << msg }
        error_cb = proc { |msg| error_messages << msg }

        loop.run(conversation, "Run test", callback: cb, error_callback: error_cb)

        expect(callback_messages).to include(/🔧 \*\*Tool\*\* `shell`/)
        expect(error_messages).to include(/Command not found/)
      end
    end

    context "with verbose mode disabled" do
      let(:tool_call) do
        double("tool_call",
          id: "call_quiet",
          name: "shell",
          arguments: {"command" => "echo test"})
      end

      let(:first_response) do
        double("response",
          tool_call?: true,
          tool_calls: {"call_quiet" => tool_call},
          content: "",
          role: :assistant,
          input_tokens: 50,
          output_tokens: 25)
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "The output is test",
          role: :assistant,
          input_tokens: 100,
          output_tokens: 50)
      end

      before do
        call_count = 0
        allow(mock_provider).to receive(:complete) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_return({stdout: "test\n"})
        allow(conversation).to receive(:verbose).and_return(false)
      end

      it "does not call callback when verbose is disabled" do
        callback_messages = []
        cb = proc { |msg| callback_messages << msg }

        loop.run(conversation, "Run test", callback: cb)

        expect(callback_messages).to be_empty
      end
    end
  end
end
