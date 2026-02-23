# frozen_string_literal: true

require "anyway_config"

Anyway::Settings.default_config_path = ->(_) { File.expand_path("~/.config/botiasloop/config.yml") }

module Botiasloop
  class Config < Anyway::Config
    attr_config \
      max_iterations: 20,
      log_level: "info",
      tools: {
        web_search: {}
      },
      providers: {
        openrouter: {
          model: "moonshotai/kimi-k2.5"
        }
      },
      channels: {
        telegram: {
          allowed_users: []
        }
      },
      commands: {
        summarize: {}
      },
      features: {
        auto_labelling: {
          enabled: true
        }
      }

    # Validation
    required :providers

    # Returns the first configured provider name and its config
    # @return [Array<String, Hash>] provider name and config
    def active_provider
      providers.each do |name, config|
        return [name.to_s, config] if provider_configured?(name, config)
      end
      ["openrouter", providers["openrouter"]]
    end

    private

    def provider_configured?(name, config)
      # Local providers need api_base
      return true if %w[ollama gpustack].include?(name.to_s) && config["api_base"]

      # Cloud providers need api_key
      return true if config["api_key"]

      # VertexAI needs project_id
      return true if name.to_s == "vertexai" && config["project_id"]

      # Azure needs api_base (and either api_key or ai_auth_token)
      return true if name.to_s == "azure" && config["api_base"]

      false
    end
  end
end
