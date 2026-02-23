# frozen_string_literal: true

require "ruby_llm"
require "logger"

module Botiasloop
  # Service class for automatically generating conversation labels
  # Triggered after 3rd user message if no label is set
  class AutoLabel
    MIN_MESSAGES_FOR_AUTO_LABEL = 6 # 3 user + 3 assistant messages

    # Generate a label for the conversation if conditions are met
    #
    # @param conversation [Conversation] The conversation to label
    # @param config [Config] Configuration instance
    # @return [String, nil] The generated label or nil if not applicable
    def self.generate(conversation, config)
      return nil unless should_generate?(conversation, config)

      label = new(config).generate_label(conversation)

      if label
        logger = Logger.new($stderr)
        logger.info "[AutoLabel] Generated label '#{label}' for conversation #{conversation.uuid}"
      end

      label
    end

    # Check if auto-labelling should run
    #
    # @param conversation [Conversation] The conversation to check
    # @param config [Config] Configuration instance
    # @return [Boolean] True if conditions are met
    def self.should_generate?(conversation, config)
      return false unless config.features&.dig("auto_labelling", "enabled") != false
      return false if conversation.label?
      return false if conversation.message_count < MIN_MESSAGES_FOR_AUTO_LABEL

      true
    end

    def initialize(config)
      @config = config
    end

    # Generate a label based on conversation content
    #
    # @param conversation [Conversation] The conversation to label
    # @return [String, nil] The generated and formatted label
    def generate_label(conversation)
      messages = conversation.history
      raw_label = generate_label_text(messages)
      return nil unless raw_label

      formatted_label = format_label(raw_label)
      return nil unless valid_label?(formatted_label)

      formatted_label
    end

    private

    def generate_label_text(messages)
      chat = create_chat

      conversation_text = messages.first(MIN_MESSAGES_FOR_AUTO_LABEL).map do |msg|
        "#{msg[:role]}: #{msg[:content]}"
      end.join("\n\n")

      prompt = <<~PROMPT
        Based on the following conversation, generate a short label (1-2 words) that describes the topic.
        Use lowercase letters only. If two words, separate them with a dash (-).
        Examples: "coding-help", "travel-planning", "recipe-ideas", "debugging"

        Conversation:
        #{conversation_text}

        Label (respond with just the label, nothing else):
      PROMPT

      chat.add_message(role: :user, content: prompt)
      response = chat.complete

      response.content&.strip
    rescue
      nil
    end

    def create_chat
      label_config = @config.features["auto_labelling"] || {}

      if label_config["model"]
        RubyLLM.chat(model: label_config["model"])
      else
        default_model = @config.providers["openrouter"]["model"]
        RubyLLM.chat(model: default_model)
      end
    end

    def format_label(raw_label)
      # Remove non-alphanumeric characters except dashes, underscores, and spaces
      cleaned = raw_label.gsub(/[^a-zA-Z0-9\s\-_]/, "")

      # Split into words (by whitespace only, preserve underscores in words)
      words = cleaned.split(/\s+/).reject(&:empty?)

      # Take max 2 words
      words = words.first(2)

      # Join with dash, lowercase
      words.join("-").downcase
    end

    def valid_label?(label)
      return false if label.nil? || label.empty?
      return false unless label.match?(ConversationManager::LABEL_REGEX)

      true
    end
  end
end
