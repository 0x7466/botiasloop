# frozen_string_literal: true

require "telegram/bot"
require "json"
require "fileutils"
require "redcarpet"

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

        unless allowed_user?(username)
          @logger.warn "[Telegram] Ignored message from unauthorized user @#{username} (chat_id: #{chat_id})"
          return
        end

        @logger.info "[Telegram] Message from @#{username}: #{text}"

        conversation = conversation_for_chat(chat_id, username)
        agent = Botiasloop::Agent.new(@config)
        response = agent.chat(text, conversation: conversation, log_start: false)

        # Convert Markdown response to Telegram-compatible HTML
        html_response = to_telegram_html(response)

        @bot.api.send_message(chat_id: chat_id, text: html_response, parse_mode: "HTML")
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

      # Convert Markdown to Telegram-compatible HTML
      #
      # @param markdown [String] Markdown text
      # @return [String] Telegram-compatible HTML
      def to_telegram_html(markdown)
        return "" if markdown.nil? || markdown.empty?

        # Configure Redcarpet renderer for Telegram-compatible HTML
        renderer_options = {
          hard_wrap: true,
          filter_html: false
        }

        extensions = {
          fenced_code_blocks: true,
          autolink: true,
          strikethrough: true,
          tables: true,
          no_intra_emphasis: true
        }

        renderer = Redcarpet::Render::HTML.new(renderer_options)
        markdown_parser = Redcarpet::Markdown.new(renderer, extensions)
        html = markdown_parser.render(markdown)

        # Post-process HTML for Telegram compatibility
        process_html_for_telegram(html)
      end

      # Process HTML to make it Telegram-compatible
      def process_html_for_telegram(html)
        result = html

        # Convert headers to bold
        result = result.gsub(/<h[1-6][^>]*>(.*?)<\/h[1-6]>/, '<b>\1</b>')

        # Convert lists to formatted text
        result = convert_lists(result)

        # Convert tables to columns on separate lines
        result = convert_tables(result)

        # Convert <br> tags to newlines (Telegram doesn't support <br>)
        result = result.gsub(/<br\s*\/?>/, "\n")

        # Strip unsupported HTML tags
        strip_unsupported_tags(result)
      end

      # Convert HTML lists to formatted text with bullets/numbers
      def convert_lists(html)
        # Process unordered lists
        result = html.gsub(/<ul[^>]*>.*?<\/ul>/m) do |ul_block|
          ul_block.gsub(/<li[^>]*>(.*?)<\/li>/) do |_|
            "• #{::Regexp.last_match(1)}<br>"
          end.gsub(/<\/?ul>/, "")
        end

        # Process ordered lists
        result.gsub(/<ol[^>]*>.*?<\/ol>/m) do |ol_block|
          counter = 0
          ol_block.gsub(/<li[^>]*>(.*?)<\/li>/) do |_|
            counter += 1
            "#{counter}. #{::Regexp.last_match(1)}<br>"
          end.gsub(/<\/?ol>/, "")
        end
      end

      # Convert HTML tables to columns on separate lines with blank lines between rows
      def convert_tables(html)
        html.gsub(/<table[^>]*>.*?<\/table>/m) do |table_block|
          rows = []
          # Extract all rows
          table_block.scan(/<tr[^>]*>(.*?)<\/tr>/m) do |row_match|
            row_html = row_match[0]
            # Extract cells from this row
            cells = row_html.scan(/<t[dh][^>]*>(.*?)<\/t[dh]>/).flatten
            # Add each cell as a separate line
            rows << cells.join("<br>")
          end

          # Join rows with blank line between them
          rows.join("<br><br>")
        end
      end

      # Strip HTML tags not supported by Telegram
      def strip_unsupported_tags(html)
        # Telegram supports: <b>, <strong>, <i>, <em>, <u>, <ins>, <s>, <strike>, <del>, <code>, <pre>, <a>
        # Remove all other tags but keep their content
        # Note: <br> is converted to newlines before this method is called
        allowed_tags = %w[b strong i em u ins s strike del code pre a]

        result = html.dup

        # Remove all HTML tags that are not in the allowed list
        result.gsub!(/<\/?(\w+)[^>]*>/) do |tag|
          tag_name = tag.gsub(/[<>\/]/, "").split.first
          allowed_tags.include?(tag_name) ? tag : ""
        end

        result
      end
    end
  end
end
