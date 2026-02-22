# frozen_string_literal: true

require "sequel"
require "fileutils"

module Botiasloop
  # Database connection and schema management for SQLite
  class Database
    # Default database path
    DEFAULT_PATH = File.expand_path("~/.config/botiasloop/db.sqlite")

    class << self
      # Get or create database connection
      #
      # @return [Sequel::SQLite::Database]
      def connect
        @db ||= Sequel.sqlite(DEFAULT_PATH)
      end

      # Set up database schema
      # Creates tables if they don't exist
      def setup!
        db = connect

        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(DEFAULT_PATH))

        # Create conversations table
        db.create_table?(:conversations) do
          String :id, primary_key: true
          String :user_id, null: false
          String :label
          TrueClass :is_current, default: false
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
          DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

          index [:user_id, :label], unique: true
        end

        # Create messages table
        db.create_table?(:messages) do
          primary_key :id
          String :conversation_id, null: false
          String :role, null: false
          String :content, null: false, text: true
          DateTime :timestamp, default: Sequel::CURRENT_TIMESTAMP
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

          foreign_key [:conversation_id], :conversations, on_delete: :cascade
          index [:conversation_id]
        end
      end

      # Reset database - delete all data
      def reset!
        db = connect
        db[:messages].delete if db.table_exists?(:messages)
        db[:conversations].delete if db.table_exists?(:conversations)
      end

      # Close database connection
      def disconnect
        @db&.disconnect
        @db = nil
      end
    end
  end
end
