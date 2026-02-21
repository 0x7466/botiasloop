# frozen_string_literal: true

require "telegram/bot"
require "json"
require "fileutils"
require "redcarpet"

module Botiasloop
  module Channels
    class Telegram < Base
      channel_name :telegram
      requires_config :bot_token

      # Get Telegram-specific configuration
      #
      # @return [Hash] Telegram configuration hash
      def channel_config
        @config.telegram
      end

      # Initialize Telegram channel
      #
      # @param config [Config] Configuration instance
      # @raise [Error] If bot_token is not configured
      def initialize(config)
        super
        cfg = channel_config
        @bot_token = cfg[:bot_token]
        @allowed_users = cfg[:allowed_users] || []
        @bot = nil
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
            process_message(message.chat.id, message) if message.is_a?(::Telegram::Bot::Types::Message)
          end
        end
      rescue Interrupt
        @logger.info "[Telegram] Shutting down..."
      end

      # Stop the Telegram bot
      def stop
        @logger.info "[Telegram] Stopping bot..."
        # Telegram::Bot::Client doesn't have an explicit stop method,
        # but the run block will exit on interrupt
      end

      # Check if bot is running
      #
      # @return [Boolean] True if bot is running
      def running?
        !@bot.nil?
      end

      # Process an incoming Telegram message
      #
      # @param chat_id [Integer] Telegram chat ID
      # @param message [Telegram::Bot::Types::Message] The full message object
      def process_message(chat_id, message)
        username = message.from&.username
        text = message.text

        unless authorized?(username)
          @logger.warn "[Telegram] Ignored message from unauthorized user @#{username} (chat_id: #{chat_id})"
          return
        end

        @logger.info "[Telegram] Message from @#{username}: #{text}"

        conversation = conversation_for(chat_id.to_s)
        agent = Botiasloop::Agent.new(@config)
        response = agent.chat(text, conversation: conversation, log_start: false)

        send_response(chat_id.to_s, response)
        @logger.info "[Telegram] Response sent to @#{username}"
      rescue => e
        @logger.error "[Telegram] Error processing message: #{e.message}"
      end

      # Check if username is in allowed list
      #
      # @param username [String, nil] Telegram username
      # @return [Boolean] True if allowed
      def authorized?(username)
        return false if username.nil? || @allowed_users.empty?

        @allowed_users.include?(username)
      end

      # Deliver a formatted response to Telegram
      #
      # @param chat_id [String] Telegram chat ID (as string)
      # @param formatted_content [String] Formatted message content
      def deliver_response(chat_id, formatted_content)
        @bot.api.send_message(
          chat_id: chat_id.to_i,
          text: formatted_content,
          parse_mode: "HTML"
        )
      end

      # Format response for Telegram
      #
      # @param content [String] Raw response content
      # @return [String] Telegram-compatible HTML
      def format_response(content)
        return "" if content.nil? || content.empty?

        to_telegram_html(content)
      end

      private

      # Convert Markdown to Telegram-compatible HTML
      #
      # @param markdown [String] Markdown text
      # @return [String] Telegram-compatible HTML
      def to_telegram_html(markdown)
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

      # Convert HTML tables to properly formatted text wrapped in <pre> tags
      def convert_tables(html)
        html.gsub(/<table[^>]*>.*?<\/table>/m) do |table_block|
          # Extract headers (th elements)
          headers = table_block.scan(/<th[^>]*>(.*?)<\/th>/).flatten

          # Extract data rows (td elements within tr elements)
          data_rows = []
          table_block.scan(/<tr[^>]*>(.*?)<\/tr>/m) do |row_match|
            row_html = row_match[0]
            # Skip rows that only contain th elements (header row)
            next if row_html.include?("<th")

            cells = row_html.scan(/<td[^>]*>(.*?)<\/td>/).flatten
            data_rows << cells if cells.any?
          end

          # Calculate column widths (minimum 3 characters)
          num_columns = [headers.length, data_rows.map(&:length).max || 0].max
          col_widths = Array.new(num_columns, 3)

          # Update widths based on header lengths
          headers.each_with_index do |header, i|
            col_widths[i] = [col_widths[i], strip_html_tags(header).length].max
          end

          # Update widths based on data cell lengths
          data_rows.each do |row|
            row.each_with_index do |cell, i|
              col_widths[i] = [col_widths[i], strip_html_tags(cell).length].max
            end
          end

          # Format the table
          lines = []

          # Format header row with bold tags
          formatted_headers = headers.map.with_index do |header, i|
            text = strip_html_tags(header).ljust(col_widths[i])
            "<b>#{text}</b>"
          end
          lines << formatted_headers.join(" ")

          # Format data rows
          data_rows.each do |row|
            formatted_cells = row.map.with_index do |cell, i|
              text = strip_html_tags(cell).ljust(col_widths[i])
              # Convert inline markdown to HTML within cells
              convert_inline_markdown(text)
            end
            lines << formatted_cells.join(" ")
          end

          # Wrap in <pre> tags
          "<pre>#{lines.join("\n")}</pre>"
        end
      end

      # Strip HTML tags from text (helper for width calculation)
      def strip_html_tags(html)
        html.gsub(/<[^>]+>/, "")
      end

      # Convert inline markdown to HTML (for table cell content)
      def convert_inline_markdown(text)
        result = text.dup

        # Bold: **text** -> <strong>text</strong>
        result.gsub!(/\*\*(.+?)\*\*/, '<strong>\1</strong>')

        # Italic: *text* -> <em>text</em>
        result.gsub!(/\*(.+?)\*/, '<em>\1</em>')

        # Code: `text` -> <code>text</code>
        result.gsub!(/`(.+?)`/, '<code>\1</code>')

        # Strikethrough: ~~text~~ -> <del>text</del>
        result.gsub!(/~~(.+?)~~/, '<del>\1</del>')

        result
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

    # Auto-register Telegram channel when file is loaded
    Botiasloop::Channels.registry.register(Telegram)
  end
end
