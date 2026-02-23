# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Agent do
  let(:config) do
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

  describe "#initialize" do
    it "accepts a config" do
      agent = described_class.new(config)
      expect(agent.instance_variable_get(:@config)).to eq(config)
    end

    it "loads default config if none provided" do
      allow(Botiasloop::Config).to receive(:new).and_return(config)
      agent = described_class.new
      expect(agent.instance_variable_get(:@config)).to eq(config)
    end
  end

  describe "#chat" do
    let(:agent) { described_class.new(config) }
    let(:conversation) { instance_double(Botiasloop::Conversation) }
    let(:mock_loop) { instance_double(Botiasloop::Loop) }
    let(:mock_provider) { double("provider") }
    let(:mock_provider_class) { double("provider_class") }
    let(:mock_model) { double("model") }

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
      allow(Botiasloop::Loop).to receive(:new).and_return(mock_loop)
      allow(conversation).to receive(:uuid).and_return("test-uuid")
      allow(RubyLLM::Models).to receive(:find).and_return(mock_model)
      allow(RubyLLM::Provider).to receive(:for).and_return(mock_provider_class)
      allow(mock_provider_class).to receive(:new).and_return(mock_provider)
    end

    it "creates a conversation if none provided" do
      expect(Botiasloop::Conversation).to receive(:new)
      allow(mock_loop).to receive(:run).and_return("response")
      agent.chat("Hello")
    end

    it "uses provided conversation" do
      existing_conv = instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
      expect(Botiasloop::Conversation).not_to receive(:new)
      allow(mock_loop).to receive(:run).and_return("response")
      agent.chat("Hello", conversation: existing_conv)
    end

    it "returns the response" do
      allow(mock_loop).to receive(:run).and_return("This is the response")
      result = agent.chat("Hello")
      expect(result).to eq("This is the response")
    end

    it "creates provider and model" do
      allow(mock_loop).to receive(:run).and_return("response")
      expect(RubyLLM::Models).to receive(:find).with("test/model").and_return(mock_model)
      expect(RubyLLM::Provider).to receive(:for).with("test/model").and_return(mock_provider_class)
      expect(mock_provider_class).to receive(:new).with(RubyLLM.config).and_return(mock_provider)
      agent.chat("Hello")
    end

    it "creates loop with provider, model and registry" do
      allow(mock_loop).to receive(:run).and_return("response")
      expect(Botiasloop::Loop).to receive(:new) do |provider, model, registry, **kwargs|
        expect(provider).to eq(mock_provider)
        expect(model).to eq(mock_model)
        expect(registry).to be_a(Botiasloop::Tools::Registry)
        expect(kwargs[:max_iterations]).to eq(10)
        mock_loop
      end
      agent.chat("Hello")
    end

    context "when web_search is not configured" do
      let(:config_without_web_search) do
        Botiasloop::Config.new({
          "max_iterations" => 10,
          "providers" => {
            "openrouter" => {
              "api_key" => "test-api-key",
              "model" => "test/model"
            }
          }
        })
      end

      let(:agent_without_web_search) { described_class.new(config_without_web_search) }

      it "creates registry without web_search tool" do
        allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
        allow(Botiasloop::Loop).to receive(:new).and_return(mock_loop)
        allow(conversation).to receive(:uuid).and_return("test-uuid")
        allow(RubyLLM::Models).to receive(:find).and_return(mock_model)
        allow(RubyLLM::Provider).to receive(:for).and_return(mock_provider_class)
        allow(mock_provider_class).to receive(:new).and_return(mock_provider)
        allow(mock_loop).to receive(:run).and_return("response")

        expect(Botiasloop::Loop).to receive(:new) do |provider, model, registry, **kwargs|
          expect(registry.tool_classes).not_to include(Botiasloop::Tools::WebSearch)
          expect(registry.tool_classes).to include(Botiasloop::Tools::Shell)
          mock_loop
        end

        agent_without_web_search.chat("Hello")
      end
    end

    context "with different providers" do
      # Note: We test that providers are configured correctly in config_spec.rb
      # Here we just verify the Agent properly uses whatever provider is active

      it "uses the active provider's model" do
        allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
        allow(Botiasloop::Loop).to receive(:new).and_return(mock_loop)
        allow(conversation).to receive(:uuid).and_return("test-uuid")
        allow(RubyLLM::Models).to receive(:find).and_return(mock_model)
        allow(RubyLLM::Provider).to receive(:for).and_return(mock_provider_class)
        allow(mock_provider_class).to receive(:new).and_return(mock_provider)
        allow(mock_loop).to receive(:run).and_return("response")

        expect(RubyLLM::Models).to receive(:find).with("test/model").and_return(mock_model)
        agent.chat("Hello")
      end
    end
  end
end
