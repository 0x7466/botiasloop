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
      @config = config || Config.new
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

      registry = create_registry
      chat = create_chat(registry)
      loop = Loop.new(chat, registry, max_iterations: @config.max_iterations)

      loop.run(conversation, message)
    rescue MaxIterationsExceeded => e
      e.message
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

        # Check for slash commands
        response = if Commands.command?(input)
          context = Commands::Context.new(conversation: conversation, config: @config)
          Commands.execute(input, context)
        else
          chat(input, conversation: conversation, log_start: first_message)
        end

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
        config.openrouter_api_key = @config.providers["openrouter"]["api_key"]
      end
    end

    def create_chat(registry)
      chat = RubyLLM.chat(model: @config.providers["openrouter"]["model"])
      chat.with_instructions(system_prompt(registry))
      chat.with_tool(Tools::Shell)
      chat.with_tool(Tools::WebSearch.new(web_search_url)) if web_search_configured?
      chat
    end

    def create_registry
      registry = Tools::Registry.new
      registry.register(Tools::Shell)
      registry.register(Tools::WebSearch, searxng_url: web_search_url) if web_search_configured?
      registry
    end

    def web_search_configured?
      url = web_search_url
      url && !url.empty?
    end

    def web_search_url
      @config.tools["web_search"]["searxng_url"]
    end

    def system_prompt(registry)
      <<~PROMPT
        You are Botias, an autonomous AI agent.

        Environment:
        - OS: #{RUBY_PLATFORM}
        - Shell: #{ENV.fetch("SHELL", "unknown")}
        - Working Directory: #{Dir.pwd}
        - Date: #{Time.now.strftime("%Y-%m-%d")}
        - Time: #{Time.now.strftime("%H:%M:%S %Z")}

        Available tools:
        #{registry.tool_classes.map { |t| "- #{t.tool_name}: #{t.description}" }.join("\n")}

        You operate in a ReAct loop: Reason about the task, Act using tools, Observe results.
        You have full CLI access via the shell tool. Use standard Unix commands for file operations.
        You can think up to #{@config.max_iterations} times before providing your final answer.
      PROMPT
    end
  end
end
