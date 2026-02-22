# frozen_string_literal: true

module Botiasloop
  module Commands
    # Label command - manages conversation labels
    class Label < Base
      command :label
      description "Set or show conversation label"

      # Execute the label command
      #
      # @param context [Context] Execution context
      # @param args [String, nil] Label value or nil to show current
      # @return [String] Command response
      def execute(context, args = nil)
        conversation = context.conversation
        user_id = context.user_id

        if args.nil? || args.strip.empty?
          # Show current label
          return show_label(conversation)
        end

        # Set label
        label_value = args.strip
        set_label(conversation, user_id, label_value)
      end

      private

      def show_label(conversation)
        if conversation.label?
          "Current label: #{conversation.label}"
        else
          "No label set. Use /label <name> to set one."
        end
      end

      def set_label(conversation, user_id, label_value)
        # Validate label format
        unless label_value.match?(/\A[a-zA-Z0-9_-]+\z/)
          return "Invalid label format. Use only letters, numbers, dashes, and underscores."
        end

        # Check uniqueness per user
        if label_in_use?(user_id, label_value, conversation.uuid)
          return "Label '#{label_value}' already in use by another conversation."
        end

        conversation.label = label_value
        "Label set to: #{label_value}"
      rescue Botiasloop::Error => e
        "Error setting label: #{e.message}"
      end

      def label_in_use?(user_id, label, current_uuid)
        return false if user_id.nil?

        existing_uuid = ConversationManager.find_by_label(user_id, label)
        existing_uuid && existing_uuid != current_uuid
      end
    end
  end
end
