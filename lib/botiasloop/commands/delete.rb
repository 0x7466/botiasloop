# frozen_string_literal: true

module Botiasloop
  module Commands
    # Delete command - permanently deletes a conversation by label or ID, or current conversation if "current"
    class Delete < Base
      command :delete
      description "Delete current conversation ('/delete current') or delete a specific conversation by label/ID"

      # Execute the delete command
      # Without args: returns error (must specify 'current' or a label/id)
      # With 'current': deletes current conversation and creates a new one
      # With args: deletes the specified conversation
      #
      # @param context [Context] Execution context
      # @param args [String, nil] 'current', label, or ID to delete
      # @return [String] Command response with deleted conversation details
      def execute(context, args = nil)
        identifier = args.to_s.strip.downcase

        if identifier == "current"
          delete_current_and_create_new(context)
        elsif identifier.empty?
          "Usage: /delete <current|label-or-id>"
        else
          delete_by_identifier(context, identifier)
        end
      rescue Botiasloop::Error => e
        "Error: #{e.message}"
      end

      private

      def delete_current_and_create_new(context)
        current = context.conversation
        result = context.chat.create_new_conversation
        context.conversation = result

        format_delete_current_response(current, result)
      end

      def delete_by_identifier(context, identifier)
        conversation = find_conversation(identifier)
        raise Botiasloop::Error, "Conversation '#{identifier}' not found" unless conversation

        if conversation.id == context.conversation.id
          raise Botiasloop::Error,
            "Cannot delete the current conversation. Use '/delete current' to delete current and start new."
        end

        deleted_info = capture_conversation_info(conversation)
        conversation.delete!
        format_delete_response(deleted_info)
      end

      def find_conversation(identifier)
        conversation = Conversation.find(label: identifier)

        unless conversation
          normalized_id = HumanId.normalize(identifier)
          conversation = Conversation.all.find { |c| HumanId.normalize(c.id) == normalized_id }
        end

        conversation
      end

      def capture_conversation_info(conversation)
        {
          uuid: conversation.uuid,
          label: conversation.label,
          label?: conversation.label?,
          message_count: conversation.message_count,
          last_activity: conversation.last_activity
        }
      end

      def format_delete_response(info)
        lines = ["**Conversation deleted permanently**"]
        lines << "- ID: #{info[:uuid]}"

        lines << if info[:label?]
          "- Label: #{info[:label]}"
        else
          "- Label: (no label)"
        end

        lines << "- Messages: #{info[:message_count]}"

        last = info[:last_activity]
        lines << if last
          "- Last activity: #{format_time_ago(last)}"
        else
          "- Last activity: no activity"
        end

        lines.join("\n")
      end

      def format_delete_current_response(deleted, new_conversation)
        lines = ["**Current conversation deleted and new conversation started**"]
        lines << ""
        lines << "Deleted:"
        lines << "- ID: #{deleted.uuid}"

        lines << if deleted.label?
          "- Label: #{deleted.label}"
        else
          "- Label: (no label)"
        end

        count = deleted.message_count
        lines << "- Messages: #{count}"

        last = deleted.last_activity
        lines << if last
          "- Last activity: #{format_time_ago(last)}"
        else
          "- Last activity: no activity"
        end

        lines << ""
        lines << "New conversation:"
        lines << "- ID: #{new_conversation.uuid}"
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
