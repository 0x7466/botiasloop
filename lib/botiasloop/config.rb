# frozen_string_literal: true

require "yaml"

module Botiasloop
  class Config
    DEFAULTS = {
      "model" => "moonshotai/kimi-k2.5",
      "max_iterations" => 20,
      "searxng_url" => "http://localhost:8080"
    }.freeze

    # Load configuration from file
    #
    # @param path [String, nil] Path to config file (default: ~/.config/botiasloop/config.yml)
    # @return [Config] Configuration instance
    def self.load(path = nil)
      path ||= File.expand_path("~/.config/botiasloop/config.yml")

      config = if File.exist?(path)
        YAML.load_file(path)
      else
        {}
      end

      new(config)
    end

    # @param config [Hash] Configuration hash
    def initialize(config)
      @config = config || {}
    end

    # @return [String] Model identifier
    def model
      @config["model"] || DEFAULTS["model"]
    end

    # @return [Integer] Maximum ReAct iterations
    def max_iterations
      @config["max_iterations"] || DEFAULTS["max_iterations"]
    end

    # @return [String] SearXNG URL
    def searxng_url
      ENV.fetch("BOTIASLOOP_SEARXNG_URL") do
        @config["searxng_url"] || DEFAULTS["searxng_url"]
      end
    end

    # @return [String] OpenRouter API key
    # @raise [Error] If API key is not set
    def api_key
      ENV.fetch("BOTIASLOOP_API_KEY") do
        raise Error, "BOTIASLOOP_API_KEY environment variable is required"
      end
    end
  end
end
