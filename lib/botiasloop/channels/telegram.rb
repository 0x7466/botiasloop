# frozen_string_literal: true

require "telegram/bot"
require "json"
require "fileutils"

module Botiasloop
  module Channels
    class Telegram
      def self.chats_file
        @chats_file ||= File.expand_path("~/.config/botiasloop/telegram_chats.json")
      end

      def self.chats_file=(path)
        @chats_file = path
      end

      # Initialize Telegram channel
      #
      # @param config [Config] Configuration instance
      # @raise [Error] If bot_token is not configured
      def initialize(config)
        @config = config
        @logger = Logger.new($stderr)
        @bot_token = config.telegram_bot_token

        raise Error, "telegram.bot_token is required" unless @bot_token

        @allowed_users = config.telegram_allowed_users
        @chats = load_chats
      end

      # Start the Telegram bot and listen for messages
      def start
        if @allowed_users.empty?
          @logger.warn "[Telegram] No allowed_users configured. No messages will be processed."
          @logger.warn "[Telegram] Add usernames to telegram.allowed_users in config."
        end

        @logger.info "[Telegram] Starting bot..."

        @bot = ::Telegram::Bot::Client.new(@bot_token)
        @bot.run do |bot|
          bot.listen do |message|
            process_message(message) if message.is_a?(::Telegram::Bot::Types::Message)
          end
        end
      rescue Interrupt
        @logger.info "[Telegram] Shutting down..."
      end

      # Process a single message
      #
      # @param message [Telegram::Bot::Types::Message] Incoming message
      def process_message(message)
        username = message.from&.username
        chat_id = message.chat.id
        text = message.text

        return unless allowed_user?(username)

        @logger.info "[Telegram] Message from @#{username}: #{text}"

        conversation = conversation_for_chat(chat_id, username)
        agent = Botiasloop::Agent.new(@config)
        response = agent.chat(text, conversation: conversation, log_start: false)

        @bot.api.send_message(chat_id: chat_id, text: response)
        @logger.info "[Telegram] Response sent to @#{username}"
      rescue => e
        @logger.error "[Telegram] Error processing message: #{e.message}"
      end

      # Check if username is in allowed list
      #
      # @param username [String, nil] Telegram username
      # @return [Boolean] True if allowed
      def allowed_user?(username)
        return false if username.nil? || @allowed_users.empty?

        @allowed_users.include?(username)
      end

      # Get or create conversation for a chat
      #
      # @param chat_id [Integer] Telegram chat ID
      # @param username [String] Telegram username
      # @return [Conversation] Conversation instance
      def conversation_for_chat(chat_id, username)
        chat_key = chat_id.to_s.to_sym

        if @chats[chat_key]
          Conversation.new(@chats[chat_key][:conversation_uuid])
        else
          conversation = Conversation.new
          @chats[chat_key] = {
            conversation_uuid: conversation.uuid,
            username: username
          }
          save_chats
          conversation
        end
      end

      private

      def load_chats
        file_path = self.class.chats_file
        return {} unless File.exist?(file_path)

        JSON.parse(File.read(file_path), symbolize_names: true)
      rescue JSON::ParserError
        {}
      end

      def save_chats
        file_path = self.class.chats_file
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, JSON.pretty_generate(@chats))
      end
    end
  end
end
