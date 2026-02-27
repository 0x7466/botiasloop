# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Loop::Run do
  let(:mock_provider) { double("provider") }
  let(:mock_model) { double("model") }
  let(:mock_registry) { double("registry") }
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
    allow(mock_registry).to receive(:schemas).and_return({})
    Botiasloop::Config.instance = nil
  end

  describe "#initialize" do
    it "generates a UUID" do
      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      expect(run.id).to match(/[0-9a-f-]{36}/)
    end

    it "stores the conversation" do
      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      expect(run.conversation).to eq(conversation)
    end
  end

  describe "#status" do
    it "returns :running before start" do
      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      expect(run.status).to eq(:running)
    end

    it "returns :completed after thread finishes" do
      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )

      run.start
      run.wait

      expect(run.status).to eq(:completed)
    end
  end

  describe "#start" do
    it "spawns a thread" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      run.start
      run.wait

      expect(run.instance_variable_get(:@thread)).to be_a(Thread)
    end

    it "returns self" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      result = run.start

      run.wait
      expect(result).to eq(run)
    end

    it "calls the callback with the response" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "final response", input_tokens: 0, output_tokens: 0)
      )

      received_messages = []
      cb = proc { |msg| received_messages << msg }

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: cb,
        error_callback: error_callback
      )

      run.start
      run.wait

      expect(received_messages).to include("final response")
    end

    it "removes itself from Agent.active_loop_runs when completed" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )

      Botiasloop::Agent.active_loop_runs.clear

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      run.start
      run.wait

      expect(Botiasloop::Agent.active_loop_runs).to be_empty
    end
  end

  describe "#interrupt!" do
    it "sets status to :interrupted" do
      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      run.start
      run.interrupt!

      expect(run.status).to eq(:interrupted)
    end

    it "removes itself from Agent.active_loop_runs" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: true, content: "", input_tokens: 0, output_tokens: 0,
          tool_calls: {"call_1" => double("tc", id: "1", name: "shell", arguments: {"command" => "sleep 10"})})
      )
      allow(mock_registry).to receive(:execute).and_return({stdout: "result\n"})

      Botiasloop::Agent.active_loop_runs.clear

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      run.start
      run.interrupt!

      expect(Botiasloop::Agent.active_loop_runs).to be_empty
    end
  end

  describe "#wait" do
    it "blocks until thread completes" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )

      run = described_class.new(
        provider: mock_provider,
        model: mock_model,
        registry: mock_registry,
        max_iterations: 5,
        conversation: conversation,
        user_input: "test",
        callback: callback,
        error_callback: error_callback
      )

      run.start
      run.wait

      expect(run.instance_variable_get(:@thread)).not_to be_alive
    end
  end
end
