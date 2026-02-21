# frozen_string_literal: true

require "anyway_config"

Anyway::Settings.default_config_path = ->(_) { File.expand_path("~/.config/botiasloop/config.yml") }

module Botiasloop
  class Config < Anyway::Config
    attr_config \
      max_iterations: 20,
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
      }

    # Validation
    required :providers
  end
end
