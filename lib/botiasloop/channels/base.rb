# frozen_string_literal: true

require "json"
require "fileutils"
require "logger"

module Botiasloop
  module Channels
    class Base
      class << self
        attr_writer :channel_identifier

        # Get or set the channel identifier
        # @param name [Symbol] Channel identifier (e.g., :telegram)
        # @return [Symbol] The channel identifier
        def channel_name(name = nil)
          if name
            @channel_identifier = name
          end
          @channel_identifier
        end

        alias_method :channel_identifier, :channel_name

        # Declare required configuration keys
        # @param keys [Array<Symbol>] Required configuration keys
        def requires_config(*keys)
          @required_config_keys ||= []
          @required_config_keys.concat(keys) if keys.any?
          @required_config_keys
        end

        # Get required configuration keys
        # @return [Array<Symbol>] Required configuration keys
        def required_config_keys
          @required_config_keys ||= []
        end
      end

      # Initialize the channel
      #
      # @param config [Config] Configuration instance
      # @raise [Error] If required configuration is missing
      def initialize(config)
        @config = config
        @logger = Logger.new($stderr)
        @conversations = load_conversations

        validate_required_config!
      end

      # Get channel-specific configuration
      # Override in subclasses for custom config access
      #
      # @return [Hash] Channel configuration hash
      def channel_config
        @config.channels[self.class.channel_identifier.to_s] || {}
      end

      # Start the channel and begin listening for messages
      # @raise [NotImplementedError] Subclass must implement
      def start
        raise NotImplementedError, "Subclass must implement #start"
      end

      # Stop the channel and cleanup
      # @raise [NotImplementedError] Subclass must implement
      def stop
        raise NotImplementedError, "Subclass must implement #stop"
      end

      # Check if the channel is currently running
      # @return [Boolean] True if running
      # @raise [NotImplementedError] Subclass must implement
      def running?
        raise NotImplementedError, "Subclass must implement #running?"
      end

      # Process an incoming message
      #
      # @param source_id [String] Unique identifier for the message source (e.g., chat_id, user_id)
      # @param content [String] Message content
      # @param metadata [Hash] Additional metadata about the message
      # @raise [NotImplementedError] Subclass must implement
      def process_message(source_id, content, metadata = {})
        raise NotImplementedError, "Subclass must implement #process_message"
      end

      # Check if a source is authorized to use this channel
      #
      # @param source_id [String] Source identifier to check
      # @return [Boolean] False by default (secure default)
      def authorized?(source_id)
        false
      end

      # Get or create a conversation for a source
      #
      # @param source_id [String] Source identifier
      # @return [Conversation] Conversation instance
      def conversation_for(source_id)
        source_key = source_id.to_s

        if @conversations[source_key]
          Conversation.new(@conversations[source_key])
        else
          conversation = Conversation.new
          @conversations[source_key] = conversation.uuid
          save_conversations
          conversation
        end
      end

      # Format a response for this channel
      #
      # @param content [String] Raw response content
      # @return [String] Formatted response
      def format_response(content)
        content
      end

      # Send a response to a source
      #
      # @param source_id [String] Source identifier
      # @param response [String] Response content
      def send_response(source_id, response)
        formatted = format_response(response)
        deliver_response(source_id, formatted)
      end

      # Deliver a formatted response to a source
      #
      # @param source_id [String] Source identifier
      # @param formatted_content [String] Formatted response content
      # @raise [NotImplementedError] Subclass must implement
      def deliver_response(source_id, formatted_content)
        raise NotImplementedError, "Subclass must implement #deliver_response"
      end

      private

      def validate_required_config!
        required_keys = self.class.required_config_keys
        return if required_keys.empty?

        cfg = channel_config
        missing_keys = required_keys.reject do |key|
          str_key = key.to_s
          cfg.key?(str_key) && !cfg[str_key].nil? && cfg[str_key] != ""
        end

        return if missing_keys.empty?

        raise Error, "#{self.class.channel_identifier}: Missing required configuration: #{missing_keys.join(", ")}"
      end

      def chats_file_path
        config_dir = File.expand_path("~/.config/botiasloop")
        File.join(config_dir, "channels", "#{self.class.channel_identifier}_chats.json")
      end

      def load_conversations
        file_path = chats_file_path
        return {} unless File.exist?(file_path)

        data = JSON.parse(File.read(file_path), symbolize_names: true)
        conversations = data[:conversations] || {}
        # Convert symbol keys back to strings for consistent access
        conversations.transform_keys(&:to_s)
      rescue JSON::ParserError
        {}
      end

      def save_conversations
        file_path = chats_file_path
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, JSON.pretty_generate({conversations: @conversations}))
      end
    end
  end
end
