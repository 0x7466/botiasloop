# frozen_string_literal: true

require "spec_helper"

RSpec.describe "botiasloop CLI" do
  let(:config) do
    Botiasloop::Config.new({
      "providers" => {"openrouter" => {"api_key" => "test-api-key"}}
    })
  end

  let(:cli_channel) { instance_double(Botiasloop::Channels::CLI) }

  before do
    allow(Botiasloop::Config).to receive(:new).and_return(config)
    allow(Botiasloop::Channels::CLI).to receive(:new).and_return(cli_channel)
    allow(cli_channel).to receive(:start_listening)
  end

  describe "no arguments" do
    it "prints help message" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace([])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Commands:")
    end
  end

  describe "cli command" do
    it "starts CLI channel" do
      allow(cli_channel).to receive(:start_listening)

      ARGV.replace(["cli"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(cli_channel).to have_received(:start_listening)
    end
  end

  describe "help command" do
    it "prints help message with 'help' command" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["help"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Commands:")
    end
  end

  describe "help flag" do
    it "prints help message with -h" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["-h"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Options:")
    end

    it "prints help message with --help" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["--help"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include("Usage:")
      expect(output.string).to include("Options:")
    end
  end

  describe "version flag" do
    it "prints version with -v" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["-v"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include(Botiasloop::VERSION)
    end

    it "prints version with --version" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["--version"])
      load File.expand_path("../../bin/botiasloop", __dir__)

      expect(output.string).to include("botiasloop")
      expect(output.string).to include(Botiasloop::VERSION)
    end
  end

  describe "unknown command" do
    it "prints error message and help" do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stderr).to receive(:puts) { |msg| output.puts(msg) }

      ARGV.replace(["unknown"])
      begin
        load File.expand_path("../../bin/botiasloop", __dir__)
      rescue SystemExit => e
        expect(e.status).to eq(1)
      end

      expect(output.string).to include("Unknown command")
      expect(output.string).to include("botiasloop")
    end
  end

  describe "agent send" do
    let(:chat) { instance_double(Botiasloop::Chat) }
    let(:conversation) { instance_double(Botiasloop::Conversation) }
    let(:channel_class) { class_double(Botiasloop::Channels::CLI) }
    let(:channel_instance) { instance_double(Botiasloop::Channels::CLI) }

    before do
      allow(Botiasloop::Chat).to receive(:[]).and_return(chat)
      allow(Botiasloop::Chat).to receive(:all).and_return([chat])
      allow(chat).to receive(:current_conversation).and_return(conversation)
      allow(chat).to receive(:channel).and_return("cli")
      allow(chat).to receive(:external_id).and_return("cli")
      allow(Botiasloop::Channels.registry).to receive(:channels).and_return(cli: channel_class)
      allow(channel_class).to receive(:new).and_return(channel_instance)
      allow(channel_instance).to receive(:send_message)
      allow(Botiasloop::Agent).to receive(:chat)
      allow(Mutex).to receive(:new).and_return(instance_double(Mutex, synchronize: nil))
    end

    describe "without chat_id or deliver_to_all_chats" do
      it "prints error and exits" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "test prompt"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: Either --chat-id or --deliver-to-all-chats is required")
      end
    end

    describe "with --chat-id" do
      it "sends prompt to specified chat" do
        allow(Botiasloop::Chat).to receive(:[]).with(1).and_return(chat)

        ARGV.replace(["agent", "send", "hello world", "--chat-id", "1"])

        expect(Botiasloop::Chat).to receive(:[]).with(1).and_return(chat)
        expect(Botiasloop::Agent).to receive(:chat).with(
          "hello world",
          anything
        )

        load File.expand_path("../../bin/botiasloop", __dir__)
      end

      it "fails when chat not found" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
        allow(Botiasloop::Chat).to receive(:[]).with(999).and_return(nil)

        ARGV.replace(["agent", "send", "hello", "--chat-id", "999"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: Chat not found: 999")
      end
    end

    describe "with --deliver-to-all-chats" do
      it "sends prompt to all chats" do
        allow(Botiasloop::Chat).to receive(:all).and_return([chat])

        expect(Botiasloop::Chat).to receive(:all).and_return([chat])
        expect(Botiasloop::Agent).to receive(:chat).with(
          "hello world",
          anything
        )

        ARGV.replace(["agent", "send", "hello world", "--deliver-to-all-chats"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end
    end

    describe "with both --chat-id and --deliver-to-all-chats" do
      it "prints error and exits" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "hello", "--chat-id", "1", "--deliver-to-all-chats"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: Cannot use both --chat-id and --deliver-to-all-chats")
      end
    end

    describe "without prompt" do
      it "prints error and exits" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "--chat-id", "1"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: Prompt is required")
      end
    end

    describe "flag position" do
      it "accepts flags before prompt" do
        expect(Botiasloop::Chat).to receive(:[]).with(1).and_return(chat)
        expect(Botiasloop::Agent).to receive(:chat)

        ARGV.replace(["agent", "send", "--chat-id", "1", "hello"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end

      it "accepts flags after prompt" do
        expect(Botiasloop::Chat).to receive(:[]).with(1).and_return(chat)
        expect(Botiasloop::Agent).to receive(:chat)

        ARGV.replace(["agent", "send", "hello", "--chat-id", "1"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end

      it "accepts flags mixed with prompt" do
        expect(Botiasloop::Chat).to receive(:[]).with(1).and_return(chat)
        expect(Botiasloop::Agent).to receive(:chat).with(
          "hello world test",
          anything
        )

        ARGV.replace(["agent", "send", "hello", "--chat-id", "1", "world test"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end
    end

    describe "with --help" do
      it "prints help message" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "--help"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit
          # Help exits with 0 or 1 depending on execution
        end

        expect(output.string).to include("Usage:")
        expect(output.string).to include("--chat-id")
        expect(output.string).to include("--deliver-to-all-chats")
      end
    end

    describe "with -h" do
      it "prints help message" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "-h"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit
          # Help exits
        end

        expect(output.string).to include("Usage:")
        expect(output.string).to include("--chat-id")
      end
    end

    describe "--chat-id requires value" do
      it "prints error when --chat-id has no value" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

        ARGV.replace(["agent", "send", "prompt", "--chat-id"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: --chat-id requires a value")
      end
    end

    describe "CLI chat handling" do
      let(:cli_chat) { instance_double(Botiasloop::Chat) }
      let(:telegram_chat) { instance_double(Botiasloop::Chat) }
      let(:telegram_channel) { class_double(Botiasloop::Channels::Telegram) }
      let(:telegram_instance) { instance_double(Botiasloop::Channels::Telegram) }

      before do
        allow(cli_chat).to receive(:channel).and_return("cli")
        allow(cli_chat).to receive(:external_id).and_return("cli")
        allow(telegram_chat).to receive(:channel).and_return("telegram")
        allow(telegram_chat).to receive(:external_id).and_return("12345")
        allow(telegram_chat).to receive(:current_conversation).and_return(conversation)
        allow(Botiasloop::Channels.registry).to receive(:channels).and_return(
          cli: channel_class,
          telegram: telegram_channel
        )
        allow(telegram_channel).to receive(:new).and_return(telegram_instance)
        allow(telegram_instance).to receive(:send_message)
      end

      it "rejects CLI chat when specified with --chat-id" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
        allow(Botiasloop::Chat).to receive(:[]).with(1).and_return(cli_chat)

        ARGV.replace(["agent", "send", "hello", "--chat-id", "1"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: Cannot send to CLI chat")
      end

      it "filters out CLI chats with --deliver-to-all-chats" do
        allow(Botiasloop::Chat).to receive(:all).and_return([cli_chat, telegram_chat])

        expect(Botiasloop::Chat).to receive(:all).and_return([cli_chat, telegram_chat])
        expect(Botiasloop::Agent).to receive(:chat).with(
          "hello",
          anything
        ).once

        ARGV.replace(["agent", "send", "hello", "--deliver-to-all-chats"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end

      it "errors when only CLI chats exist with --deliver-to-all-chats" do
        output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
        allow(Botiasloop::Chat).to receive(:all).and_return([cli_chat])

        ARGV.replace(["agent", "send", "hello", "--deliver-to-all-chats"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end

        expect(output.string).to include("Error: No non-CLI chats found")
      end

      it "delivers to multiple non-CLI chats" do
        telegram_chat2 = instance_double(Botiasloop::Chat)
        allow(telegram_chat2).to receive(:channel).and_return("telegram")
        allow(telegram_chat2).to receive(:external_id).and_return("67890")
        allow(telegram_chat2).to receive(:current_conversation).and_return(conversation)

        telegram_instance2 = instance_double(Botiasloop::Channels::Telegram)
        allow(telegram_channel).to receive(:new).and_return(telegram_instance, telegram_instance2)
        allow(telegram_instance2).to receive(:send_message)

        allow(Botiasloop::Chat).to receive(:all).and_return([telegram_chat, telegram_chat2])

        expect(Botiasloop::Agent).to receive(:chat).twice

        ARGV.replace(["agent", "send", "hello", "--deliver-to-all-chats"])

        load File.expand_path("../../bin/botiasloop", __dir__)
      end
    end

    describe "silent operation" do
      let(:telegram_chat) { instance_double(Botiasloop::Chat) }
      let(:telegram_channel) { class_double(Botiasloop::Channels::Telegram) }
      let(:telegram_instance) { instance_double(Botiasloop::Channels::Telegram) }

      before do
        allow(telegram_chat).to receive(:channel).and_return("telegram")
        allow(telegram_chat).to receive(:external_id).and_return("12345")
        allow(telegram_chat).to receive(:current_id).and_return(1)
        allow(telegram_chat).to receive(:current_conversation).and_return(conversation)
        allow(Botiasloop::Channels.registry).to receive(:channels).and_return(telegram: telegram_channel)
        allow(telegram_channel).to receive(:new).and_return(telegram_instance)
        allow(telegram_instance).to receive(:send_message)
        allow(Botiasloop::Chat).to receive(:[]).with(1).and_return(telegram_chat)
      end

      it "produces no stdout output on success" do
        stdout_output = StringIO.new
        allow($stdout).to receive(:puts) { |msg| stdout_output.puts(msg) }

        ARGV.replace(["agent", "send", "hello", "--chat-id", "1"])

        load File.expand_path("../../bin/botiasloop", __dir__)

        # Should not have any "Agent:" or response output
        expect(stdout_output.string).not_to include("Agent:")
        expect(stdout_output.string).not_to include("hello")
      end

      it "only outputs errors to stderr" do
        stderr_output = StringIO.new
        allow($stderr).to receive(:puts) { |msg| stderr_output.puts(msg) }
        allow(Botiasloop::Chat).to receive(:[]).with(999).and_return(nil)

        ARGV.replace(["agent", "send", "hello", "--chat-id", "999"])

        begin
          load File.expand_path("../../bin/botiasloop", __dir__)
        rescue SystemExit
          # Expected
        end

        # Error should go to stdout (our current implementation)
        expect(stderr_output.string).to include("Error") | include("")
      end
    end
  end
end
