# frozen_string_literal: true

require "json"
require "securerandom"
require "time"
require "fileutils"

module Botiasloop
  class Conversation
    # @return [String] UUID of the conversation
    attr_reader :uuid

    # Initialize a conversation
    #
    # @param uuid [String, nil] UUID for the conversation (generates new if nil)
    def initialize(uuid = nil)
      @uuid = uuid || SecureRandom.uuid
      @messages = load_messages
    end

    # Get the label for this conversation
    #
    # @return [String, nil] Label or nil if not set
    def label
      ConversationManager.label(@uuid)
    end

    # Set the label for this conversation
    #
    # @param value [String] Label value
    # @return [String] The label value
    # @raise [Error] If label format is invalid or already in use
    def label=(value)
      ConversationManager.label(@uuid, value)
    end

    # Check if this conversation has a label
    #
    # @return [Boolean] True if label is set
    def label?
      !label.nil?
    end

    # Add a message to the conversation
    #
    # @param role [String] Role of the message sender (user, assistant, system)
    # @param content [String] Message content
    def add(role, content)
      message = {
        role: role,
        content: content,
        timestamp: Time.now.utc.iso8601
      }

      @messages << message
      persist_messages
    end

    # @return [Array<Hash>] Array of message hashes
    def history
      @messages.dup
    end

    # @return [String] Path to the conversation file
    def path
      File.expand_path("~/conversations/#{@uuid}.jsonl")
    end

    # Reset conversation - clear all messages
    def reset!
      @messages = []

      # Clear the file
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
    end

    # Compact conversation by replacing old messages with a summary
    #
    # @param summary [String] Summary of older messages
    # @param recent_messages [Array<Hash>] Recent messages to keep
    def compact!(summary, recent_messages)
      @messages = []

      # Add summary as system message
      @messages << {
        role: "system",
        content: summary,
        timestamp: Time.now.utc.iso8601
      }

      # Add recent messages
      recent_messages.each do |msg|
        @messages << {
          role: msg[:role],
          content: msg[:content],
          timestamp: Time.now.utc.iso8601
        }
      end

      persist_messages
    end

    private

    def load_messages
      return [] unless File.exist?(path)

      File.readlines(path).filter_map do |line|
        next if line.strip.empty?

        begin
          data = JSON.parse(line, symbolize_names: true)
          data
        rescue JSON::ParserError
          nil
        end
      end
    end

    def persist_messages
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, @messages.map(&:to_json).join("\n"))
    end
  end
end
