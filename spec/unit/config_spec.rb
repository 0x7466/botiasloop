# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tempfile"

RSpec.describe Botiasloop::Config do
  describe ".new" do
    context "with defaults" do
      it "uses default max_iterations" do
        # Explicitly override any file config
        config = described_class.new({"max_iterations" => 20})
        expect(config.max_iterations).to eq(20)
      end

      it "uses default openrouter model" do
        config = described_class.new({})
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
        config = described_class.new({
          "providers" => {
            "openrouter" => {
              "api_key" => "test-key"
            }
          }
        })
        expect(config.providers["openrouter"]["api_key"]).to eq("test-key")
        # Deep merge preserves defaults
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
end
