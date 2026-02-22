# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Channels::Base do
  let(:config) do
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

  # Create a concrete test channel class that implements required methods
  let(:test_channel_class) do
    Class.new(described_class) do
      channel_name :test_channel
      requires_config :token

      attr_reader :started, :stopped, :processed_messages

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
    # Clear database state before each test
    Botiasloop::ConversationManager.clear_all
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
      incomplete_config = Botiasloop::Config.new({
        "channels" => {"test_channel" => {}},
        "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
      })
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

    it "creates a logger" do
      logger = channel.instance_variable_get(:@logger)
      expect(logger).to be_a(Logger)
    end

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

    it "raises NotImplementedError for extract_content if not implemented" do
      channel = incomplete_class.new(config)
      expect { channel.process_message("id", "content") }.to raise_error(NotImplementedError, /extract_content/)
    end
  end

  describe "#conversation_for" do
    let(:channel) { test_channel_class.new(config) }

    context "when source does not exist" do
      it "creates a new conversation" do
        conversation = channel.conversation_for("user123")
        expect(conversation).to be_a(Botiasloop::Conversation)
      end

      it "stores the mapping in ConversationManager" do
        conversation = channel.conversation_for("user123")
        uuid = Botiasloop::ConversationManager.current_uuid_for("user123")
        expect(uuid).to eq(conversation.uuid)
      end

      it "saves to persistent storage via ConversationManager" do
        conversation = channel.conversation_for("user123")

        # Verify via database
        db_conv = Botiasloop::Conversation.find(id: conversation.uuid)
        expect(db_conv).not_to be_nil
        expect(db_conv.user_id).to eq("user123")
      end
    end

    context "when source already exists" do
      before do
        Botiasloop::Conversation.create(id: "existing-uuid", user_id: "user123", is_current: true)
      end

      it "returns existing conversation" do
        result = channel.conversation_for("user123")
        expect(result.uuid).to eq("existing-uuid")
      end

      it "does not create a new conversation" do
        expect(Botiasloop::Conversation).not_to receive(:create)
        channel.conversation_for("user123")
      end
    end
  end

  describe "#process_message with commands" do
    let(:process_test_channel_class) do
      Class.new(described_class) do
        channel_name :process_test_channel

        attr_reader :delivered_responses

        def initialize(config)
          super
          @delivered_responses = []
        end

        def start
        end

        def stop
        end

        def running?
          false
        end

        def extract_content(raw_message)
          raw_message
        end

        def authorized?(source_id)
          true
        end

        def deliver_response(source_id, formatted_content)
          @delivered_responses << {source_id: source_id, content: formatted_content}
        end
      end
    end
    let(:channel) { process_test_channel_class.new(config) }
    let(:mock_agent) { instance_double(Botiasloop::Agent) }

    before do
      allow(Botiasloop::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:chat).and_return("Agent response")
    end

    it "updates ConversationManager when /new command changes conversation" do
      # First, establish an initial conversation
      initial_conversation = channel.conversation_for("user123")
      initial_uuid = initial_conversation.uuid

      # Now execute the /new command that will switch conversations
      channel.process_message("user123", "/new")

      # Verify the conversation was switched in ConversationManager
      current_uuid = Botiasloop::ConversationManager.current_uuid_for("user123")
      expect(current_uuid).not_to eq(initial_uuid)
      expect(current_uuid).to be_a(String)
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
          channel_name :test_channel

          def authorized?(source_id)
            cfg = channel_config
            allowed_users = cfg["allowed_users"] || []
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
            "channels" => {
              "test_channel" => {
                "token" => "test-token",
                "allowed_users" => []
              }
            },
            "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
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

  describe "class-level configuration" do
    it "allows getting channel_name from class" do
      expect(test_channel_class.channel_identifier).to eq(:test_channel)
    end

    it "allows getting required_config_keys from class" do
      expect(test_channel_class.required_config_keys).to contain_exactly(:token)
    end
  end
end
