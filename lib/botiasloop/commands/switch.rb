# frozen_string_literal: true

module Botiasloop
  module Commands
    # Switch command - switches to a different conversation by label or UUID
    class Switch < Base
      command :switch
      description "Switch to a different conversation by label or UUID"

      # Execute the switch command
      #
      # @param context [Context] Execution context
      # @param args [String, nil] Label or UUID to switch to
      # @return [String] Command response with conversation preview
      def execute(context, args = nil)
        identifier = args.to_s.strip

        if identifier.empty?
          return "Usage: /switch <label-or-uuid>"
        end

        new_conversation = ConversationManager.switch(context.user_id, identifier)
        context.conversation = new_conversation

        format_switch_response(new_conversation)
      rescue Botiasloop::Error => e
        "Error: #{e.message}"
      end

      private

      def format_switch_response(conversation)
        lines = ["Switched to conversation:"]
        lines << "- UUID: #{conversation.uuid}"

        lines << if conversation.label?
          "- Label: #{conversation.label}"
        else
          "- Label: (no label)"
        end

        count = conversation.message_count
        lines << "- Messages: #{count}"

        last = conversation.last_activity
        lines << if last
          "- Last activity: #{format_time_ago(last)}"
        else
          "- Last activity: no activity"
        end

        lines.join("\n")
      end

      def format_time_ago(timestamp)
        time = Time.parse(timestamp)
        now = Time.now.utc
        diff = now - time

        if diff < 60
          "just now"
        elsif diff < 3600
          "#{Integer(diff / 60)} minutes ago"
        elsif diff < 86_400
          "#{Integer(diff / 3600)} hours ago"
        elsif diff < 604_800
          "#{Integer(diff / 86_400)} days ago"
        else
          time.strftime("%Y-%m-%d %H:%M UTC")
        end
      rescue ArgumentError
        timestamp
      end
    end
  end
end
