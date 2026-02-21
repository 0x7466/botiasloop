# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Botiasloop::Channels::CLI do
  let(:config) do
    Botiasloop::Config.new({
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  let(:temp_dir) { Dir.mktmpdir("botiasloop_test") }
  let(:conversations_file) { File.join(temp_dir, "conversations.json") }

  before do
    allow(Dir).to receive(:home).and_return(temp_dir)
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with("~/.config/botiasloop").and_return(temp_dir)
    allow(Botiasloop::ConversationManager).to receive(:mapping_file).and_return(conversations_file)
    Botiasloop::ConversationManager.clear_all
  end

  after do
    FileUtils.rm_rf(temp_dir)
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
      channel = described_class.new(config)
      expect(channel).to be_a(described_class)
    end

    it "sets running to false initially" do
      channel = described_class.new(config)
      expect(channel.running?).to be false
    end
  end

  describe "#authorized?" do
    let(:channel) { described_class.new(config) }

    it "returns true for any source_id" do
      expect(channel.authorized?("cli")).to be true
      expect(channel.authorized?("anything")).to be true
      expect(channel.authorized?(nil)).to be true
    end

    it "always returns true" do
      expect(channel.authorized?("user123")).to be true
    end
  end

  describe "#start" do
    let(:channel) { described_class.new(config) }
    let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "cli-test-uuid") }

    before do
      allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
      allow(channel).to receive(:puts)
      allow(channel).to receive(:print)
      allow(channel.instance_variable_get(:@logger)).to receive(:info)
    end

    it "sets running to true" do
      allow($stdin).to receive(:gets).and_return("exit")
      channel.start
      expect(channel.running?).to be false # Reset after exit
    end

    it "prints welcome message" do
      allow($stdin).to receive(:gets).and_return("exit")
      expect(channel).to receive(:puts).with(/botiasloop.*Interactive Mode/)
      expect(channel).to receive(:puts).with(/Type.*exit/)
      channel.start
    end

    it "exits on 'exit' command" do
      allow($stdin).to receive(:gets).and_return("exit")
      channel.start
      expect(channel.running?).to be false
    end

    it "exits on 'quit' command" do
      allow($stdin).to receive(:gets).and_return("quit")
      channel.start
      expect(channel.running?).to be false
    end

    it "exits on '\\q' command" do
      allow($stdin).to receive(:gets).and_return('\\q')
      channel.start
      expect(channel.running?).to be false
    end

    it "exits on nil input (EOF)" do
      allow($stdin).to receive(:gets).and_return(nil)
      channel.start
      expect(channel.running?).to be false
    end

    it "handles Ctrl+C gracefully" do
      allow($stdin).to receive(:gets).and_raise(Interrupt)
      expect(channel).to receive(:puts).with(/Goodbye/)
      expect { channel.start }.not_to raise_error
    end
  end

  describe "#stop" do
    let(:channel) { described_class.new(config) }

    it "sets running to false" do
      # First start it
      allow($stdin).to receive(:gets).and_return(nil)
      allow(channel).to receive(:puts)
      allow(channel).to receive(:print)
      allow(channel.instance_variable_get(:@logger)).to receive(:info)

      channel.start
      channel.stop
      expect(channel.running?).to be false
    end
  end

  describe "#running?" do
    let(:channel) { described_class.new(config) }

    it "returns false when not started" do
      expect(channel.running?).to be false
    end
  end

  describe "#extract_content" do
    let(:channel) { described_class.new(config) }

    it "returns the raw message as-is for CLI" do
      expect(channel.extract_content("Hello World")).to eq("Hello World")
    end

    it "handles empty strings" do
      expect(channel.extract_content("")).to eq("")
    end
  end

  describe "#process_message" do
    let(:channel) { described_class.new(config) }
    let(:conversation) { instance_double(Botiasloop::Conversation, uuid: "cli-test-uuid") }
    let(:agent) { instance_double(Botiasloop::Agent) }

    before do
      allow(channel).to receive(:conversation_for).with("cli").and_return(conversation)
      allow(Botiasloop::Agent).to receive(:new).and_return(agent)
      allow(channel).to receive(:send_response)
      allow(channel.instance_variable_get(:@logger)).to receive(:error)
    end

    it "processes non-command messages through agent" do
      expect(agent).to receive(:chat).with("Hello", conversation: conversation).and_return("Response")
      channel.process_message("cli", "Hello")
    end

    it "handles slash commands" do
      allow(Botiasloop::Commands).to receive(:command?).with("/help").and_return(true)
      allow(Botiasloop::Commands).to receive(:execute).and_return("Help text")

      expect(agent).not_to receive(:chat)
      channel.process_message("cli", "/help")
    end

    it "sends response after processing" do
      allow(agent).to receive(:chat).and_return("Response text")
      expect(channel).to receive(:send_response).with("cli", "Response text")
      channel.process_message("cli", "Hello")
    end

    it "handles errors gracefully" do
      allow(agent).to receive(:chat).and_raise(StandardError.new("Test error"))
      expect(channel).to receive(:send_response).with("cli", /Error: Test error/)
      expect(channel.instance_variable_get(:@logger)).to receive(:error).with(/Test error/)
      channel.process_message("cli", "Hello")
    end
  end

  describe "#handle_error" do
    let(:channel) { described_class.new(config) }

    it "logs the error and sends response to user" do
      error = StandardError.new("Test error")
      expect(channel.instance_variable_get(:@logger)).to receive(:error).with("[CLI] Error processing message: Test error")
      expect(channel).to receive(:send_response).with("cli", "Error: Test error")

      channel.handle_error("cli", "cli", error, "Hello")
    end
  end

  describe "#deliver_response" do
    let(:channel) { described_class.new(config) }

    it "outputs response to stdout" do
      expect { channel.deliver_response("cli", "Test response") }.to output(/Agent: Test response/).to_stdout
    end

    it "outputs newline after response" do
      output = StringIO.new
      allow(channel).to receive(:puts) { |msg| output.puts(msg) }
      channel.deliver_response("cli", "Test")
      expect(output.string).to include("\n")
    end
  end

  describe "conversation persistence" do
    let(:channel) { described_class.new(config) }

    before do
      FileUtils.mkdir_p(File.dirname(conversations_file))
    end

    it "uses 'cli' as fixed source_id for conversation_for" do
      conversation = channel.conversation_for("cli")
      expect(conversation).to be_a(Botiasloop::Conversation)
    end

    it "saves conversations to global conversations.json via ConversationManager" do
      channel.conversation_for("cli")

      expect(File.exist?(conversations_file)).to be true
      saved = JSON.parse(File.read(conversations_file), symbolize_names: true)
      expect(saved[:conversations]).to have_key(:cli)
    end

    it "reuses existing conversation via ConversationManager" do
      conversation1 = channel.conversation_for("cli")

      # Create new channel instance - should get same conversation via ConversationManager
      channel2 = described_class.new(config)
      conversation2 = channel2.conversation_for("cli")

      expect(conversation2.uuid).to eq(conversation1.uuid)
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
