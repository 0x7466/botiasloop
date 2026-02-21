# frozen_string_literal: true

require "yaml"

module Botiasloop
  class Config
    DEFAULTS = {
      providers: {
        openrouter: {
          model: "moonshotai/kimi-k2.5"
        }
      },
      max_iterations: 20,
      searxng_url: "http://localhost:8080"
    }.freeze

    # Load configuration from file
    #
    # @param path [String, nil] Path to config file (default: ~/.config/botiasloop/config.yml)
    # @return [Config] Configuration instance
    def self.load(path = nil)
      path ||= File.expand_path("~/.config/botiasloop/config.yml")

      config = if File.exist?(path)
        YAML.load_file(path, symbolize_names: true)
      else
        {}
      end

      new(config)
    end

    # @param config [Hash] Configuration hash
    def initialize(config)
      @config = config || {}
    end

    # @return [Hash] Providers configuration
    def providers
      @config[:providers] || {}
    end

    # @return [Hash] OpenRouter provider configuration
    def openrouter
      providers[:openrouter] || DEFAULTS[:providers][:openrouter] || {}
    end

    # @return [String] OpenRouter model identifier
    def openrouter_model
      openrouter[:model]
    end

    # @return [Integer] Maximum ReAct iterations
    def max_iterations
      @config[:max_iterations] || DEFAULTS[:max_iterations]
    end

    # @return [String] SearXNG URL
    def searxng_url
      @config[:searxng_url] || ENV["BOTIASLOOP_SEARXNG_URL"] || DEFAULTS[:searxng_url]
    end

    # @return [String] OpenRouter API key
    # @raise [Error] If API key is not set
    def openrouter_api_key
      openrouter[:api_key] || ENV["OPENROUTER_API_KEY"] || raise(Error, "OpenRouter API key required")
    end

    # @return [Hash] Telegram configuration
    def telegram
      @config[:telegram] || {}
    end

    # @return [String, nil] Telegram bot token
    def telegram_bot_token
      telegram[:bot_token]
    end

    # @return [Array<String>] Allowed Telegram usernames
    def telegram_allowed_users
      telegram[:allowed_users] || []
    end
  end
end
