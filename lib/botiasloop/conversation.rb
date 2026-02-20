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

    private

    def load_messages
      return [] unless File.exist?(path)

      File.readlines(path).filter_map do |line|
        line.strip.empty? ? nil : JSON.parse(line, symbolize_names: true)
      end
    end

    def persist_messages
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, @messages.map(&:to_json).join("\n"))
    end
  end
end
