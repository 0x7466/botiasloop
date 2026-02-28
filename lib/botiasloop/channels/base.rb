# frozen_string_literal: true

require "json"
require "fileutils"

module Botiasloop
  module Channels
    class Base
      class << self
        attr_writer :channel_identifier

        # Get or set the channel identifier
        # @param name [Symbol] Channel identifier (e.g., :telegram)
        # @return [Symbol] The channel identifier
        def channel_name(name = nil)
          @channel_identifier = name if name
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
      # @raise [Error] If required configuration is missing
      def initialize
        validate_required_config!
      end

      # Get channel-specific configuration
      # Override in subclasses for custom config access
      #
      # @return [Hash] Channel configuration hash
      def channel_config
        Config.instance.channels[self.class.channel_identifier.to_s] || {}
      end

      # Get the channel type string (e.g., "telegram", "cli")
      # Override in subclasses if needed
      #
      # @return [String] Channel type string
      def channel_type
        self.class.channel_identifier.to_s
      end

      # Start the channel and begin listening for messages
      # @raise [NotImplementedError] Subclass must implement
      def start_listening
        raise NotImplementedError, "Subclass must implement #start_listening"
      end

      # Stop the channel and cleanup
      # @raise [NotImplementedError] Subclass must implement
      def stop_listening
        raise NotImplementedError, "Subclass must implement #stop_listening"
      end

      # Check if the channel is currently running
      # @return [Boolean] True if running
      # @raise [NotImplementedError] Subclass must implement
      def running?
        raise NotImplementedError, "Subclass must implement #running?"
      end

      # Process an incoming message using template method pattern
      #
      # @param source_id [String] Unique identifier for the message source (e.g., chat_id, user_id)
      # @param raw_message [Object] Raw message object (varies by channel)
      # @param metadata [Hash] Additional metadata about the message
      def process_message(source_id, raw_message, _metadata = {})
        # Hook: Extract content from raw message
        content = extract_content(raw_message)
        return if content.nil? || content.to_s.empty?

        # Hook: Extract user ID for authorization
        user_id = extract_user_id(source_id, raw_message)

        # Authorization check
        unless authorized?(user_id)
          handle_unauthorized(source_id, user_id, raw_message)
          return
        end

        # Hook: Pre-processing
        before_process(source_id, user_id, content, raw_message)

        # Stop any previous typing indicator when new message arrives
        stop_typing(source_id)

        # Core processing logic
        chat = chat_for(source_id, user_identifier: user_id)
        conversation = chat.current_conversation

        if Commands.command?(content)
          context = Commands::Context.new(
            conversation: conversation,
            chat: chat,
            channel: self,
            user_id: source_id
          )
          response = Commands.execute(content, context)
          send_message(source_id, response)
        else
          callback = proc { |message| send_message(source_id, message) }
          error_callback = proc { |error| send_message(source_id, "Error: #{error}") }
          completion_callback = proc { stop_typing(source_id) }
          start_typing(source_id)
          Agent.chat(content, callback: callback, error_callback: error_callback,
            completion_callback: completion_callback, chat: chat)
        end

        # Hook: Post-processing
        after_process(source_id, user_id, nil, raw_message)
      rescue => e
        handle_error(source_id, user_id, e, raw_message)
      end

      # Extract content from raw message. Subclasses must implement.
      #
      # @param raw_message [Object] Raw message object
      # @return [String] Extracted message content
      # @raise [NotImplementedError] Subclass must implement
      def extract_content(raw_message)
        raise NotImplementedError, "Subclass must implement #extract_content"
      end

      # Extract user ID from raw message for authorization
      # Override in subclasses if user ID differs from source_id
      #
      # @param source_id [String] Source identifier
      # @param raw_message [Object] Raw message object
      # @return [String] User ID for authorization
      def extract_user_id(source_id, _raw_message)
        source_id
      end

      # Hook called before processing a message
      # Override in subclasses for custom pre-processing (e.g., logging)
      #
      # @param source_id [String] Source identifier
      # @param user_id [String] User ID
      # @param content [String] Message content
      # @param raw_message [Object] Raw message object
      def before_process(source_id, user_id, content, raw_message)
        # No-op by default
      end

      # Hook called after processing a message
      # Override in subclasses for custom post-processing (e.g., logging)
      #
      # @param source_id [String] Source identifier
      # @param user_id [String] User ID
      # @param response [String] Response content
      # @param raw_message [Object] Raw message object
      def after_process(source_id, user_id, response, raw_message)
        # No-op by default
      end

      # Start typing indicator for a source
      # Override in subclasses to show "user is typing" indicator
      #
      # @param source_id [String] Source identifier
      def start_typing(_source_id)
        # No-op by default
      end

      # Stop typing indicator for a source
      # Override in subclasses to hide "user is typing" indicator
      #
      # @param source_id [String] Source identifier
      def stop_typing(_source_id)
        # No-op by default
      end

      # Handle unauthorized access
      # Override in subclasses for custom unauthorized handling
      #
      # @param source_id [String] Source identifier
      # @param user_id [String] User ID that was denied
      # @param raw_message [Object] Raw message object
      def handle_unauthorized(source_id, user_id, _raw_message)
        Logger.warn "[#{self.class.channel_identifier}] Unauthorized access from #{user_id} (source: #{source_id})"
      end

      # Handle errors during message processing
      # Override in subclasses for custom error handling
      #
      # @param source_id [String] Source identifier
      # @param user_id [String] User ID
      # @param error [Exception] The error that occurred
      # @param raw_message [Object] Raw message object
      def handle_error(_source_id, _user_id, error, _raw_message)
        Logger.error "[#{self.class.channel_identifier}] Error processing message: #{error.message}"
        raise error
      end

      # Check if a source is authorized to use this channel
      #
      # @param source_id [String] Source identifier to check
      # @return [Boolean] False by default (secure default)
      def authorized?(_source_id)
        false
      end

      # Get or create a chat for a source
      #
      # @param source_id [String] Source identifier
      # @param user_identifier [String, nil] Optional user identifier (e.g., username)
      # @return [Chat] Chat instance
      def chat_for(source_id, user_identifier: nil)
        Chat.find_or_create(channel_type, source_id, user_identifier: user_identifier)
      end

      # Format a message for this channel
      #
      # @param content [String] Raw message content
      # @return [String] Formatted message
      def format_message(content)
        content
      end

      # Send a message to a source
      #
      # @param source_id [String] Source identifier
      # @param message [String] Message content
      def send_message(source_id, message)
        formatted = format_message(message)
        deliver_message(source_id, formatted)
      end

      # Deliver a formatted message to a source
      #
      # @param source_id [String] Source identifier
      # @param formatted_content [String] Formatted message content
      # @raise [NotImplementedError] Subclass must implement
      def deliver_message(source_id, formatted_content)
        raise NotImplementedError, "Subclass must implement #deliver_message"
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
    end
  end
end
