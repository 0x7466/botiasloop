# frozen_string_literal: true

require "ruby_llm"

module Botiasloop
  class Agent
    @instance = nil
    @mutex = Mutex.new
    @active_loop_runs = []

    class << self
      # @return [Agent] Singleton instance of the agent
      def instance
        @instance ||= new
      end

      # @return [Array<Loop::Run>] Active loop runs
      def active_loop_runs
        @active_loop_runs ||= []
      end

      # Send a message and get a response asynchronously
      #
      # @param message [String] User message
      # @param callback [Proc] Callback for messages (verbose + final response)
      # @param error_callback [Proc, nil] Callback for errors
      # @param conversation [Conversation, nil] Existing conversation
      # @return [Loop::Run] Run instance
      def chat(message, callback:, error_callback: nil, conversation: nil)
        instance.chat(message, callback: callback, error_callback: error_callback, conversation: conversation)
      end

      # Set the instance directly (primarily for testing)
      # @param agent [Agent, nil] Agent instance or nil to reset
      attr_writer :instance
    end

    # Initialize the agent
    def initialize
      setup_ruby_llm

      @provider, @model = create_provider_and_model
      @registry = create_registry
      @max_iterations = Config.instance.max_iterations
    end

    # Send a message and get a response asynchronously
    #
    # @param message [String] User message
    # @param callback [Proc] Callback for messages (verbose + final response)
    # @param error_callback [Proc, nil] Callback for errors
    # @param conversation [Conversation, nil] Existing conversation
    # @return [Loop::Run] Run instance
    def chat(message, callback:, error_callback: nil, conversation: nil)
      conversation ||= Conversation.new

      run = Loop::Run.new(
        provider: @provider,
        model: @model,
        registry: @registry,
        max_iterations: @max_iterations,
        conversation: conversation,
        user_input: message,
        callback: callback,
        error_callback: error_callback
      )

      self.class.active_loop_runs << run
      run.start
    end

    private

    def setup_ruby_llm
      provider_name, provider_config = Config.instance.active_provider

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
      _provider_name, provider_config = Config.instance.active_provider
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
      Config.instance.tools["web_search"]["searxng_url"]
    end
  end
end
