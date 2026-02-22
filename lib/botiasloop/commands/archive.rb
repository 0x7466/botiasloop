# frozen_string_literal: true

module Botiasloop
  module Commands
    # Archive command - archives a conversation by label or UUID, or current conversation if no args
    class Archive < Base
      command :archive
      description "Archive current conversation (no args) or a specific conversation by label/UUID"

      # Execute the archive command
      # Without args: archives current conversation and creates a new one
      # With args: archives the specified conversation
      #
      # @param context [Context] Execution context
      # @param args [String, nil] Label or UUID to archive (nil = archive current)
      # @return [String] Command response with archived conversation details
      def execute(context, args = nil)
        identifier = args.to_s.strip
        result = ConversationManager.archive(context.user_id, identifier.empty? ? nil : identifier)

        if result[:new_conversation]
          # Archived current and created new
          context.conversation = result[:new_conversation]
          format_archive_current_response(result[:archived], result[:new_conversation])
        else
          # Archived specific conversation
          format_archive_response(result[:archived])
        end
      rescue Botiasloop::Error => e
        "Error: #{e.message}"
      end

      private

      def format_archive_response(conversation)
        lines = ["**Conversation archived successfully**"]
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

      def format_archive_current_response(archived, new_conversation)
        lines = ["**Current conversation archived and new conversation started**"]
        lines << ""
        lines << "Archived:"
        lines << "- UUID: #{archived.uuid}"

        lines << if archived.label?
          "- Label: #{archived.label}"
        else
          "- Label: (no label)"
        end

        count = archived.message_count
        lines << "- Messages: #{count}"

        last = archived.last_activity
        lines << if last
          "- Last activity: #{format_time_ago(last)}"
        else
          "- Last activity: no activity"
        end

        lines << ""
        lines << "New conversation:"
        lines << "- UUID: #{new_conversation.uuid}"
        lines << "- Label: (no label)"

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
