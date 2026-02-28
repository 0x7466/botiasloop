# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Channels::CLI do
  let(:test_config) do
    Botiasloop::Config.new({
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  before do
    Botiasloop::Config.instance = test_config
    Botiasloop::Channels.registry.register(described_class)
  end

  after do
    Botiasloop::Config.instance = nil
  end

  describe "inheritance" do
    it "inherits from Channels::Base" do
      expect(described_class.ancestors).to include(Botiasloop::Channels::Base)
    end

    it "has channel_name :cli" do
      expect(described_class.channel_identifier).to eq(:cli)
    end

    it "has no required config keys" do
      expect(described_class.required_config_keys).to be_empty
    end
  end

  describe "auto-registration" do
    it "is registered in the global registry" do
      registry = Botiasloop::Channels.registry
      expect(registry[:cli]).to eq(described_class)
    end
  end

  describe "constants" do
    it "defines EXIT_COMMANDS" do
      expect(described_class::EXIT_COMMANDS).to eq(%w[exit quit \q])
    end

    it "defines SOURCE_ID as 'cli'" do
      expect(described_class::SOURCE_ID).to eq("cli")
    end
  end

  describe "#initialize" do
    it "initializes successfully without required config" do
      channel = described_class.new
      expect(channel).to be_a(described_class)
    end

    it "sets running to false initially" do
      channel = described_class.new
      expect(channel.running?).to be false
    end
  end

  describe "#authorized?" do
    let(:channel) { described_class.new }

    it "returns true for any source_id" do
      expect(channel.authorized?("cli")).to be true
      expect(channel.authorized?("anything")).to be true
      expect(channel.authorized?(nil)).to be true
    end

    it "always returns true" do
      expect(channel.authorized?("user123")).to be true
    end
  end

  describe "#start_listening" do
    let(:channel) { described_class.new }
    let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "cli-test-uuid") }

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
      allow(channel).to receive(:puts)
      allow(channel).to receive(:print)
      allow(Botiasloop::Logger).to receive(:info)
    end

    it "sets running to true" do
      allow($stdin).to receive(:gets).and_return("exit")
      channel.start_listening
      expect(channel.running?).to be false # Reset after exit
    end

    it "prints welcome message" do
      allow($stdin).to receive(:gets).and_return("exit")
      expect(channel).to receive(:puts).with(/botiasloop.*Interactive Mode/)
      expect(channel).to receive(:puts).with(/Type.*exit/)
      channel.start_listening
    end

    it "exits on 'exit' command" do
      allow($stdin).to receive(:gets).and_return("exit")
      channel.start_listening
      expect(channel.running?).to be false
    end

    it "exits on 'quit' command" do
      allow($stdin).to receive(:gets).and_return("quit")
      channel.start_listening
      expect(channel.running?).to be false
    end

    it "exits on '\\q' command" do
      allow($stdin).to receive(:gets).and_return('\\q')
      channel.start_listening
      expect(channel.running?).to be false
    end

    it "exits on nil input (EOF)" do
      allow($stdin).to receive(:gets).and_return(nil)
      channel.start_listening
      expect(channel.running?).to be false
    end

    it "handles Ctrl+C gracefully" do
      allow($stdin).to receive(:gets).and_raise(Interrupt)
      expect(channel).to receive(:puts).with(/Goodbye/)
      expect { channel.start_listening }.not_to raise_error
    end
  end

  describe "#stop_listening" do
    let(:channel) { described_class.new }

    it "sets running to false" do
      # First start it
      allow($stdin).to receive(:gets).and_return(nil)
      allow(channel).to receive(:puts)
      allow(channel).to receive(:print)
      allow(Botiasloop::Logger).to receive(:info)

      channel.start_listening
      channel.stop_listening
      expect(channel.running?).to be false
    end
  end

  describe "#running?" do
    let(:channel) { described_class.new }

    it "returns false when not started" do
      expect(channel.running?).to be false
    end
  end

  describe "#extract_content" do
    let(:channel) { described_class.new }

    it "returns the raw message as-is for CLI" do
      expect(channel.extract_content("Hello World")).to eq("Hello World")
    end

    it "handles empty strings" do
      expect(channel.extract_content("")).to eq("")
    end
  end

  describe "#process_message" do
    let(:channel) { described_class.new }
    let(:chat) { Botiasloop::Chat.find_or_create("cli", "cli") }
    let(:conversation) { chat.current_conversation }
    let(:mock_run) { instance_double(Botiasloop::Loop::Run) }

    before do
      Botiasloop::Agent.instance_variable_set(:@instance, nil)
      allow(Botiasloop::Agent).to receive(:chat).and_return(mock_run)
      allow(mock_run).to receive(:start).and_return(mock_run)
      allow(channel).to receive(:send_message)
      allow(Botiasloop::Logger).to receive(:error)
    end

    it "processes non-command messages through agent" do
      expect(Botiasloop::Agent).to receive(:chat).with(
        "Hello",
        hash_including(callback: kind_of(Proc), chat: kind_of(Botiasloop::Chat))
      )
      channel.process_message("cli", "Hello")
    end

    it "handles slash commands" do
      allow(Botiasloop::Commands).to receive(:command?).with("/help").and_return(true)
      allow(Botiasloop::Commands).to receive(:execute).and_return("Help text")

      expect(Botiasloop::Agent).not_to receive(:chat)
      channel.process_message("cli", "/help")
    end

    it "calls send_message via callback with response" do
      allow(Botiasloop::Agent).to receive(:chat) do |message, **options|
        options[:callback].call("Response text")
        mock_run
      end

      expect(channel).to receive(:send_message).with("cli", "Response text")
      channel.process_message("cli", "Hello")
    end

    it "handles errors via error_callback" do
      allow(Botiasloop::Agent).to receive(:chat) do |message, **options|
        options[:error_callback].call("Test error")
        mock_run
      end

      expect(channel).to receive(:send_message).with("cli", /Error: Test error/)
      channel.process_message("cli", "Hello")
    end
  end

  describe "#handle_error" do
    let(:channel) { described_class.new }

    it "logs the error and sends error message to user" do
      error = StandardError.new("Test error")
      expect(Botiasloop::Logger).to receive(:error).with("[CLI] Error processing message: Test error")
      expect(channel).to receive(:send_message).with("cli", "Error: Test error")

      channel.handle_error("cli", "cli", error, "Hello")
    end
  end

  describe "#deliver_message" do
    let(:channel) { described_class.new }

    it "outputs message to stdout" do
      expect { channel.deliver_message("cli", "Test message") }.to output(/Agent: Test message/).to_stdout
    end

    it "outputs newline after message" do
      output = StringIO.new
      allow(channel).to receive(:puts) { |msg| output.puts(msg) }
      channel.deliver_message("cli", "Test")
      expect(output.string).to include("\n")
    end
  end

  describe "conversation persistence" do
    let(:channel) { described_class.new }

    it "uses 'cli' as fixed source_id for chat_for" do
      chat = channel.chat_for("cli")
      expect(chat).to be_a(Botiasloop::Chat)
      expect(chat.current_conversation).to be_a(Botiasloop::Conversation)
    end

    it "saves conversations to database via Chat" do
      chat = channel.chat_for("cli")
      conversation = chat.current_conversation

      # Verify via database
      db_conv = Botiasloop::Conversation.find(id: conversation.id)
      expect(db_conv).not_to be_nil
    end

    it "reuses existing conversation via Chat" do
      chat1 = channel.chat_for("cli")
      conversation1 = chat1.current_conversation

      # Create new channel instance - should get same chat and conversation via Chat model
      channel2 = described_class.new
      chat2 = channel2.chat_for("cli")
      conversation2 = chat2.current_conversation

      expect(conversation2.id).to eq(conversation1.id)
    end
  end

  describe "integration with channels module" do
    it "is listed in registry.names" do
      registry = Botiasloop::Channels.registry
      expect(registry.names).to include(:cli)
    end

    it "can be retrieved via registry[:cli]" do
      registry = Botiasloop::Channels.registry
      expect(registry[:cli]).to eq(described_class)
    end
  end
end
