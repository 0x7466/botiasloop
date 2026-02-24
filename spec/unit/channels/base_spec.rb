# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Channels::Base do
  let(:test_config) do
    Botiasloop::Config.new({
      "channels" => {
        "test_channel" => {
          "token" => "test-token",
          "allowed_users" => ["testuser"]
        }
      },
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  before do
    Botiasloop::Config.instance = test_config
  end

  after do
    Botiasloop::Config.instance = nil
  end

  # Create a concrete test channel class that implements required methods
  let(:test_channel_class) do
    Class.new(described_class) do
      channel_name :test_channel
      requires_config :token

      attr_reader :started, :stopped, :processed_messages

      def initialize
        super
        @started = false
        @stopped = false
        @processed_messages = []
        @running = false
      end

      def start_listening
        @started = true
        @running = true
      end

      def stop_listening
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

  describe ".channel_name" do
    it "sets the channel identifier" do
      expect(test_channel_class.channel_identifier).to eq(:test_channel)
    end

    it "can be retrieved via class method" do
      channel = test_channel_class.new
      expect(channel.class.channel_identifier).to eq(:test_channel)
    end
  end

  describe ".requires_config" do
    it "stores required configuration keys" do
      expect(test_channel_class.required_config_keys).to contain_exactly(:token)
    end

    it "raises error if required config is missing" do
      incomplete_config = Botiasloop::Config.new({
        "channels" => {"test_channel" => {}},
        "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
      })
      Botiasloop::Config.instance = incomplete_config
      expect { test_channel_class.new }.to raise_error(Botiasloop::Error, /token/)
    end

    it "accepts config with all required keys" do
      expect { test_channel_class.new }.not_to raise_error
    end
  end

  describe "#initialize" do
    let(:channel) { test_channel_class.new }

    it "provides channel-specific config via method" do
      expect(channel.channel_config).to eq({"token" => "test-token", "allowed_users" => ["testuser"]})
    end
  end

  describe "abstract methods enforcement" do
    let(:incomplete_class) do
      Class.new(described_class) do
        channel_name :incomplete
      end
    end

    it "raises NotImplementedError for start_listening if not implemented" do
      channel = incomplete_class.new
      expect { channel.start_listening }.to raise_error(NotImplementedError, /start_listening/)
    end

    it "raises NotImplementedError for stop_listening if not implemented" do
      channel = incomplete_class.new
      expect { channel.stop_listening }.to raise_error(NotImplementedError, /stop_listening/)
    end

    it "raises NotImplementedError for running? if not implemented" do
      channel = incomplete_class.new
      expect { channel.running? }.to raise_error(NotImplementedError, /running/)
    end

    it "raises NotImplementedError for extract_content if not implemented" do
      channel = incomplete_class.new
      expect { channel.process_message("id", "content") }.to raise_error(NotImplementedError, /extract_content/)
    end
  end

  describe "#chat_for" do
    let(:channel) { test_channel_class.new }

    context "when source does not exist" do
      it "creates a new chat" do
        chat = channel.chat_for("user123")
        expect(chat).to be_a(Botiasloop::Chat)
        expect(chat.channel).to eq("test_channel")
        expect(chat.external_id).to eq("user123")
      end

      it "returns a chat with a current conversation" do
        chat = channel.chat_for("user123")
        expect(chat.current_conversation).to be_a(Botiasloop::Conversation)
      end

      it "saves to persistent storage via database" do
        chat = channel.chat_for("user123")
        conversation = chat.current_conversation

        # Verify via database
        db_conv = Botiasloop::Conversation.find(id: conversation.id)
        expect(db_conv).not_to be_nil
        expect(db_conv.id).to eq(conversation.id)
      end
    end

    context "when source already exists" do
      before do
        @chat = Botiasloop::Chat.create(channel: "test_channel", external_id: "user123")
        @conversation = Botiasloop::Conversation.create
        @chat.update(current_conversation_id: @conversation.id)
      end

      it "returns existing chat" do
        chat = channel.chat_for("user123")
        expect(chat.id).to eq(@chat.id)
      end

      it "returns the same conversation" do
        chat = channel.chat_for("user123")
        expect(chat.current_conversation.id).to eq(@conversation.id)
      end
    end
  end

  describe "#process_message with commands" do
    let(:process_test_channel_class) do
      Class.new(described_class) do
        channel_name :process_test_channel

        attr_reader :delivered_responses

        def initialize
          super
          @delivered_responses = []
        end

        def start_listening
        end

        def stop_listening
        end

        def running?
          false
        end

        def extract_content(raw_message)
          raw_message
        end

        def authorized?(_source_id)
          true
        end

        def deliver_message(source_id, formatted_content)
          @delivered_responses << {source_id: source_id, content: formatted_content}
        end
      end
    end
    let(:channel) { process_test_channel_class.new }

    before do
      allow(Botiasloop::Agent).to receive(:chat).and_return("Agent response")
    end

    it "updates chat when /new command changes conversation" do
      # First, establish an initial chat and conversation
      chat = channel.chat_for("user123")
      initial_conversation = chat.current_conversation
      initial_uuid = initial_conversation.uuid

      # Now execute the /new command that will switch conversations
      channel.process_message("user123", "/new")

      # Verify the conversation was switched in the chat
      chat.reload
      expect(chat.current_conversation_id).not_to eq(initial_uuid)
      expect(chat.current_conversation).to be_a(Botiasloop::Conversation)
    end
  end

  describe "#authorized?" do
    let(:channel) { test_channel_class.new }

    it "returns false by default (secure default)" do
      # Test the base implementation - it always returns false
      expect(channel.authorized?("user1")).to be false
    end

    context "when channel overrides authorized?" do
      let(:auth_channel_class) do
        Class.new(test_channel_class) do
          channel_name :test_channel

          def authorized?(source_id)
            cfg = channel_config
            allowed_users = cfg["allowed_users"] || []
            return false if source_id.nil? || allowed_users.empty?

            allowed_users.include?(source_id)
          end
        end
      end

      let(:auth_channel) { auth_channel_class.new }

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
        let(:empty_channel) do
          empty_config = Botiasloop::Config.new({
            "channels" => {
              "test_channel" => {
                "token" => "test-token",
                "allowed_users" => []
              }
            },
            "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
          })
          Botiasloop::Config.instance = empty_config
          auth_channel_class.new
        end

        before do
          Botiasloop::Config.instance = test_config
        end

        it "returns false for all users" do
          expect(empty_channel.authorized?("anyuser")).to be false
        end
      end
    end
  end

  describe "#format_message" do
    let(:channel) { test_channel_class.new }

    it "returns content as-is by default" do
      expect(channel.format_message("Hello **world**")).to eq("Hello **world**")
    end

    context "when overridden" do
      let(:formatted_channel_class) do
        Class.new(test_channel_class) do
          def format_message(content)
            content.upcase
          end
        end
      end

      let(:formatted_channel) { formatted_channel_class.new }

      it "uses custom formatting" do
        expect(formatted_channel.format_message("hello")).to eq("HELLO")
      end
    end
  end

  describe "#send_message" do
    let(:channel) { test_channel_class.new }

    it "formats message before sending" do
      allow(channel).to receive(:format_message).with("Hello").and_return("HELLO")
      allow(channel).to receive(:deliver_message)

      channel.send_message("user123", "Hello")
      expect(channel).to have_received(:format_message).with("Hello")
    end

    it "calls deliver_message with formatted content" do
      allow(channel).to receive(:format_message).and_return("FORMATTED")
      allow(channel).to receive(:deliver_message)

      channel.send_message("user123", "Hello")
      expect(channel).to have_received(:deliver_message).with("user123", "FORMATTED")
    end
  end

  describe "#deliver_message" do
    it "raises NotImplementedError (subclasses must implement)" do
      channel = test_channel_class.new
      expect { channel.deliver_message("id", "content") }.to raise_error(NotImplementedError, /deliver_message/)
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
