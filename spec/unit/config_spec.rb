# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "tempfile"

def with_env(vars)
  original = {}
  vars.each do |key, value|
    original[key] = ENV[key]
    ENV[key] = value
  end
  yield
ensure
  original.each do |key, value|
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end

RSpec.describe Botiasloop::Config do
  describe ".load" do
    context "with default path" do
      let(:config_dir) { Dir.mktmpdir("config") }
      let(:config_path) { File.join(config_dir, "config.yml") }

      before do
        FileUtils.mkdir_p(config_dir)
        allow(Dir).to receive(:home).and_return(File.dirname(config_dir))
        allow(File).to receive(:expand_path).and_call_original
        allow(File).to receive(:expand_path).with("~/.config/botiasloop/config.yml").and_return(config_path)
      end

      after do
        FileUtils.rm_rf(config_dir)
      end

      context "when config file exists" do
        before do
          File.write(config_path, YAML.dump(providers: {openrouter: {model: "custom/model"}}, max_iterations: 10))
        end

        it "loads configuration from file" do
          config = described_class.load
          expect(config.openrouter_model).to eq("custom/model")
          expect(config.max_iterations).to eq(10)
        end
      end

      context "when config file does not exist" do
        it "uses default values" do
          config = described_class.load
          expect(config.openrouter_model).to eq("moonshotai/kimi-k2.5")
          expect(config.max_iterations).to eq(20)
        end
      end
    end

    context "with custom path" do
      let(:temp_file) { Tempfile.new("config.yml") }

      before do
        File.write(temp_file.path, YAML.dump(providers: {openrouter: {model: "test/model"}}))
      end

      after do
        temp_file.close
        temp_file.unlink
      end

      it "loads from custom path" do
        config = described_class.load(temp_file.path)
        expect(config.openrouter_model).to eq("test/model")
      end
    end

    context "with environment variable overrides" do
      let(:config_dir) { Dir.mktmpdir("config") }
      let(:config_path) { File.join(config_dir, "config.yml") }

      before do
        FileUtils.mkdir_p(config_dir)
        allow(Dir).to receive(:home).and_return(File.dirname(config_dir))
        allow(File).to receive(:expand_path).and_call_original
        allow(File).to receive(:expand_path).with("~/.config/botiasloop/config.yml").and_return(config_path)
        File.write(config_path, YAML.dump(searxng_url: "http://default:8080"))
      end

      after do
        FileUtils.rm_rf(config_dir)
      end

      it "uses BOTIASLOOP_SEARXNG_URL environment variable" do
        with_env("BOTIASLOOP_SEARXNG_URL" => "http://custom:8080") do
          config = described_class.load
          expect(config.searxng_url).to eq("http://custom:8080")
        end
      end
    end
  end

  describe "#openrouter_api_key" do
    let(:config) { described_class.new({}) }

    it "reads from OPENROUTER_API_KEY environment variable" do
      with_env("OPENROUTER_API_KEY" => "test-key-123") do
        expect(config.openrouter_api_key).to eq("test-key-123")
      end
    end

    it "reads from config file when env var not set" do
      config = described_class.new({providers: {openrouter: {api_key: "config-key-123"}}})
      with_env("OPENROUTER_API_KEY" => nil) do
        expect(config.openrouter_api_key).to eq("config-key-123")
      end
    end

    it "raises when environment variable and config are not set" do
      with_env("OPENROUTER_API_KEY" => nil) do
        expect { config.openrouter_api_key }.to raise_error(Botiasloop::Error, /OpenRouter API key required/)
      end
    end
  end

  describe "#providers" do
    it "returns empty hash when not configured" do
      config = described_class.new({})
      expect(config.providers).to eq({})
    end

    it "returns providers configuration" do
      config = described_class.new({providers: {openrouter: {api_key: "test"}}})
      expect(config.providers).to eq({openrouter: {api_key: "test"}})
    end
  end

  describe "#openrouter" do
    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.openrouter).to eq({model: "moonshotai/kimi-k2.5"})
    end

    it "returns openrouter configuration" do
      config = described_class.new({providers: {openrouter: {api_key: "test", model: "model"}}})
      expect(config.openrouter).to eq({api_key: "test", model: "model"})
    end
  end

  describe "#openrouter_model" do
    it "returns configured model from openrouter provider" do
      config = described_class.new({providers: {openrouter: {model: "custom/model"}}})
      expect(config.openrouter_model).to eq("custom/model")
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.openrouter_model).to eq("moonshotai/kimi-k2.5")
    end
  end

  describe "#max_iterations" do
    it "returns configured max_iterations" do
      config = described_class.new({max_iterations: 15})
      expect(config.max_iterations).to eq(15)
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.max_iterations).to eq(20)
    end
  end

  describe "#searxng_url" do
    it "returns configured searxng_url" do
      config = described_class.new({searxng_url: "http://custom:8080"})
      expect(config.searxng_url).to eq("http://custom:8080")
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.searxng_url).to eq("http://localhost:8080")
    end
  end
end
