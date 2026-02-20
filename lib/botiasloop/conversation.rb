# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module Botiasloop
  class Conversation
    # Initialize a conversation
    #
    # @param uuid [String, nil] UUID for the conversation (generates new if nil)
    def initialize(uuid = nil)
      @uuid = uuid || SecureRandom.uuid
    end

    # @return [String] UUID of the conversation
    attr_reader :uuid

    # Add a message to the conversation
    #
    # @param role [String] Role of the message sender (user, assistant, system)
    # @param content [String] Message content
    def add(role, content)
      message = {
        "role" => role,
        "content" => content,
        "timestamp" => Time.now.utc.iso8601
      }

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") do |file|
        file.puts(message.to_json)
      end
    end

    # @return [Array<Hash>] Array of message hashes
    def history
      return [] unless File.exist?(path)

      File.readlines(path).map do |line|
        JSON.parse(line)
      end
    end

    # @return [String] Path to the conversation file
    def path
      File.expand_path("~/conversations/#{@uuid}.jsonl")
    end
  end
end
