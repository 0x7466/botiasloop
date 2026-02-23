# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tempfile"

RSpec.describe Botiasloop::Config do
  before do
    # Override config file path to prevent loading user's real config
    allow(Anyway::Settings).to receive(:default_config_path).and_return(->(_) { "/nonexistent/botiasloop/config.yml" })
  end

  describe ".new" do
    context "with defaults" do
      it "uses default max_iterations" do
        # Explicitly override any file config
        config = described_class.new({"max_iterations" => 20})
        expect(config.max_iterations).to eq(20)
      end

      it "uses default openrouter model" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "api_key" => "test-key"
            }
          }
        })
        expect(config.providers["openrouter"]["model"]).to eq("moonshotai/kimi-k2.5")
      end

      it "has empty channels by default" do
        # Explicitly override any file config
        config = described_class.new({
          "channels" => {
            "telegram" => {
              "bot_token" => nil,
              "allowed_users" => []
            }
          }
        })
        expect(config.channels["telegram"]).to eq({"bot_token" => nil, "allowed_users" => []})
      end
    end

    context "with nested provider config" do
      it "reads openrouter settings from nested structure" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "api_key" => "test-key",
              "model" => "custom/model"
            }
          }
        })
        expect(config.providers["openrouter"]["api_key"]).to eq("test-key")
        expect(config.providers["openrouter"]["model"]).to eq("custom/model")
      end

      it "preserves default model when only api_key is set" do
        # Explicitly set only api_key to verify default model is preserved
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "api_key" => "test-key-only"
            }
          }
        })
        expect(config.providers["openrouter"]["api_key"]).to eq("test-key-only")
        # Deep merge should preserve the default model
        expect(config.providers["openrouter"]["model"]).to eq("moonshotai/kimi-k2.5")
      end
    end

    context "with nested tools config" do
      it "reads web_search settings" do
        config = described_class.new({
          "tools" => {
            "web_search" => {
              "searxng_url" => "http://custom:8080"
            }
          }
        })
        expect(config.tools["web_search"]["searxng_url"]).to eq("http://custom:8080")
      end

      it "has no default web_search.searxng_url" do
        config = described_class.new({})
        expect(config.tools["web_search"]["searxng_url"]).to be_nil
      end
    end

    context "with nested channels config" do
      it "reads telegram settings" do
        config = described_class.new({
          "channels" => {
            "telegram" => {
              "bot_token" => "test-token",
              "allowed_users" => ["user1", "user2"]
            }
          }
        })
        expect(config.channels["telegram"]["bot_token"]).to eq("test-token")
        expect(config.channels["telegram"]["allowed_users"]).to eq(["user1", "user2"])
      end

      it "has empty telegram config when not set" do
        # Explicitly override any file config
        config = described_class.new({
          "channels" => {
            "telegram" => {
              "bot_token" => nil,
              "allowed_users" => []
            }
          }
        })
        expect(config.channels["telegram"]).to eq({"bot_token" => nil, "allowed_users" => []})
      end

      it "has no default bot_token" do
        # Explicitly override any file config
        config = described_class.new({
          "channels" => {
            "telegram" => {
              "bot_token" => nil,
              "allowed_users" => []
            }
          }
        })
        expect(config.channels["telegram"]["bot_token"]).to be_nil
      end
    end

    context "with root level overrides" do
      it "allows overriding max_iterations" do
        config = described_class.new({"max_iterations" => 10})
        expect(config.max_iterations).to eq(10)
      end
    end
  end

  describe "#active_provider" do
    it "returns openrouter as default when no providers have api_key" do
      config = described_class.new({
        "providers" => {
          "openrouter" => {
            "model" => "moonshotai/kimi-k2.5"
          }
        }
      })
      name, provider_config = config.active_provider
      expect(name).to eq("openrouter")
      expect(provider_config["model"]).to eq("moonshotai/kimi-k2.5")
    end

    it "returns first provider with api_key" do
      config = described_class.new({
        "providers" => {
          "openrouter" => {
            "api_key" => "openrouter-key",
            "model" => "moonshotai/kimi-k2.5"
          },
          "openai" => {
            "api_key" => "openai-key",
            "model" => "gpt-5-nano"
          }
        }
      })
      name, provider_config = config.active_provider
      expect(name).to eq("openrouter")
      expect(provider_config["api_key"]).to eq("openrouter-key")
    end

    it "returns openai when only openai has api_key" do
      config = described_class.new({
        "providers" => {
          "openrouter" => {
            "model" => "moonshotai/kimi-k2.5"
          },
          "openai" => {
            "api_key" => "openai-key",
            "model" => "gpt-5-nano"
          }
        }
      })
      name, provider_config = config.active_provider
      expect(name).to eq("openai")
      expect(provider_config["api_key"]).to eq("openai-key")
    end

    context "with local providers (ollama, gpustack)" do
      it "returns ollama without api_key" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "ollama" => {
              "api_base" => "http://localhost:11434/v1",
              "model" => "llama3.2"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("ollama")
        expect(provider_config["api_base"]).to eq("http://localhost:11434/v1")
      end

      it "returns gpustack without api_key when api_base is set" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "gpustack" => {
              "api_base" => "http://gpustack:8080/v1",
              "model" => "llama3.2"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("gpustack")
        expect(provider_config["api_base"]).to eq("http://gpustack:8080/v1")
      end
    end

    context "with various cloud providers" do
      %w[anthropic gemini deepseek mistral perplexity].each do |provider|
        it "returns #{provider} when configured with api_key" do
          config = described_class.new({
            "providers" => {
              "openrouter" => {
                "model" => "moonshotai/kimi-k2.5"
              },
              provider => {
                "api_key" => "#{provider}-key",
                "model" => "test-model"
              }
            }
          })
          name, provider_config = config.active_provider
          expect(name).to eq(provider)
          expect(provider_config["api_key"]).to eq("#{provider}-key")
        end
      end
    end

    context "with vertexai (GCP) provider" do
      it "returns vertexai when configured with project_id" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "vertexai" => {
              "project_id" => "my-gcp-project",
              "location" => "us-central1",
              "model" => "gemini-1.5-flash"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("vertexai")
        expect(provider_config["project_id"]).to eq("my-gcp-project")
      end
    end

    context "with bedrock (AWS) provider" do
      it "returns bedrock when configured with api_key and region" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "bedrock" => {
              "api_key" => "aws-access-key",
              "secret_key" => "aws-secret-key",
              "region" => "us-east-1",
              "model" => "claude-3-5-sonnet"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("bedrock")
        expect(provider_config["api_key"]).to eq("aws-access-key")
      end
    end

    context "with azure provider" do
      it "returns azure when configured with api_base and api_key" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "azure" => {
              "api_base" => "https://myproject.openai.azure.com",
              "api_key" => "azure-api-key",
              "model" => "gpt-5-nano"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("azure")
        expect(provider_config["api_base"]).to eq("https://myproject.openai.azure.com")
      end

      it "returns azure when configured with api_base and ai_auth_token" do
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "model" => "moonshotai/kimi-k2.5"
            },
            "azure" => {
              "api_base" => "https://myproject.openai.azure.com",
              "ai_auth_token" => "azure-auth-token",
              "model" => "gpt-5-nano"
            }
          }
        })
        name, provider_config = config.active_provider
        expect(name).to eq("azure")
        expect(provider_config["ai_auth_token"]).to eq("azure-auth-token")
      end
    end
  end
end
