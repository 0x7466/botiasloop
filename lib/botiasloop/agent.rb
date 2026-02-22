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
    # @return [String] Assistant response
    def chat(message, conversation: nil)
      conversation ||= Conversation.new

      registry = create_registry
      provider, model = create_provider_and_model
      loop = Loop.new(provider, model, registry, max_iterations: @config.max_iterations)

      loop.run(conversation, message)
    rescue MaxIterationsExceeded => e
      e.message
    end

    private

    def setup_ruby_llm
      RubyLLM.configure do |config|
        config.openrouter_api_key = @config.providers["openrouter"]["api_key"]
      end
    end

    def create_provider_and_model
      model_id = @config.providers["openrouter"]["model"]
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
