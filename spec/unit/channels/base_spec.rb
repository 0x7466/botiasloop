# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

RSpec.describe Botiasloop::Channels::Base do
  let(:temp_dir) { Dir.mktmpdir("botiasloop_test") }
  let(:config) do
    Botiasloop::Config.new({
      test_channel: {
        token: "test-token",
        allowed_users: ["testuser"]
      }
    })
  end

  # Create a concrete test channel class that implements required methods
  let(:test_channel_class) do
    Class.new(described_class) do
      channel_name :test_channel
      requires_config :token

      attr_reader :started, :stopped, :processed_messages

      # Override to access config from the hash directly
      def channel_config
        @config.instance_variable_get(:@config)[:test_channel] || {}
      end

      def initialize(config)
        super
        @started = false
        @stopped = false
        @processed_messages = []
        @running = false
      end

      def start
        @started = true
        @running = true
      end

      def stop
        @stopped = true
        @running = false
      end

      def running?
        @running
      end

      def process_message(source_id, content, metadata = {})
        @processed_messages << {source_id: source_id, content: content, metadata: metadata}
      end
    end
  end

  before do
    allow(Dir).to receive(:home).and_return(temp_dir)
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with("~/.config/botiasloop").and_return(temp_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".channel_name" do
    it "sets the channel identifier" do
      expect(test_channel_class.channel_identifier).to eq(:test_channel)
    end

    it "can be retrieved via class method" do
      channel = test_channel_class.new(config)
      expect(channel.class.channel_identifier).to eq(:test_channel)
    end
  end

  describe ".requires_config" do
    it "stores required configuration keys" do
      expect(test_channel_class.required_config_keys).to contain_exactly(:token)
    end

    it "raises error if required config is missing" do
      incomplete_config = Botiasloop::Config.new({test_channel: {}})
      expect { test_channel_class.new(incomplete_config) }.to raise_error(Botiasloop::Error, /token/)
    end

    it "accepts config with all required keys" do
      expect { test_channel_class.new(config) }.not_to raise_error
    end
  end

  describe "#initialize" do
    let(:channel) { test_channel_class.new(config) }

    it "sets the config" do
      expect(channel.instance_variable_get(:@config)).to eq(config)
    end

    it "initializes empty conversations hash" do
      conversations = channel.instance_variable_get(:@conversations)
      expect(conversations).to eq({})
    end

    it "creates a logger" do
      logger = channel.instance_variable_get(:@logger)
      expect(logger).to be_a(Logger)
    end

    it "provides channel-specific config via method" do
      expect(channel.channel_config).to eq({token: "test-token", allowed_users: ["testuser"]})
    end
  end

  describe "abstract methods enforcement" do
    let(:incomplete_class) do
      Class.new(described_class) do
        channel_name :incomplete
      end
    end

    it "raises NotImplementedError for start if not implemented" do
      channel = incomplete_class.new(config)
      expect { channel.start }.to raise_error(NotImplementedError, /start/)
    end

    it "raises NotImplementedError for stop if not implemented" do
      channel = incomplete_class.new(config)
      expect { channel.stop }.to raise_error(NotImplementedError, /stop/)
    end

    it "raises NotImplementedError for running? if not implemented" do
      channel = incomplete_class.new(config)
      expect { channel.running? }.to raise_error(NotImplementedError, /running/)
    end

    it "raises NotImplementedError for process_message if not implemented" do
      channel = incomplete_class.new(config)
      expect { channel.process_message("id", "content") }.to raise_error(NotImplementedError, /process_message/)
    end
  end

  describe "#conversation_for" do
    let(:channel) { test_channel_class.new(config) }
    let(:chats_file) { File.join(temp_dir, "channels", "test_channel_chats.json") }

    before do
      FileUtils.mkdir_p(File.dirname(chats_file))
    end

    context "when source does not exist" do
      it "creates a new conversation" do
        conversation = channel.conversation_for("user123")
        expect(conversation).to be_a(Botiasloop::Conversation)
      end

      it "stores the mapping" do
        conversation = channel.conversation_for("user123")
        conversations = channel.instance_variable_get(:@conversations)
        expect(conversations["user123"]).to eq(conversation.uuid)
      end

      it "saves to persistent storage" do
        channel.conversation_for("user123")
        expect(File.exist?(chats_file)).to be true

        saved_data = JSON.parse(File.read(chats_file), symbolize_names: true)
        expect(saved_data[:conversations]).to have_key(:user123)
      end
    end

    context "when source already exists" do
      before do
        File.write(chats_file, JSON.dump({
          conversations: {
            "user123" => "existing-uuid"
          }
        }))
        # Reload conversations from file
        channel.instance_variable_set(:@conversations, channel.send(:load_conversations))
      end

      it "returns existing conversation" do
        existing_conversation = instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
        expect(Botiasloop::Conversation).to receive(:new).with("existing-uuid").and_return(existing_conversation)

        result = channel.conversation_for("user123")
        expect(result.uuid).to eq("existing-uuid")
      end

      it "does not create a new conversation" do
        allow(Botiasloop::Conversation).to receive(:new).with("existing-uuid").and_return(
          instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
        )
        expect(Botiasloop::Conversation).not_to receive(:new).with(no_args)

        channel.conversation_for("user123")
      end
    end
  end

  describe "#authorized?" do
    let(:channel) { test_channel_class.new(config) }

    it "returns false by default (secure default)" do
      # Test the base implementation - it always returns false
      expect(channel.authorized?("user1")).to be false
    end

    context "when channel overrides authorized?" do
      let(:auth_channel_class) do
        Class.new(test_channel_class) do
          def authorized?(source_id)
            cfg = channel_config
            allowed_users = cfg[:allowed_users] || []
            return false if source_id.nil? || allowed_users.empty?
            allowed_users.include?(source_id)
          end
        end
      end

      let(:auth_channel) { auth_channel_class.new(config) }

      it "returns true for authorized users" do
        expect(auth_channel.authorized?("testuser")).to be true
      end

      it "returns false for unauthorized users" do
        expect(auth_channel.authorized?("hacker")).to be false
      end

      it "returns false for nil source_id" do
        expect(auth_channel.authorized?(nil)).to be false
      end

      context "when allowed_users is empty" do
        let(:empty_config) do
          Botiasloop::Config.new({
            test_channel: {
              token: "test-token",
              allowed_users: []
            }
          })
        end

        let(:empty_channel) { auth_channel_class.new(empty_config) }

        it "returns false for all users" do
          expect(empty_channel.authorized?("anyuser")).to be false
        end
      end
    end
  end

  describe "#format_response" do
    let(:channel) { test_channel_class.new(config) }

    it "returns content as-is by default" do
      expect(channel.format_response("Hello **world**")).to eq("Hello **world**")
    end

    context "when overridden" do
      let(:formatted_channel_class) do
        Class.new(test_channel_class) do
          def format_response(content)
            content.upcase
          end
        end
      end

      let(:formatted_channel) { formatted_channel_class.new(config) }

      it "uses custom formatting" do
        expect(formatted_channel.format_response("hello")).to eq("HELLO")
      end
    end
  end

  describe "#send_response" do
    let(:channel) { test_channel_class.new(config) }

    it "formats response before sending" do
      allow(channel).to receive(:format_response).with("Hello").and_return("HELLO")
      allow(channel).to receive(:deliver_response)

      channel.send_response("user123", "Hello")
      expect(channel).to have_received(:format_response).with("Hello")
    end

    it "calls deliver_response with formatted content" do
      allow(channel).to receive(:format_response).and_return("FORMATTED")
      allow(channel).to receive(:deliver_response)

      channel.send_response("user123", "Hello")
      expect(channel).to have_received(:deliver_response).with("user123", "FORMATTED")
    end
  end

  describe "#deliver_response" do
    it "raises NotImplementedError (subclasses must implement)" do
      channel = test_channel_class.new(config)
      expect { channel.deliver_response("id", "content") }.to raise_error(NotImplementedError, /deliver_response/)
    end
  end

  describe "persistence methods" do
    let(:channel) { test_channel_class.new(config) }
    let(:chats_file) { File.join(temp_dir, "channels", "test_channel_chats.json") }

    before do
      FileUtils.mkdir_p(File.dirname(chats_file))
    end

    describe "#save_conversations" do
      it "saves conversations to JSON file" do
        channel.instance_variable_set(:@conversations, {"user1" => "uuid1", "user2" => "uuid2"})
        channel.send(:save_conversations)

        saved = JSON.parse(File.read(chats_file), symbolize_names: true)
        expect(saved[:conversations]).to eq({user1: "uuid1", user2: "uuid2"})
      end

      it "creates directory if needed" do
        FileUtils.rm_rf(File.dirname(chats_file))
        channel.instance_variable_set(:@conversations, {"user1" => "uuid1"})
        channel.send(:save_conversations)

        expect(File.directory?(File.dirname(chats_file))).to be true
      end
    end

    describe "#load_conversations" do
      it "returns empty hash if file does not exist" do
        result = channel.send(:load_conversations)
        expect(result).to eq({})
      end

      it "returns empty hash on JSON parse error" do
        File.write(chats_file, "invalid json")
        result = channel.send(:load_conversations)
        expect(result).to eq({})
      end

      it "loads conversations from file" do
        File.write(chats_file, JSON.dump({conversations: {"user1" => "uuid1"}}))
        result = channel.send(:load_conversations)
        expect(result).to eq({"user1" => "uuid1"})
      end
    end

    describe "#chats_file_path" do
      it "returns path based on channel identifier" do
        path = channel.send(:chats_file_path)
        expect(path).to eq(chats_file)
      end
    end
  end

  describe "class-level configuration" do
    it "allows getting channel_name from class" do
      expect(test_channel_class.channel_identifier).to eq(:test_channel)
    end

    it "allows getting required_config_keys from class" do
      expect(test_channel_class.required_config_keys).to contain_exactly(:token)
    end
  end
end
