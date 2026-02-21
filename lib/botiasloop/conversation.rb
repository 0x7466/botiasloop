# frozen_string_literal: true

require "json"
require "securerandom"
require "time"
require "fileutils"

module Botiasloop
  class Conversation
    # @return [String] UUID of the conversation
    attr_reader :uuid

    # @return [Integer] Total input tokens used
    attr_reader :tokens_in

    # @return [Integer] Total output tokens used
    attr_reader :tokens_out

    # Initialize a conversation
    #
    # @param uuid [String, nil] UUID for the conversation (generates new if nil)
    def initialize(uuid = nil)
      @uuid = uuid || SecureRandom.uuid
      @messages = load_messages
      @tokens_in = 0
      @tokens_out = 0
      load_tokens
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

    # Add token counts to the conversation
    #
    # @param tokens_in [Integer] Number of input tokens to add
    # @param tokens_out [Integer] Number of output tokens to add
    def add_tokens(tokens_in: 0, tokens_out: 0)
      @tokens_in += tokens_in
      @tokens_out += tokens_out
      persist_tokens
    end

    # Reset conversation - clear all messages and tokens
    def reset!
      @messages = []
      @tokens_in = 0
      @tokens_out = 0

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
      @tokens_in = 0
      @tokens_out = 0

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

      persist_compacted
    end

    private

    def load_messages
      return [] unless File.exist?(path)

      File.readlines(path).filter_map do |line|
        next if line.strip.empty?

        begin
          data = JSON.parse(line, symbolize_names: true)
          # Skip metadata lines (token tracking)
          next if data[:metadata]

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

    def load_tokens
      return unless File.exist?(path)

      lines = File.readlines(path)
      return if lines.empty?

      # Tokens are stored in the last line if it's a metadata line
      last_line = lines.last.strip
      return if last_line.empty?

      begin
        data = JSON.parse(last_line, symbolize_names: true)
        if data[:metadata]
          @tokens_in = data[:tokens_in] || 0
          @tokens_out = data[:tokens_out] || 0
        end
      rescue JSON::ParserError
        # If last line isn't valid JSON or doesn't have metadata, ignore
      end
    end

    def persist_tokens
      FileUtils.mkdir_p(File.dirname(path))

      metadata = {
        role: "system",
        content: "token_metadata",
        timestamp: Time.now.utc.iso8601,
        metadata: true,
        tokens_in: @tokens_in,
        tokens_out: @tokens_out
      }

      # Check if there's already a metadata line
      lines = File.exist?(path) ? File.readlines(path) : []

      # Remove existing metadata line if present
      lines = lines.reject do |line|
        data = JSON.parse(line.strip, symbolize_names: true)
        data[:metadata] == true
      rescue JSON::ParserError
        false
      end

      # Add new metadata line
      lines << metadata.to_json

      File.write(path, lines.join(""))
    end

    def persist_compacted
      FileUtils.mkdir_p(File.dirname(path))

      lines = @messages.map(&:to_json)

      # Add metadata line with reset tokens
      metadata = {
        role: "system",
        content: "token_metadata",
        timestamp: Time.now.utc.iso8601,
        metadata: true,
        tokens_in: @tokens_in,
        tokens_out: @tokens_out
      }
      lines << metadata.to_json

      File.write(path, lines.join("\n"))
    end
  end
end
