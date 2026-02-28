# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Agent do
  let(:test_config) do
    Botiasloop::Config.new({
      "max_iterations" => 10,
      "tools" => {
        "web_search" => {
          "searxng_url" => "http://searxng:8080"
        }
      },
      "providers" => {
        "openrouter" => {
          "api_key" => "test-api-key",
          "model" => "test/model"
        }
      }
    })
  end

  before do
    Botiasloop::Config.instance = test_config
  end

  after do
    Botiasloop::Config.instance = nil
  end

  describe "#chat" do
    let(:mock_provider) { double("provider") }
    let(:mock_model) { double("model") }
    let(:mock_registry) { double("registry") }
    let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "test-uuid") }
    let(:chat) { instance_double(Botiasloop::Chat, id: 123, channel: "telegram", external_id: "456") }
    let(:callback) { proc { |msg| } }
    let(:error_callback) { proc { |msg| } }

    let(:agent) do
      inst = described_class.allocate
      inst.instance_variable_set(:@provider, mock_provider)
      inst.instance_variable_set(:@model, mock_model)
      inst.instance_variable_set(:@registry, mock_registry)
      inst.instance_variable_set(:@max_iterations, 10)
      inst
    end

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
      allow(chat).to receive(:current_conversation).and_return(conversation)
      allow(conversation).to receive(:add)
      allow(conversation).to receive(:system_prompt).and_return("System prompt")
      allow(conversation).to receive(:history).and_return([])
      allow(conversation).to receive(:verbose).and_return(false)
      allow(conversation).to receive(:label?).and_return(false)
      allow(conversation).to receive(:message_count).and_return(2)
      allow(mock_registry).to receive(:schemas).and_return({})
    end

    it "creates a conversation if none provided" do
      expect(Botiasloop::Conversation).to receive(:new)
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      agent.chat("Hello", callback: callback)
    end

    it "uses chat's current conversation" do
      expect(Botiasloop::Conversation).not_to receive(:new)
      allow(chat).to receive(:current_conversation).and_return(conversation)
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      agent.chat("Hello", callback: callback, chat: chat)
    end

    it "returns a Loop::Run instance" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      run = agent.chat("Hello", callback: callback)
      expect(run).to be_a(Botiasloop::Loop::Run)
    end

    it "adds the run to active_loop_runs" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      described_class.active_loop_runs.clear
      agent.chat("Hello", callback: callback)
      expect(described_class.active_loop_runs.size).to eq(1)
    end

    it "passes callback to the run" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      my_callback = proc { |msg| }
      run = agent.chat("Hello", callback: my_callback, chat: chat)
      expect(run.instance_variable_get(:@callback)).to eq(my_callback)
    end

    it "passes error_callback to the run" do
      allow(mock_provider).to receive(:complete).and_return(
        double("response", tool_call?: false, content: "response", input_tokens: 0, output_tokens: 0)
      )
      my_error_callback = proc { |msg| }
      run = agent.chat("Hello", callback: callback, error_callback: my_error_callback, chat: chat)
      expect(run.instance_variable_get(:@error_callback)).to eq(my_error_callback)
    end

    it "requires callback" do
      expect { agent.chat("Hello") }.to raise_error(ArgumentError, "missing keyword: :callback")
    end
  end

  describe ".instance" do
    let(:mock_provider) { double("provider") }
    let(:mock_model) { double("model") }
    let(:mock_registry) { double("registry") }

    def create_agent_instance
      inst = described_class.allocate
      inst.instance_variable_set(:@provider, mock_provider)
      inst.instance_variable_set(:@model, mock_model)
      inst.instance_variable_set(:@registry, mock_registry)
      inst.instance_variable_set(:@max_iterations, 10)
      inst
    end

    it "returns the same instance on multiple calls" do
      described_class.instance = create_agent_instance
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1.object_id).to eq(instance2.object_id)
    end

    it "creates a new instance after reset" do
      original_instance = create_agent_instance
      described_class.instance = original_instance
      described_class.instance = nil
      new_instance = create_agent_instance
      described_class.instance = new_instance

      expect(new_instance.object_id).not_to eq(original_instance.object_id)
    end
  end

  describe ".chat" do
    let(:mock_instance) { instance_double(described_class) }
    let(:callback) { proc { |msg| } }

    before do
      described_class.instance = mock_instance
    end

    after do
      described_class.instance = nil
    end

    it "delegates to the singleton instance" do
      chat = instance_double(Botiasloop::Chat)

      expect(mock_instance).to receive(:chat).with(
        "Hello",
        callback: callback,
        error_callback: nil,
        completion_callback: nil,
        chat: chat
      ).and_return(double("run"))

      described_class.chat("Hello", callback: callback, chat: chat)
    end
  end

  describe ".active_loop_runs" do
    it "returns an array" do
      expect(described_class.active_loop_runs).to be_an(Array)
    end

    it "is empty by default" do
      expect(described_class.active_loop_runs).to be_empty
    end
  end
end
