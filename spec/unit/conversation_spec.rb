# frozen_string_literal: true

require "spec_helper"
require "securerandom"
require "json"
require "time"
require "tmpdir"

RSpec.describe Botiasloop::Conversation do
  let(:temp_dir) { Dir.mktmpdir("conversations") }
  let(:fixed_uuid) { "550e8400-e29b-41d4-a716-446655440000" }

  before do
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with("~/conversations/#{fixed_uuid}.jsonl").and_return(File.join(temp_dir, "#{fixed_uuid}.jsonl"))
  end

  after do
    FileUtils.rm_rf(temp_dir)
    FileUtils.rm_rf(File.expand_path("~/conversations"))
  end

  describe "#initialize" do
    context "with no uuid provided" do
      it "generates a new uuid" do
        allow(SecureRandom).to receive(:uuid).and_return(fixed_uuid)
        conversation = described_class.new
        expect(conversation.uuid).to eq(fixed_uuid)
      end
    end

    context "with uuid provided" do
      it "uses the provided uuid" do
        conversation = described_class.new(fixed_uuid)
        expect(conversation.uuid).to eq(fixed_uuid)
      end
    end
  end

  describe "#path" do
    it "returns the correct path" do
      conversation = described_class.new(fixed_uuid)
      expect(conversation.path).to eq(File.join(temp_dir, "#{fixed_uuid}.jsonl"))
    end
  end

  describe "#add" do
    let(:conversation) { described_class.new(fixed_uuid) }

    it "adds a message to the conversation" do
      conversation.add("user", "Hello")
      expect(conversation.history.length).to eq(1)
      expect(conversation.history.first[:role]).to eq("user")
      expect(conversation.history.first[:content]).to eq("Hello")
    end

    it "persists to file" do
      conversation.add("user", "Hello")
      expect(File.exist?(conversation.path)).to be true

      lines = File.readlines(conversation.path)
      expect(lines.length).to eq(1)

      data = JSON.parse(lines.first, symbolize_names: true)
      expect(data[:role]).to eq("user")
      expect(data[:content]).to eq("Hello")
      expect(data[:timestamp]).to be_a(String)
    end

    it "appends multiple messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi there!")

      lines = File.readlines(conversation.path)
      expect(lines.length).to eq(2)

      data1 = JSON.parse(lines[0], symbolize_names: true)
      data2 = JSON.parse(lines[1], symbolize_names: true)

      expect(data1[:role]).to eq("user")
      expect(data2[:role]).to eq("assistant")
    end
  end

  describe "#history" do
    let(:conversation) { described_class.new(fixed_uuid) }

    it "returns empty array for new conversation" do
      expect(conversation.history).to eq([])
    end

    it "returns all messages" do
      conversation.add("user", "Hello")
      conversation.add("assistant", "Hi!")

      history = conversation.history
      expect(history.length).to eq(2)
      expect(history[0][:content]).to eq("Hello")
      expect(history[1][:content]).to eq("Hi!")
    end

    it "loads from file when conversation exists" do
      conversation.add("user", "Hello")

      # Create new instance with same uuid
      conversation2 = described_class.new(fixed_uuid)
      expect(conversation2.history.length).to eq(1)
      expect(conversation2.history.first[:content]).to eq("Hello")
    end

    it "returns a copy of messages" do
      conversation.add("user", "Hello")
      history = conversation.history
      history.clear
      expect(conversation.history.length).to eq(1)
    end
  end

  describe "timestamp" do
    let(:conversation) { described_class.new(fixed_uuid) }
    let(:fixed_time) { Time.parse("2026-02-20T10:00:00Z") }

    it "includes ISO8601 timestamp" do
      allow(Time).to receive(:now).and_return(fixed_time)
      conversation.add("user", "Hello")

      lines = File.readlines(conversation.path)
      data = JSON.parse(lines.first, symbolize_names: true)
      expect(data[:timestamp]).to eq("2026-02-20T10:00:00Z")
    end
  end
end
