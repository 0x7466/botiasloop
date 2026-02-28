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

  describe "#provider_configured?" do
    let(:agent) { described_class.allocate }

    it "returns true for ollama with api_base" do
      expect(agent.send(:provider_configured?, "ollama", {"api_base" => "http://localhost:11434"})).to be true
    end

    it "returns true for gpustack with api_base" do
      expect(agent.send(:provider_configured?, "gpustack", {"api_base" => "http://localhost:8000"})).to be true
    end

    it "returns true with api_key" do
      expect(agent.send(:provider_configured?, "openai", {"api_key" => "sk-test"})).to be true
    end

    it "returns true for vertexai with project_id" do
      expect(agent.send(:provider_configured?, "vertexai", {"project_id" => "my-project"})).to be true
    end

    it "returns true for azure with api_base" do
      expect(agent.send(:provider_configured?, "azure", {"api_base" => "https://example.openai.azure.com"})).to be true
    end

    it "returns false for unknown provider without config" do
      expect(agent.send(:provider_configured?, "unknown", {})).to be false
    end
  end

  describe "#configure_provider" do
    let(:agent) { described_class.allocate }
    let(:config) { double("RubyLLM::Config") }

    it "configures openai with api_key" do
      expect(config).to receive(:openai_api_key=).with("sk-test")
      agent.send(:configure_provider, config, "openai", {"api_key" => "sk-test"})
    end

    it "configures openai with organization_id" do
      expect(config).to receive(:openai_api_key=).with("sk-test")
      expect(config).to receive(:openai_organization_id=).with("org-123")
      agent.send(:configure_provider, config, "openai", {"api_key" => "sk-test", "organization_id" => "org-123"})
    end

    it "configures openai with project_id" do
      expect(config).to receive(:openai_api_key=).with("sk-test")
      expect(config).to receive(:openai_project_id=).with("proj-123")
      agent.send(:configure_provider, config, "openai", {"api_key" => "sk-test", "project_id" => "proj-123"})
    end

    it "configures openai with api_base" do
      expect(config).to receive(:openai_api_key=).with("sk-test")
      expect(config).to receive(:openai_api_base=).with("https://custom.example.com")
      agent.send(:configure_provider, config, "openai", {"api_key" => "sk-test", "api_base" => "https://custom.example.com"})
    end

    it "configures anthropic with api_key" do
      expect(config).to receive(:anthropic_api_key=).with("sk-ant-test")
      agent.send(:configure_provider, config, "anthropic", {"api_key" => "sk-ant-test"})
    end

    it "configures gemini with api_key" do
      expect(config).to receive(:gemini_api_key=).with("gemini-key")
      agent.send(:configure_provider, config, "gemini", {"api_key" => "gemini-key"})
    end

    it "configures gemini with api_base" do
      expect(config).to receive(:gemini_api_key=).with("gemini-key")
      expect(config).to receive(:gemini_api_base=).with("https://custom-gemini.example.com")
      agent.send(:configure_provider, config, "gemini", {"api_key" => "gemini-key", "api_base" => "https://custom-gemini.example.com"})
    end

    it "configures vertexai with project_id" do
      expect(config).to receive(:vertexai_project_id=).with("my-project")
      agent.send(:configure_provider, config, "vertexai", {"project_id" => "my-project"})
    end

    it "configures vertexai with location" do
      expect(config).to receive(:vertexai_project_id=).with("my-project")
      expect(config).to receive(:vertexai_location=).with("us-central1")
      agent.send(:configure_provider, config, "vertexai", {"project_id" => "my-project", "location" => "us-central1"})
    end

    it "configures deepseek with api_key" do
      expect(config).to receive(:deepseek_api_key=).with("deepseek-key")
      agent.send(:configure_provider, config, "deepseek", {"api_key" => "deepseek-key"})
    end

    it "configures mistral with api_key" do
      expect(config).to receive(:mistral_api_key=).with("mistral-key")
      agent.send(:configure_provider, config, "mistral", {"api_key" => "mistral-key"})
    end

    it "configures perplexity with api_key" do
      expect(config).to receive(:perplexity_api_key=).with("perplexity-key")
      agent.send(:configure_provider, config, "perplexity", {"api_key" => "perplexity-key"})
    end

    it "configures openrouter with api_key" do
      expect(config).to receive(:openrouter_api_key=).with("openrouter-key")
      agent.send(:configure_provider, config, "openrouter", {"api_key" => "openrouter-key"})
    end

    it "configures ollama with api_base" do
      expect(config).to receive(:ollama_api_base=).with("http://localhost:11434/v1")
      agent.send(:configure_provider, config, "ollama", {"api_base" => "http://localhost:11434/v1"})
    end

    it "configures ollama with default api_base" do
      expect(config).to receive(:ollama_api_base=).with("http://localhost:11434/v1")
      agent.send(:configure_provider, config, "ollama", {})
    end

    it "configures gpustack with api_base" do
      expect(config).to receive(:gpustack_api_base=).with("http://localhost:8000")
      agent.send(:configure_provider, config, "gpustack", {"api_base" => "http://localhost:8000"})
    end

    it "configures gpustack with api_key" do
      expect(config).to receive(:gpustack_api_base=).with("http://localhost:8000")
      expect(config).to receive(:gpustack_api_key=).with("gpustack-key")
      agent.send(:configure_provider, config, "gpustack", {"api_base" => "http://localhost:8000", "api_key" => "gpustack-key"})
    end

    it "configures bedrock with api_key" do
      expect(config).to receive(:bedrock_api_key=).with("bedrock-key")
      agent.send(:configure_provider, config, "bedrock", {"api_key" => "bedrock-key"})
    end

    it "configures bedrock with secret_key" do
      expect(config).to receive(:bedrock_secret_key=).with("secret-key")
      agent.send(:configure_provider, config, "bedrock", {"secret_key" => "secret-key"})
    end

    it "configures bedrock with region" do
      expect(config).to receive(:bedrock_region=).with("us-east-1")
      agent.send(:configure_provider, config, "bedrock", {"region" => "us-east-1"})
    end

    it "configures bedrock with session_token" do
      expect(config).to receive(:bedrock_session_token=).with("session-token")
      agent.send(:configure_provider, config, "bedrock", {"session_token" => "session-token"})
    end

    it "configures azure with api_base" do
      expect(config).to receive(:azure_api_base=).with("https://example.openai.azure.com")
      agent.send(:configure_provider, config, "azure", {"api_base" => "https://example.openai.azure.com"})
    end

    it "configures azure with api_key" do
      expect(config).to receive(:azure_api_base=).with("https://example.openai.azure.com")
      expect(config).to receive(:azure_api_key=).with("azure-key")
      agent.send(:configure_provider, config, "azure", {"api_base" => "https://example.openai.azure.com", "api_key" => "azure-key"})
    end

    it "configures azure with ai_auth_token" do
      expect(config).to receive(:azure_api_base=).with("https://example.openai.azure.com")
      expect(config).to receive(:azure_ai_auth_token=).with("auth-token")
      agent.send(:configure_provider, config, "azure", {"api_base" => "https://example.openai.azure.com", "ai_auth_token" => "auth-token"})
    end
  end
end
