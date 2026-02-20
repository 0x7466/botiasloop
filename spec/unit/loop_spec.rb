# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Loop do
  let(:mock_chat) { double("chat") }
  let(:mock_registry) { double("registry") }
  let(:loop) { described_class.new(mock_chat, mock_registry, max_iterations: 5) }
  let(:conversation) { instance_double(Botiasloop::Conversation) }

  before do
    allow(conversation).to receive(:add)
    allow(conversation).to receive(:history).and_return([])
    allow(mock_chat).to receive(:add_tool_result)
  end

  describe "#initialize" do
    it "stores chat and registry" do
      expect(loop.instance_variable_get(:@chat)).to eq(mock_chat)
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
          tool_calls?: false,
          content: "This is the answer")
      end

      before do
        allow(mock_chat).to receive(:ask).and_return(response)
      end

      it "returns the response content" do
        result = loop.run(conversation, "What is 2+2?")
        expect(result).to eq("This is the answer")
      end

      it "adds user message to conversation" do
        expect(conversation).to receive(:add).with("user", "What is 2+2?")
        loop.run(conversation, "What is 2+2?")
      end

      it "adds assistant response to conversation" do
        expect(conversation).to receive(:add).with("assistant", "This is the answer")
        loop.run(conversation, "What is 2+2?")
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
          tool_calls?: true,
          tool_calls: [tool_call],
          content: "")
      end

      let(:final_response) do
        double("response",
          tool_calls?: false,
          content: "The output is hello")
      end

      before do
        call_count = 0
        allow(mock_chat).to receive(:ask) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_return({stdout: "hello\n"})
      end

      it "executes the tool" do
        expect(mock_registry).to receive(:execute).with("shell", {"command" => "echo hello"})
        loop.run(conversation, "Run echo hello")
      end

      it "returns final answer after tool execution" do
        result = loop.run(conversation, "Run echo hello")
        expect(result).to eq("The output is hello")
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
          tool_calls?: true,
          tool_calls: [tool_call],
          content: "")
      end

      before do
        allow(mock_chat).to receive(:ask).and_return(response)
        allow(mock_registry).to receive(:execute).and_return({stdout: "test"})
      end

      it "raises error when max iterations reached" do
        expect { loop.run(conversation, "Test") }.to raise_error(Botiasloop::Error, /Max iterations/)
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
          tool_calls?: true,
          tool_calls: [tool_call],
          content: "")
      end

      let(:final_response) do
        double("response",
          tool_calls?: false,
          content: "There was an error")
      end

      before do
        call_count = 0
        allow(mock_chat).to receive(:ask) do
          call_count += 1
          (call_count == 1) ? first_response : final_response
        end
        allow(mock_registry).to receive(:execute).and_raise(Botiasloop::Error, "Tool failed")
      end

      it "retries up to 3 times" do
        expect(mock_registry).to receive(:execute).exactly(3).times
        loop.run(conversation, "Test")
      end

      it "continues after retries exhausted" do
        result = loop.run(conversation, "Test")
        expect(result).to eq("There was an error")
      end
    end
  end
end
