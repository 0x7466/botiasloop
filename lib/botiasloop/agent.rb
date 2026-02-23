# frozen_string_literal: true

require "ruby_llm"
require "logger"

module Botiasloop
  class Agent
    # Initialize the agent
    #
    # @param config [Config, nil] Configuration instance (loads default if nil)
    def initialize(config = nil)
      @config = config || Config.new
      @logger = Logger.new($stderr)
      setup_ruby_llm
    end

    # Send a message and get a response
    #
    # @param message [String] User message
    # @param conversation [Conversation, nil] Existing conversation
    # @param verbose_callback [Proc, nil] Callback for verbose messages
    # @return [String] Assistant response
    def chat(message, conversation: nil, verbose_callback: nil)
      conversation ||= Conversation.new

      registry = create_registry
      provider, model = create_provider_and_model
      loop = Loop.new(provider, model, registry, max_iterations: @config.max_iterations)

      loop.run(conversation, message, verbose_callback)
    rescue MaxIterationsExceeded => e
      e.message
    end

    private

    def setup_ruby_llm
      provider_name, provider_config = @config.active_provider

      RubyLLM.configure do |config|
        configure_provider(config, provider_name, provider_config)
      end
    end

    def configure_provider(config, provider_name, provider_config)
      case provider_name
      when "openai"
        config.openai_api_key = provider_config["api_key"]
        config.openai_organization_id = provider_config["organization_id"] if provider_config["organization_id"]
        config.openai_project_id = provider_config["project_id"] if provider_config["project_id"]
        config.openai_api_base = provider_config["api_base"] if provider_config["api_base"]
      when "anthropic"
        config.anthropic_api_key = provider_config["api_key"]
      when "gemini"
        config.gemini_api_key = provider_config["api_key"]
        config.gemini_api_base = provider_config["api_base"] if provider_config["api_base"]
      when "vertexai"
        config.vertexai_project_id = provider_config["project_id"]
        config.vertexai_location = provider_config["location"] if provider_config["location"]
      when "deepseek"
        config.deepseek_api_key = provider_config["api_key"]
      when "mistral"
        config.mistral_api_key = provider_config["api_key"]
      when "perplexity"
        config.perplexity_api_key = provider_config["api_key"]
      when "openrouter"
        config.openrouter_api_key = provider_config["api_key"]
      when "ollama"
        config.ollama_api_base = provider_config["api_base"] || "http://localhost:11434/v1"
      when "gpustack"
        config.gpustack_api_base = provider_config["api_base"]
        config.gpustack_api_key = provider_config["api_key"] if provider_config["api_key"]
      when "bedrock"
        config.bedrock_api_key = provider_config["api_key"] if provider_config["api_key"]
        config.bedrock_secret_key = provider_config["secret_key"] if provider_config["secret_key"]
        config.bedrock_region = provider_config["region"] if provider_config["region"]
        config.bedrock_session_token = provider_config["session_token"] if provider_config["session_token"]
      when "azure"
        config.azure_api_base = provider_config["api_base"]
        if provider_config["api_key"]
          config.azure_api_key = provider_config["api_key"]
        elsif provider_config["ai_auth_token"]
          config.azure_ai_auth_token = provider_config["ai_auth_token"]
        end
      end
    end

    def create_provider_and_model
      _provider_name, provider_config = @config.active_provider
      model_id = provider_config["model"]
      model = RubyLLM::Models.find(model_id)
      provider_class = RubyLLM::Provider.for(model_id)
      provider = provider_class.new(RubyLLM.config)
      [provider, model]
    end

    def create_registry
      registry = Tools::Registry.new
      registry.register(Tools::Shell)
      registry.register(Tools::WebSearch, searxng_url: web_search_url) if web_search_configured?
      registry
    end

    def web_search_configured?
      url = web_search_url
      url && !url.empty?
    end

    def web_search_url
      @config.tools["web_search"]["searxng_url"]
    end
  end
end
