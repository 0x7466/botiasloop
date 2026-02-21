# frozen_string_literal: true

require "logger"

module Botiasloop
  module Channels
    class CLI < Base
      channel_name :cli

      EXIT_COMMANDS = %w[exit quit \q].freeze
      SOURCE_ID = "cli"

      # Initialize CLI channel
      #
      # @param config [Config] Configuration instance
      def initialize(config)
        super
        @running = false
      end

      # Start the CLI interactive mode
      def start
        @running = true
        @logger.info "[CLI] Starting interactive mode..."

        puts "botiasloop v#{VERSION} - Interactive Mode"
        puts "Type 'exit', 'quit', or '\\q' to exit"
        puts

        while @running
          print "You: "
          input = $stdin.gets&.chomp
          break if input.nil? || EXIT_COMMANDS.include?(input.downcase)

          puts
          process_message(SOURCE_ID, input)
        end

        @running = false
        @logger.info "[CLI] Interactive mode ended"
      rescue Interrupt
        @running = false
        puts "\nGoodbye!"
        @logger.info "[CLI] Interrupted by user"
      end

      # Stop the CLI channel
      def stop
        @running = false
        @logger.info "[CLI] Stopping..."
      end

      # Check if CLI channel is running
      #
      # @return [Boolean] True if running
      def running?
        @running
      end

      # Extract content from raw message
      # For CLI, the raw message is already the content string
      #
      # @param raw_message [String] Raw message (already a string)
      # @return [String] The content
      def extract_content(raw_message)
        raw_message
      end

      # Check if source is authorized (CLI is always authorized)
      #
      # @param source_id [String] Source identifier to check
      # @return [Boolean] Always true for CLI
      def authorized?(source_id)
        true
      end

      # Handle errors by sending error message to user
      #
      # @param source_id [String] Source identifier
      # @param user_id [String] User ID
      # @param error [Exception] The error that occurred
      # @param raw_message [Object] Raw message object
      def handle_error(source_id, user_id, error, raw_message)
        @logger.error "[CLI] Error processing message: #{error.message}"
        send_response(source_id, "Error: #{error.message}")
      end

      # Deliver a formatted response to the CLI
      #
      # @param source_id [String] Source identifier
      # @param formatted_content [String] Formatted response content
      def deliver_response(source_id, formatted_content)
        puts "Agent: #{formatted_content}"
        puts
      end

      # Auto-register CLI channel when file is loaded
      Botiasloop::Channels.registry.register(CLI)
    end
  end
end
