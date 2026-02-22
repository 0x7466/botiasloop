# frozen_string_literal: true

require "securerandom"
require "time"

module Botiasloop
  # Conversation model - represents a chat conversation with messages
  # Direct Sequel model with all database and business logic combined
  class Conversation < Sequel::Model(:conversations)
    # Message model nested within Conversation namespace
    class Message < Sequel::Model(:messages)
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      many_to_one :conversation, class: "Botiasloop::Conversation", key: :conversation_id

      # Validations
      def validate
        super
        validates_presence [:conversation_id, :role, :content]
      end

      # Convert message to hash for API compatibility
      # @return [Hash] Message as hash with symbol keys
      def to_hash
        {
          role: role,
          content: content,
          input_tokens: input_tokens || 0,
          output_tokens: output_tokens || 0,
          timestamp: timestamp.iso8601
        }
      end
    end

    one_to_many :messages, class: "Botiasloop::Conversation::Message", key: :conversation_id

    # Set up validations and hooks
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true

    # Allow setting primary key (id) for UUID
    unrestrict_primary_key

    # Auto-generate UUID before creation if not provided
    def before_create
      self.id ||= SecureRandom.uuid
      super
    end

    # Validations
    def validate
      super
      validates_presence [:user_id]

      if label && !label.to_s.empty?
        validates_format ConversationManager::LABEL_REGEX, :label, message: "Invalid label format. Use only letters, numbers, dashes, and underscores."
        validates_unique [:user_id, :label], message: "Label '#{label}' already in use by another conversation"
      end
    end

    # Check if this conversation has a label
    #
    # @return [Boolean] True if label is set
    def label?
      !label.nil? && !label.to_s.empty?
    end

    # Get the timestamp of the last activity in the conversation
    #
    # @return [String, nil] ISO8601 timestamp of last message, or nil if no messages
    def last_activity
      return nil if messages.empty?

      messages_dataset.order(:timestamp).last.timestamp.utc.iso8601
    end

    # Get the number of messages in the conversation
    #
    # @return [Integer] Message count
    def message_count
      messages.count
    end

    # Get total tokens (input + output) for the conversation
    #
    # @return [Integer] Total token count
    def total_tokens
      (input_tokens || 0) + (output_tokens || 0)
    end

    # Add a message to the conversation
    #
    # @param role [String] Role of the message sender (user, assistant, system)
    # @param content [String] Message content
    # @param input_tokens [Integer] Input tokens for this message (prompt tokens sent to LLM)
    # @param output_tokens [Integer] Output tokens for this message (completion tokens from LLM)
    def add(role, content, input_tokens: 0, output_tokens: 0)
      Message.create(
        conversation_id: id,
        role: role,
        content: content,
        input_tokens: input_tokens || 0,
        output_tokens: output_tokens || 0,
        timestamp: Time.now.utc
      )

      # Update conversation token totals
      update_token_totals(input_tokens, output_tokens)
    end

    # Update conversation-level token totals
    #
    # @param input_tokens [Integer] Input tokens to add
    # @param output_tokens [Integer] Output tokens to add
    def update_token_totals(input_tokens, output_tokens)
      self.input_tokens = (self.input_tokens || 0) + (input_tokens || 0)
      self.output_tokens = (self.output_tokens || 0) + (output_tokens || 0)
      save if modified?
    end

    # Get conversation history as array of message hashes
    #
    # @return [Array<Hash>] Array of message hashes with role, content, timestamp
    def history
      messages_dataset.order(:timestamp).map(&:to_hash)
    end

    # @return [String] UUID of the conversation
    def uuid
      # Return existing id or generate a new one for unsaved records
      self.id ||= SecureRandom.uuid
    end

    # Reset conversation - clear all messages and reset token counts
    def reset!
      messages_dataset.delete
      self.input_tokens = 0
      self.output_tokens = 0
      save
    end

    # Compact conversation by replacing old messages with a summary
    #
    # @param summary [String] Summary of older messages
    # @param recent_messages [Array<Hash>] Recent messages to keep
    def compact!(summary, recent_messages)
      reset!
      add("system", summary)
      recent_messages.each do |msg|
        add(msg[:role], msg[:content])
      end
    end

    # Generate the system prompt for this conversation
    # Includes current date/time and environment info
    #
    # @return [String] System prompt
    def system_prompt
      skills_registry = Skills::Registry.new

      prompt = <<~PROMPT
        You are Botias, an autonomous AI agent.

        Environment:
        - OS: #{RUBY_PLATFORM}
        - Shell: #{ENV.fetch("SHELL", "unknown")}
        - Working Directory: #{Dir.pwd}
        - Date: #{Time.now.strftime("%Y-%m-%d")}
        - Time: #{Time.now.strftime("%H:%M:%S %Z")}

        You operate in a ReAct loop: Reason about the task, Act using tools, Observe results.
      PROMPT

      if skills_registry.skills.any?
        prompt += <<~SKILLS

          Available Skills:
          #{skills_registry.skills_table}

          To use a skill, read its SKILL.md file at the provided path using the shell tool (e.g., `cat ~/skills/skill-name/SKILL.md`).
          Skills follow progressive disclosure: only metadata is shown above. Full instructions are loaded on demand.
        SKILLS
      end

      prompt
    end
  end
end
