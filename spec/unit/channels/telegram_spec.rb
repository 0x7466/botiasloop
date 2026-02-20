# frozen_string_literal: true

require "spec_helper"
require "json"
require "tempfile"
require "fileutils"

RSpec.describe Botiasloop::Channels::Telegram do
  let(:config) do
    Botiasloop::Config.new({
      telegram: {
        bot_token: "test-token-123",
        allowed_users: ["testuser"]
      }
    })
  end

  let(:temp_dir) { Dir.mktmpdir("botiasloop_test") }
  let(:chats_file) { File.join(temp_dir, "telegram_chats.json") }

  let(:mock_bot) { double("bot") }
  let(:mock_api) { double("api") }

  before do
    allow(Dir).to receive(:home).and_return(temp_dir)
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with("~/.config/botiasloop").and_return(temp_dir)
    allow(File).to receive(:expand_path).with("~/.config/botiasloop/telegram_chats.json").and_return(chats_file)

    # Set the chats file path for testing
    Botiasloop::Channels::Telegram.chats_file = chats_file

    # Mock Telegram::Bot::Client
    stub_const("Telegram::Bot::Client", double)
    stub_const("Telegram::Bot::Types::Message", Class.new)
    allow(Telegram::Bot::Client).to receive(:new).with("test-token-123").and_return(mock_bot)
    allow(mock_bot).to receive(:api).and_return(mock_api)
    allow(mock_bot).to receive(:run).and_yield(mock_bot)
    allow(mock_bot).to receive(:listen)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    context "when bot_token is configured" do
      it "initializes successfully" do
        channel = described_class.new(config)
        expect(channel).to be_a(described_class)
      end
    end

    context "when bot_token is not configured" do
      let(:config) do
        Botiasloop::Config.new({
          telegram: {
            allowed_users: ["testuser"]
          }
        })
      end

      it "raises an error" do
        expect { described_class.new(config) }.to raise_error(Botiasloop::Error, /bot_token/)
      end
    end
  end

  describe "#start" do
    let(:channel) { described_class.new(config) }
    let(:logger) { instance_double(Logger) }

    before do
      allow(Logger).to receive(:new).and_return(logger)
      allow(logger).to receive(:info)
      allow(logger).to receive(:warn)
      allow(logger).to receive(:error)
    end

    context "when allowed_users is empty" do
      let(:config) do
        Botiasloop::Config.new({
          telegram: {
            bot_token: "test-token-123",
            allowed_users: []
          }
        })
      end

      it "logs a warning about no allowed users" do
        expect(logger).to receive(:warn).with(/allowed_users/)
        channel.start
      end
    end

    context "when allowed_users is configured" do
      it "starts polling for messages" do
        expect(mock_bot).to receive(:listen).and_yield(nil)
        channel.start
      end
    end
  end

  describe "#process_message" do
    let(:channel) { described_class.new(config) }
    let(:mock_agent) { instance_double(Botiasloop::Agent) }
    let(:mock_conversation) { instance_double(Botiasloop::Conversation) }

    before do
      allow(Botiasloop::Agent).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:chat).and_return("Test response")
      allow(mock_api).to receive(:send_message)
      channel.instance_variable_set(:@bot, mock_bot)
    end

    context "when user is not in allowed list" do
      let(:message) do
        double(
          "message",
          chat: double("chat", id: 123456),
          from: double("from", username: "unauthorized_user"),
          text: "Hello"
        )
      end

      it "silently ignores the message" do
        expect(mock_agent).not_to receive(:chat)
        expect(mock_api).not_to receive(:send_message)
        channel.process_message(message)
      end
    end

    context "when user is in allowed list" do
      let(:message) do
        double(
          "message",
          chat: double("chat", id: 123456),
          from: double("from", username: "testuser"),
          text: "Hello bot"
        )
      end

      it "processes the message and sends response" do
        expect(mock_agent).to receive(:chat).with("Hello bot", conversation: anything, log_start: false).and_return("Test response")
        expect(mock_api).to receive(:send_message).with(chat_id: 123456, text: anything, parse_mode: "HTML")
        channel.process_message(message)
      end

      it "creates a new conversation for new chat" do
        allow(mock_conversation).to receive(:uuid).and_return("test-uuid")
        allow(Botiasloop::Conversation).to receive(:new).and_return(mock_conversation)

        channel.process_message(message)

        expect(File.exist?(chats_file)).to be true
        chats_data = JSON.parse(File.read(chats_file), symbolize_names: true)
        expect(chats_data[:"123456"]).to include(:conversation_uuid, :username)
      end
    end

    context "when chat already exists" do
      let(:message) do
        double(
          "message",
          chat: double("chat", id: 123456),
          from: double("from", username: "testuser"),
          text: "Second message"
        )
      end

      before do
        FileUtils.mkdir_p(File.dirname(chats_file))
        File.write(chats_file, JSON.dump({
          "123456" => {
            conversation_uuid: "existing-uuid",
            username: "testuser"
          }
        }))
        # Reload chats from file
        channel.instance_variable_set(:@chats, channel.send(:load_chats))
      end

      it "reuses existing conversation" do
        conversation = instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
        expect(Botiasloop::Conversation).to receive(:new).with("existing-uuid").and_return(conversation)
        expect(Botiasloop::Conversation).not_to receive(:new).with(no_args)
        allow(mock_agent).to receive(:chat).and_return("Test response")

        channel.process_message(message)
      end
    end
  end

  describe "#conversation_for_chat" do
    let(:channel) { described_class.new(config) }

    before do
      # Ensure the channel reloads chats from file for each test
      channel.instance_variable_set(:@chats, {})
    end

    context "when chat does not exist" do
      it "creates new conversation and saves mapping" do
        conversation = channel.conversation_for_chat(123456, "testuser")

        expect(conversation).to be_a(Botiasloop::Conversation)
        expect(File.exist?(chats_file)).to be true

        chats_data = JSON.parse(File.read(chats_file), symbolize_names: true)
        expect(chats_data[:"123456"][:username]).to eq("testuser")
        expect(chats_data[:"123456"][:conversation_uuid]).to eq(conversation.uuid)
      end
    end

    context "when chat exists" do
      before do
        FileUtils.mkdir_p(File.dirname(chats_file))
        File.write(chats_file, JSON.dump({
          "123456" => {
            conversation_uuid: "existing-uuid",
            username: "testuser"
          }
        }))
        # Reload chats from file
        channel.instance_variable_set(:@chats, channel.send(:load_chats))
      end

      it "returns existing conversation" do
        existing_conversation = instance_double(Botiasloop::Conversation, uuid: "existing-uuid")
        expect(Botiasloop::Conversation).to receive(:new).with("existing-uuid").and_return(existing_conversation)
        expect(Botiasloop::Conversation).not_to receive(:new).with(no_args)
        conversation = channel.conversation_for_chat(123456, "testuser")
        expect(conversation.uuid).to eq("existing-uuid")
      end
    end
  end

  describe "#allowed_user?" do
    let(:channel) { described_class.new(config) }

    context "when allowed_users is empty" do
      let(:config) do
        Botiasloop::Config.new({
          telegram: {
            bot_token: "test-token-123",
            allowed_users: []
          }
        })
      end

      it "returns false for any username" do
        expect(channel.allowed_user?("anyuser")).to be false
        expect(channel.allowed_user?(nil)).to be false
      end
    end

    context "when allowed_users has entries" do
      it "returns true for allowed username" do
        expect(channel.allowed_user?("testuser")).to be true
      end

      it "returns false for non-allowed username" do
        expect(channel.allowed_user?("otheruser")).to be false
      end

      it "returns false for nil username" do
        expect(channel.allowed_user?(nil)).to be false
      end
    end
  end

  describe "#to_telegram_html" do
    let(:channel) { described_class.new(config) }

    it "converts bold markdown to HTML" do
      result = channel.send(:to_telegram_html, "This is **bold** text")
      expect(result).to include("<strong>bold</strong>")
    end

    it "converts italic markdown to HTML" do
      result = channel.send(:to_telegram_html, "This is *italic* text")
      expect(result).to include("<em>italic</em>")
    end

    it "converts strikethrough markdown to HTML" do
      result = channel.send(:to_telegram_html, "This is ~~deleted~~ text")
      expect(result).to include("<del>deleted</del>")
    end

    it "converts inline code to HTML" do
      result = channel.send(:to_telegram_html, "Use `code` here")
      expect(result).to include("<code>code</code>")
    end

    it "converts code blocks to HTML" do
      result = channel.send(:to_telegram_html, "```ruby\ndef hello\n  puts 'hi'\nend\n```")
      expect(result).to include("<pre>")
      expect(result).to match(/<code/)
    end

    it "converts headers to bold" do
      result = channel.send(:to_telegram_html, "# Header 1\n## Header 2")
      expect(result).to include("<b>Header 1</b>")
      expect(result).to include("<b>Header 2</b>")
      expect(result).not_to include("<h1>")
      expect(result).not_to include("<h2>")
    end

    it "converts unordered lists to formatted text" do
      result = channel.send(:to_telegram_html, "- Item 1\n- Item 2\n- Item 3")
      expect(result).to include("• Item 1")
      expect(result).to include("• Item 2")
      expect(result).to include("• Item 3")
      expect(result).not_to include("<ul>")
      expect(result).not_to include("<li>")
    end

    it "converts ordered lists to formatted text" do
      result = channel.send(:to_telegram_html, "1. First\n2. Second\n3. Third")
      expect(result).to include("1. First")
      expect(result).to include("2. Second")
      expect(result).to include("3. Third")
      expect(result).not_to include("<ol>")
      expect(result).not_to include("<li>")
    end

    it "converts tables to columns on separate lines" do
      result = channel.send(:to_telegram_html, "| Col1 | Col2 | Col3 |\n|------|------|------|\n| A | B | C |")
      expect(result).to include("Col1")
      expect(result).to include("Col2")
      expect(result).to include("Col3")
      expect(result).to include("A")
      expect(result).to include("B")
      expect(result).to include("C")
      expect(result).not_to include("<table>")
    end

    it "converts links to HTML" do
      result = channel.send(:to_telegram_html, "Check [this link](http://example.com)")
      expect(result).to include('<a href="http://example.com">this link</a>')
    end

    it "preserves line breaks" do
      result = channel.send(:to_telegram_html, "Line 1\nLine 2")
      expect(result).to include("Line 1\n")
      expect(result).to include("Line 2")
      expect(result).not_to include("<br>")
    end

    it "removes unsupported HTML tags" do
      result = channel.send(:to_telegram_html, "Text with <script>alert('xss')</script> script")
      expect(result).not_to include("<script>")
      expect(result).not_to include("</script>")
      expect(result).to include("Text with")
      expect(result).to include("script")
    end
  end
end
