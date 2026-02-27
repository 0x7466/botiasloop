# frozen_string_literal: true

require "spec_helper"
require "json"
require "tempfile"
require "fileutils"

RSpec.describe Botiasloop::Channels::Telegram do
  let(:test_config) do
    Botiasloop::Config.new({
      "channels" => {
        "telegram" => {
          "bot_token" => "test-token-123",
          "allowed_users" => ["testuser"]
        }
      },
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  let(:mock_bot) { double("bot") }
  let(:mock_api) { double("api") }

  before do
    Botiasloop::Config.instance = test_config

    # Ensure Telegram is registered in the global registry
    Botiasloop::Channels.registry.register(described_class)

    # Mock Telegram::Bot::Client
    stub_const("Telegram::Bot::Client", double)
    stub_const("Telegram::Bot::Types::Message", Class.new)
    allow(Telegram::Bot::Client).to receive(:new).with("test-token-123").and_return(mock_bot)
    allow(mock_bot).to receive(:api).and_return(mock_api)
    allow(mock_bot).to receive(:run).and_yield(mock_bot)
    allow(mock_bot).to receive(:listen)

    # Mock set_my_commands API call
    allow(mock_api).to receive(:set_my_commands)
  end

  after do
    Botiasloop::Config.instance = nil
  end

  describe "inheritance" do
    it "inherits from Channels::Base" do
      expect(described_class.ancestors).to include(Botiasloop::Channels::Base)
    end

    it "has channel_name :telegram" do
      expect(described_class.channel_identifier).to eq(:telegram)
    end

    it "requires :bot_token config" do
      expect(described_class.required_config_keys).to include(:bot_token)
    end
  end

  describe "auto-registration" do
    it "is registered in the global registry" do
      registry = Botiasloop::Channels.registry
      expect(registry[:telegram]).to eq(described_class)
    end
  end

  describe "#initialize" do
    context "when bot_token is configured" do
      it "initializes successfully" do
        channel = described_class.new
        expect(channel).to be_a(described_class)
      end

      it "loads allowed_users from config" do
        channel = described_class.new
        expect(channel.instance_variable_get(:@allowed_users)).to eq(["testuser"])
      end
    end

    context "when bot_token is not configured" do
      let(:incomplete_config) do
        Botiasloop::Config.new({
          "channels" => {
            "telegram" => {
              "bot_token" => nil,
              "allowed_users" => ["testuser"]
            }
          },
          "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
        })
      end

      before do
        Botiasloop::Config.instance = incomplete_config
      end

      it "raises an error" do
        expect { described_class.new }.to raise_error(Botiasloop::Error, /bot_token/)
      end
    end
  end

  describe "#start_listening" do
    let(:channel) { described_class.new }

    before do
      allow(Botiasloop::Logger).to receive(:info)
      allow(Botiasloop::Logger).to receive(:warn)
      allow(Botiasloop::Logger).to receive(:error)
    end

    context "when allowed_users is empty" do
      let(:empty_config) do
        Botiasloop::Config.new({
          "channels" => {
            "telegram" => {
              "bot_token" => "test-token-123",
              "allowed_users" => []
            }
          },
          "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
        })
      end

      before do
        Botiasloop::Config.instance = empty_config
      end

      it "logs a warning about no allowed users" do
        expect(Botiasloop::Logger).to receive(:warn).with(/allowed_users/)
        allow(mock_bot).to receive(:listen)
        channel.start_listening
      end
    end

    context "when allowed_users is configured" do
      it "starts polling for messages" do
        expect(mock_bot).to receive(:listen).and_yield(nil)
        channel.start_listening
      end

      it "sets bot instance" do
        allow(mock_bot).to receive(:listen).and_yield(nil)
        channel.start_listening
        expect(channel.instance_variable_get(:@bot)).to eq(mock_bot)
      end
    end
  end

  describe "#stop_listening" do
    let(:channel) { described_class.new }

    before do
      allow(Botiasloop::Logger).to receive(:info)
    end

    it "logs stopping message" do
      expect(Botiasloop::Logger).to receive(:info).with(/Stopping/)
      channel.stop_listening
    end

    it "interrupts the running thread" do
      # Mock bot.run to block until interrupted
      blocking_called = false
      allow(mock_bot).to receive(:run) do |_block|
        blocking_called = true
        sleep 0.5 # Simulate blocking listen loop
      end

      # Start the channel in a separate thread
      thread = Thread.new do
        channel.start_listening
      end

      # Wait for blocking to start
      sleep 0.1 until blocking_called || !thread.alive?

      # Verify thread is running (blocked on the mock)
      expect(thread.alive?).to be true

      # Stop should interrupt the thread
      channel.stop_listening

      # Wait for thread to finish
      sleep 0.2

      # Thread should have exited gracefully
      expect(thread.alive?).to be false
    end
  end

  describe "#running?" do
    let(:channel) { described_class.new }

    it "returns false when bot is not started" do
      expect(channel.running?).to be false
    end

    it "returns true when bot is started" do
      channel.instance_variable_set(:@bot, mock_bot)
      expect(channel.running?).to be true
    end
  end

  describe "#process_message" do
    let(:mock_conversation) { instance_double(Botiasloop::Conversation) }
    let(:chat_id) { 123_456 }
    let(:message_text) { "Hello bot" }
    let(:username) { "testuser" }

    let(:message) do
      double(
        "message",
        chat: double("chat", id: chat_id),
        from: double("from", username: username),
        text: message_text
      )
    end

    let(:channel) do
      # Stub Logger before creating channel

      described_class.new
    end

    before do
      allow(Botiasloop::Logger).to receive(:info)
      allow(Botiasloop::Logger).to receive(:warn)
      allow(Botiasloop::Logger).to receive(:error)
      allow(Botiasloop::Agent).to receive(:chat).and_return("Test response")
      allow(mock_api).to receive(:send_message)
      channel.instance_variable_set(:@bot, mock_bot)
    end

    context "when user is not in allowed list" do
      let(:username) { "unauthorized_user" }

      it "silently ignores the message" do
        expect(Botiasloop::Agent).not_to receive(:chat)
        expect(mock_api).not_to receive(:send_message)
        channel.process_message(chat_id.to_s, message)
      end

      it "logs warning about unauthorized user" do
        expect(Botiasloop::Logger).to receive(:warn).with(/unauthorized/)
        channel.process_message(chat_id.to_s, message)
      end
    end

    context "when user is in allowed list" do
      it "processes the message and sends response" do
        expect(Botiasloop::Agent).to receive(:chat).with(
          message_text,
          conversation: anything,
          verbose_callback: anything
        ).and_return("Test response")
        expect(mock_api).to receive(:send_message).with(
          chat_id: chat_id,
          text: anything,
          parse_mode: "HTML"
        )
        channel.process_message(chat_id.to_s, message)
      end

      it "uses Chat for conversation state" do
        channel.process_message(chat_id.to_s, message)

        # Verify chat was created and associated with the user
        chat = Botiasloop::Chat.find(channel: "telegram", external_id: chat_id.to_s)
        expect(chat).not_to be_nil
        expect(chat.current_conversation).not_to be_nil
      end
    end

    context "when chat already exists" do
      before do
        Botiasloop::Chat.create(channel: "telegram", external_id: chat_id.to_s)
      end

      it "reuses existing conversation" do
        allow(Botiasloop::Agent).to receive(:chat).and_return("Test response")

        # Process message - should use existing chat
        channel.process_message(chat_id.to_s, message)

        # Verify the chat was retrieved
        chat = Botiasloop::Chat.find(channel: "telegram", external_id: chat_id.to_s)
        expect(chat).not_to be_nil
      end
    end
  end

  describe "#chat_for" do
    let(:channel) { described_class.new }

    context "when chat does not exist" do
      it "creates new chat and conversation" do
        chat = channel.chat_for("123456")

        expect(chat).to be_a(Botiasloop::Chat)
        expect(chat.current_conversation).to be_a(Botiasloop::Conversation)

        # Verify via database
        db_conv = Botiasloop::Conversation.find(id: chat.current_conversation.id)
        expect(db_conv).not_to be_nil
      end
    end

    context "when chat exists" do
      before do
        Botiasloop::Chat.create(channel: "telegram", external_id: "123456")
      end

      it "returns existing chat" do
        chat = channel.chat_for("123456")
        expect(chat.external_id).to eq("123456")
      end
    end
  end

  describe "#authorized?" do
    let(:channel) { described_class.new }

    context "when allowed_users is empty" do
      let(:config) do
        Botiasloop::Config.new({
          "channels" => {
            "telegram" => {
              "bot_token" => "test-token-123",
              "allowed_users" => []
            }
          },
          "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
        })
      end

      it "returns false for any username" do
        expect(channel.authorized?("anyuser")).to be false
        expect(channel.authorized?(nil)).to be false
      end
    end

    context "when allowed_users has entries" do
      it "returns true for allowed username" do
        expect(channel.authorized?("testuser")).to be true
      end

      it "returns false for non-allowed username" do
        expect(channel.authorized?("otheruser")).to be false
      end

      it "returns false for nil username" do
        expect(channel.authorized?(nil)).to be false
      end
    end
  end

  describe "#extract_content" do
    let(:channel) { described_class.new }
    let(:message_text) { "Hello bot" }
    let(:message) do
      instance_double(
        Telegram::Bot::Types::Message,
        text: message_text,
        from: instance_double(Telegram::Bot::Types::User, username: "testuser"),
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456)
      )
    end

    it "extracts text from Telegram message" do
      expect(channel.extract_content(message)).to eq("Hello bot")
    end
  end

  describe "#extract_user_id" do
    let(:channel) { described_class.new }
    let(:message) do
      instance_double(
        Telegram::Bot::Types::Message,
        text: "Hello",
        from: instance_double(Telegram::Bot::Types::User, username: "testuser"),
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456)
      )
    end

    it "extracts username from Telegram message" do
      expect(channel.extract_user_id("123456", message)).to eq("testuser")
    end

    it "handles messages without username" do
      message_no_user = instance_double(
        Telegram::Bot::Types::Message,
        text: "Hello",
        from: nil,
        chat: instance_double(Telegram::Bot::Types::Chat, id: 123_456)
      )
      expect(channel.extract_user_id("123456", message_no_user)).to be_nil
    end
  end

  describe "#before_process" do
    let(:channel) { described_class.new }
    let(:logger) { Botiasloop::Logger }

    before do
      allow(Botiasloop::Logger).to receive(:info)
    end

    it "logs message receipt" do
      expect(Botiasloop::Logger).to receive(:info).with("[Telegram] Message from @testuser: Hello")
      channel.before_process("123456", "testuser", "Hello", nil)
    end
  end

  describe "#after_process" do
    let(:channel) { described_class.new }
    let(:logger) { Botiasloop::Logger }

    before do
      allow(Botiasloop::Logger).to receive(:info)
    end

    it "logs response sent" do
      expect(Botiasloop::Logger).to receive(:info).with("[Telegram] Response sent to @testuser")
      channel.after_process("123456", "testuser", "Response text", nil)
    end
  end

  describe "#handle_unauthorized" do
    let(:channel) { described_class.new }
    let(:logger) { Botiasloop::Logger }

    before do
      allow(Botiasloop::Logger).to receive(:warn)
    end

    it "logs warning about unauthorized user" do
      expect(Botiasloop::Logger).to receive(:warn).with("[Telegram] Ignored message from unauthorized user @baduser (chat_id: 123456)")
      channel.handle_unauthorized("123456", "baduser", nil)
    end
  end

  describe "#handle_error" do
    let(:channel) { described_class.new }
    let(:logger) { Botiasloop::Logger }

    before do
      allow(Botiasloop::Logger).to receive(:error)
    end

    it "logs error without re-raising" do
      error = StandardError.new("Test error")
      expect(Botiasloop::Logger).to receive(:error).with("[Telegram] Error processing message: Test error")
      expect { channel.handle_error("123456", "testuser", error, nil) }.not_to raise_error
    end
  end

  describe "#format_message" do
    let(:channel) { described_class.new }

    it "converts markdown to telegram HTML" do
      result = channel.format_message("**bold** text")
      expect(result).to include("<strong>bold</strong>")
    end

    it "returns empty string for nil content" do
      expect(channel.format_message(nil)).to eq("")
    end

    it "returns empty string for empty content" do
      expect(channel.format_message("")).to eq("")
    end
  end

  describe "#deliver_message" do
    let(:channel) { described_class.new }
    let(:chat_id) { "123456" }
    let(:formatted_content) { "<b>Hello</b> world" }

    before do
      channel.instance_variable_set(:@bot, mock_bot)
    end

    it "sends message via bot API" do
      expect(mock_api).to receive(:send_message).with(
        chat_id: 123_456,
        text: formatted_content,
        parse_mode: "HTML"
      )
      channel.deliver_message(chat_id, formatted_content)
    end

    it "converts string chat_id to integer" do
      expect(mock_api).to receive(:send_message).with(
        hash_including(chat_id: 123_456)
      )
      channel.deliver_message("123456", formatted_content)
    end

    it "skips sending when content is empty" do
      expect(mock_api).not_to receive(:send_message)
      channel.deliver_message(chat_id, "")
    end

    it "skips sending when content is nil" do
      expect(mock_api).not_to receive(:send_message)
      channel.deliver_message(chat_id, nil)
    end
  end

  describe "private #to_telegram_html" do
    let(:channel) { described_class.new }

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
      expect(result).to include("<pre><code>")
      expect(result).to include("</code></pre>")
      expect(result).not_to include("<code class=")
      expect(result).to include("def hello")
    end

    it "converts code blocks without language to HTML" do
      result = channel.send(:to_telegram_html, "```\nplain code\n```")
      expect(result).to include("<pre><code>")
      expect(result).to include("</code></pre>")
      expect(result).to include("plain code")
    end

    it "escapes HTML inside code blocks" do
      result = channel.send(:to_telegram_html, "```\n<div>test</div>\n```")
      expect(result).to include("&lt;div&gt;test&lt;/div&gt;")
      expect(result).not_to include("<div>test</div>")
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

    it "converts tables to properly formatted text in pre tags" do
      result = channel.send(:to_telegram_html, "| Col1 | Col2 | Col3 |\n|------|------|------|\n| A | B | C |")
      expect(result).to include("<pre>")
      expect(result).to include("</pre>")
      expect(result).to include("<b>Col1</b>")
      expect(result).to include("<b>Col2</b>")
      expect(result).to include("<b>Col3</b>")
      expect(result).to include("A")
      expect(result).to include("B")
      expect(result).to include("C")
      expect(result).not_to include("<table>")
      expect(result).not_to include("<tr>")
      expect(result).not_to include("<td>")
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
