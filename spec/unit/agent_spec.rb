# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Agent do
  let(:config) do
    instance_double(Botiasloop::Config,
      model: "test/model",
      max_iterations: 10,
      searxng_url: "http://searxng:8080",
      api_key: "test-api-key")
  end

  describe "#initialize" do
    it "accepts a config" do
      agent = described_class.new(config)
      expect(agent.instance_variable_get(:@config)).to eq(config)
    end

    it "loads default config if none provided" do
      allow(Botiasloop::Config).to receive(:load).and_return(config)
      agent = described_class.new
      expect(agent.instance_variable_get(:@config)).to eq(config)
    end
  end

  describe "#chat" do
    let(:agent) { described_class.new(config) }
    let(:conversation) { instance_double(Botiasloop::Conversation) }
    let(:mock_loop) { instance_double(Botiasloop::Loop) }
    let(:mock_chat) { double("chat") }

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
      allow(Botiasloop::Loop).to receive(:new).and_return(mock_loop)
      allow(conversation).to receive(:uuid).and_return("test-uuid")
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_tool)
      allow(mock_chat).to receive(:with_instructions)
    end

    it "creates a conversation if none provided" do
      expect(Botiasloop::Conversation).to receive(:new)
      allow(mock_loop).to receive(:run).and_return("response")
      agent.chat("Hello")
    end

    it "uses provided conversation" do
      existing_conv = instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
      expect(Botiasloop::Conversation).not_to receive(:new)
      allow(mock_loop).to receive(:run).and_return("response")
      agent.chat("Hello", conversation: existing_conv)
    end

    it "returns the response" do
      allow(mock_loop).to receive(:run).and_return("This is the response")
      result = agent.chat("Hello")
      expect(result).to eq("This is the response")
    end

    it "logs the conversation" do
      allow(mock_loop).to receive(:run).and_return("response")
      expect(agent.instance_variable_get(:@logger)).to receive(:info).with(/test-uuid/)
      agent.chat("Hello")
    end

    it "registers Shell tool with chat" do
      allow(mock_loop).to receive(:run).and_return("response")
      expect(mock_chat).to receive(:with_tool).with(Botiasloop::Tools::Shell).and_return(mock_chat)
      agent.chat("Hello")
    end

    it "registers WebSearch tool with chat" do
      allow(mock_loop).to receive(:run).and_return("response")
      websearch_tool = nil
      expect(mock_chat).to receive(:with_tool).twice do |tool|
        if tool.is_a?(Botiasloop::Tools::WebSearch)
          websearch_tool = tool
        end
        mock_chat
      end
      agent.chat("Hello")
      expect(websearch_tool).not_to be_nil
      expect(websearch_tool.instance_variable_get(:@searxng_url)).to eq("http://searxng:8080")
    end
  end

  describe "#system_prompt" do
    let(:agent) { described_class.new(config) }
    let(:registry) { Botiasloop::Tools::Registry.new }

    before do
      registry.register(Botiasloop::Tools::Shell)
      registry.register(Botiasloop::Tools::WebSearch, searxng_url: "http://searxng:8080")
    end

    it "includes ReAct guidance" do
      prompt = agent.send(:system_prompt, registry)
      expect(prompt).to include("You operate in a ReAct loop")
      expect(prompt).to include("Reason about the task, Act using tools, Observe results")
    end

    it "includes max iterations from config" do
      prompt = agent.send(:system_prompt, registry)
      expect(prompt).to include("You can think up to 10 times")
    end

    it "lists available tools" do
      prompt = agent.send(:system_prompt, registry)
      expect(prompt).to include("- shell: Execute a shell command and return the output")
      expect(prompt).to include("- web_search: Search the web using SearXNG")
    end

    it "includes environment information" do
      prompt = agent.send(:system_prompt, registry)
      expect(prompt).to include("Environment:")
      expect(prompt).to include("OS:")
      expect(prompt).to include("Working Directory:")
      expect(prompt).to include("Date:")
    end
  end

  describe "#interactive" do
    let(:agent) { described_class.new(config) }
    let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "interactive-uuid") }

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
    end

    it "enters interactive mode" do
      allow(agent).to receive(:gets).and_return("Hello", "exit")
      allow(agent).to receive(:puts)
      allow(agent).to receive(:chat).and_return("Response")

      expect { agent.interactive }.not_to raise_error
    end

    it "exits on 'exit'" do
      allow(agent).to receive(:gets).and_return("exit")
      allow(agent).to receive(:puts)

      expect { agent.interactive }.not_to raise_error
    end

    it "exits on 'quit'" do
      allow(agent).to receive(:gets).and_return("quit")
      allow(agent).to receive(:puts)

      expect { agent.interactive }.not_to raise_error
    end

    it "exits on '\\q'" do
      allow(agent).to receive(:gets).and_return("\\q")
      allow(agent).to receive(:puts)

      expect { agent.interactive }.not_to raise_error
    end

    it "handles Ctrl+C gracefully" do
      allow(agent).to receive(:gets).and_raise(Interrupt)
      allow(agent).to receive(:puts)

      expect { agent.interactive }.not_to raise_error
    end

    it "reuses the same conversation for multiple messages" do
      allow(agent).to receive(:gets).and_return("Hello", "World", "exit")
      allow(agent).to receive(:puts)
      allow(agent).to receive(:chat).with("Hello", conversation: conversation, log_start: true).and_return("Response1")
      allow(agent).to receive(:chat).with("World", conversation: conversation, log_start: false).and_return("Response2")

      expect(Botiasloop::Conversation).to receive(:new).once

      agent.interactive
    end

    it "logs only on first message in interactive mode" do
      allow(agent).to receive(:gets).and_return("Hello", "World", "exit")
      allow(agent).to receive(:puts)
      allow(agent).to receive(:chat).with("Hello", conversation: conversation, log_start: true).and_return("Response1")
      allow(agent).to receive(:chat).with("World", conversation: conversation, log_start: false).and_return("Response2")

      agent.interactive
    end
  end
end
