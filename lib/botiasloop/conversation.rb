# frozen_string_literal: true

require "time"

module Botiasloop
  # Conversation model - represents a chat conversation with messages
  # Direct Sequel model with all database and business logic combined
  class Conversation < Sequel::Model(:conversations)
    # Valid label format: alphanumeric, dashes, and underscores
    LABEL_REGEX = /\A[a-zA-Z0-9_-]+\z/

    # Message model nested within Conversation namespace
    class Message < Sequel::Model(:messages)
      plugin :validation_helpers
      plugin :timestamps, update_on_create: true

      many_to_one :conversation, class: "Botiasloop::Conversation", key: :conversation_id

      # Validations
      def validate
        super
        validates_presence %i[conversation_id role content]
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

    # Auto-generate human-readable ID before creation if not provided
    def before_create
      self.id ||= HumanId.generate
      super
    end

    # Validations
    def validate
      super

      return unless label && !label.to_s.empty?

      validates_format LABEL_REGEX, :label,
        message: "Invalid label format. Use only letters, numbers, dashes, and underscores."
      validates_unique :label, message: "Label '#{label}' already in use by another conversation"
    end

    # Check if this conversation has a label
    #
    # @return [Boolean] True if label is set
    def label?
      !label.nil? && !label.to_s.empty?
    end

    # Check if this conversation is archived
    #
    # @return [Boolean] True if archived
    def archived?
      archived == true
    end

    # Set the label for this conversation
    #
    # @param value [String] Label value
    def label=(value)
      # Allow empty string to be treated as nil (clearing the label)
      value = nil if value.to_s.empty?
      super
    end

    # Archive this conversation
    #
    # @return [Conversation] self
    def archive!
      update(archived: true)
      self
    end

    # Delete this conversation permanently
    # Also deletes all associated messages via cascade
    #
    # @return [void]
    def delete!
      messages_dataset.delete
      delete
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

    # @return [String] Human-readable ID of the conversation
    def uuid
      # Return existing id or generate a new one for unsaved records
      self.id ||= HumanId.generate
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

      prompt += build_operator_section
      prompt += build_identity_section

      prompt
    end

    private

    def build_identity_section
      path = File.expand_path("~/IDENTITY.md")
      content = File.exist?(path) ? File.read(path).strip : nil

      section = "\n\nIDENTITY.md\nDefines who you are - your name, personality, and how you behave.\n\n"

      if content && !content.empty?
        section += "#{content}\n\n"
        section += "You can update ~/IDENTITY.md when the operator wants you to act differently or call you differently (eg. 'Be more concise from now on')."
      elsif content && content.empty?
        section += "CRITICAL: This file is empty. After setting up OPERATOR.md, ask the operator:\n\n"
        section += "1. What name should I use for myself?\n"
        section += "2. How formal or casual should I be?\n"
        section += "3. Should I be concise or detailed in responses?\n"
        section += "4. Any other personality preferences?\n\n"
        section += "Then create ~/IDENTITY.md with this information."
      else
        section += "CRITICAL: This file does not exist. After setting up OPERATOR.md, ask the operator:\n\n"
        section += "1. What name should I use for myself?\n"
        section += "2. How formal or casual should I be?\n"
        section += "3. Should I be concise or detailed in responses?\n"
        section += "4. Any other personality preferences?\n\n"
        section += "Then create ~/IDENTITY.md with: `cat > ~/IDENTITY.md << 'EOF'\n[content here]\nEOF`"
      end

      section
    end

    def build_operator_section
      path = File.expand_path("~/OPERATOR.md")
      content = File.exist?(path) ? File.read(path).strip : nil

      section = "\n\nOPERATOR.md\nInformation about the operator - their preferences, context, background, and more.\n\n"

      if content && !content.empty?
        section += "#{content}\n\n"
        section += "You can update ~/OPERATOR.md when you learn something new about the operator (eg. their name, birthday, what they like, etc.)."
      elsif content && content.empty?
        section += "CRITICAL: This file is empty. Before helping with other tasks, you MUST:\n\n"
        section += "1. Ask the operator their name\n"
        section += "2. Ask their location and timezone\n"
        section += "3. Ask their preferred language\n"
        section += "4. Ask about their interests, hobbies, or work\n"
        section += "5. Ask any relevant personal context they're comfortable sharing (birthday, family, etc.)\n\n"
        section += "Then create ~/OPERATOR.md with this information."
      else
        section += "CRITICAL: This file does not exist. Before helping with other tasks, you MUST:\n\n"
        section += "1. Ask the operator their name\n"
        section += "2. Ask their location and timezone\n"
        section += "3. Ask their preferred language\n"
        section += "4. Ask about their interests, hobbies, or work\n"
        section += "5. Ask any relevant personal context they're comfortable sharing (birthday, family, etc.)\n\n"
        section += "Then create ~/OPERATOR.md with: `cat > ~/OPERATOR.md << 'EOF'\n[content here]\nEOF`"
      end

      section
    end
  end
end
