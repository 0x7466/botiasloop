# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Loop do
  let(:mock_provider) { double("provider") }
  let(:mock_model) { double("model") }
  let(:mock_registry) { double("registry") }
  let(:loop) { described_class.new(mock_provider, mock_model, mock_registry, max_iterations: 5) }
  let(:conversation) { instance_double(Botiasloop::Conversation) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(conversation).to receive(:add)
    allow(conversation).to receive(:history).and_return([])
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:info)
    allow(mock_registry).to receive(:schemas).and_return({})
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
          content: "This is the answer")
      end

      before do
        allow(mock_provider).to receive(:complete).and_return(response)
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
          tool_call?: true,
          tool_calls: {"call_123" => tool_call},
          content: "")
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "The output is hello")
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
        loop.run(conversation, "Run echo hello")
      end

      it "returns final answer after tool execution" do
        result = loop.run(conversation, "Run echo hello")
        expect(result).to eq("The output is hello")
      end

      it "logs the tool call" do
        expect(logger).to receive(:info).with(/\[Tool\] Executing shell/)
        loop.run(conversation, "Run echo hello")
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
          content: "")
      end

      before do
        allow(mock_provider).to receive(:complete).and_return(response)
        allow(mock_registry).to receive(:execute).and_return({stdout: "test"})
      end

      it "raises MaxIterationsExceeded when max iterations reached" do
        expect { loop.run(conversation, "Test") }.to raise_error(Botiasloop::MaxIterationsExceeded)
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
          content: "")
      end

      let(:final_response) do
        double("response",
          tool_call?: false,
          content: "There was an error")
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
        loop.run(conversation, "Test")
      end

      it "continues after retries exhausted" do
        result = loop.run(conversation, "Test")
        expect(result).to eq("There was an error")
      end
    end
  end
end
