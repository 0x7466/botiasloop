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

        first_message = true

        while @running
          print "You: "
          input = $stdin.gets&.chomp
          break if input.nil? || EXIT_COMMANDS.include?(input.downcase)

          puts
          process_message(SOURCE_ID, input, {first_message: first_message})
          first_message = false
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

      # Process an incoming message
      #
      # @param source_id [String] Source identifier (always "cli")
      # @param content [String] Message content
      # @param metadata [Hash] Additional metadata
      def process_message(source_id, content, metadata = {})
        conversation = conversation_for(source_id)

        # Check for slash commands
        response = if Commands.command?(content)
          context = Commands::Context.new(
            conversation: conversation,
            config: @config,
            channel: self,
            user_id: source_id
          )
          Commands.execute(content, context)
        else
          agent = Agent.new(@config)
          agent.chat(content, conversation: conversation, log_start: metadata[:first_message])
        end

        send_response(source_id, response)
      rescue => e
        @logger.error "[CLI] Error processing message: #{e.message}"
        send_response(source_id, "Error: #{e.message}")
      end

      # Check if source is authorized (CLI is always authorized)
      #
      # @param source_id [String] Source identifier to check
      # @return [Boolean] Always true for CLI
      def authorized?(source_id)
        true
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
