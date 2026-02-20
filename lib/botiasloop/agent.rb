# frozen_string_literal: true

require "ruby_llm"
require "logger"

module Botiasloop
  class Agent
    EXIT_COMMANDS = %w[exit quit \q].freeze

    # Initialize the agent
    #
    # @param config [Config, nil] Configuration instance (loads default if nil)
    def initialize(config = nil)
      @config = config || Config.load
      @logger = Logger.new($stderr)
      setup_ruby_llm
    end

    # Send a message and get a response
    #
    # @param message [String] User message
    # @param conversation [Conversation, nil] Existing conversation
    # @param log_start [Boolean] Whether to log conversation start
    # @return [String] Assistant response
    def chat(message, conversation: nil, log_start: true)
      conversation ||= Conversation.new
      @logger.info "Starting conversation #{conversation.uuid}" if log_start

      chat = create_chat
      registry = create_registry
      loop = Loop.new(chat, registry, max_iterations: @config.max_iterations)

      loop.run(conversation, message)
    end

    # Run in interactive mode
    def interactive
      puts "botiasloop v#{VERSION} - Interactive Mode"
      puts "Type 'exit', 'quit', or '\\q' to exit"
      puts

      conversation = Conversation.new
      first_message = true
      loop do
        print "You: "
        input = gets&.chomp
        break if input.nil? || EXIT_COMMANDS.include?(input.downcase)

        puts
        response = chat(input, conversation: conversation, log_start: first_message)
        first_message = false
        puts "Agent: #{response}"
        puts
      end
    rescue Interrupt
      puts "\nGoodbye!"
    end

    private

    def setup_ruby_llm
      RubyLLM.configure do |config|
        config.openrouter_api_key = @config.api_key
      end
    end

    def create_chat
      RubyLLM.chat(model: @config.model)
    end

    def create_registry
      registry = Tools::Registry.new
      registry.register(Tools::Shell)
      registry.register(Tools::WebSearch, searxng_url: @config.searxng_url)
      registry
    end
  end
end
