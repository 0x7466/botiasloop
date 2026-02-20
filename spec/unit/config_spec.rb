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
          File.write(config_path, YAML.dump("model" => "custom/model", "max_iterations" => 10))
        end

        it "loads configuration from file" do
          config = described_class.load
          expect(config.model).to eq("custom/model")
          expect(config.max_iterations).to eq(10)
        end
      end

      context "when config file does not exist" do
        it "uses default values" do
          config = described_class.load
          expect(config.model).to eq("moonshotai/kimi-k2.5")
          expect(config.max_iterations).to eq(20)
        end
      end
    end

    context "with custom path" do
      let(:temp_file) { Tempfile.new("config.yml") }

      before do
        File.write(temp_file.path, YAML.dump("model" => "test/model"))
      end

      after do
        temp_file.close
        temp_file.unlink
      end

      it "loads from custom path" do
        config = described_class.load(temp_file.path)
        expect(config.model).to eq("test/model")
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
        File.write(config_path, YAML.dump("searxng_url" => "http://default:8080"))
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

  describe "#api_key" do
    let(:config) { described_class.new({}) }

    it "reads from BOTIASLOOP_API_KEY environment variable" do
      with_env("BOTIASLOOP_API_KEY" => "test-key-123") do
        expect(config.api_key).to eq("test-key-123")
      end
    end

    it "raises when environment variable is not set" do
      with_env("BOTIASLOOP_API_KEY" => nil) do
        expect { config.api_key }.to raise_error(Botiasloop::Error, /BOTIASLOOP_API_KEY/)
      end
    end
  end

  describe "#model" do
    it "returns configured model" do
      config = described_class.new({"model" => "custom/model"})
      expect(config.model).to eq("custom/model")
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.model).to eq("moonshotai/kimi-k2.5")
    end
  end

  describe "#max_iterations" do
    it "returns configured max_iterations" do
      config = described_class.new({"max_iterations" => 15})
      expect(config.max_iterations).to eq(15)
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.max_iterations).to eq(20)
    end
  end

  describe "#searxng_url" do
    it "returns configured searxng_url" do
      config = described_class.new({"searxng_url" => "http://custom:8080"})
      expect(config.searxng_url).to eq("http://custom:8080")
    end

    it "returns default when not configured" do
      config = described_class.new({})
      expect(config.searxng_url).to eq("http://localhost:8080")
    end
  end
end
