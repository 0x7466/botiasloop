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
      # Automatically sets up schema on first connection
      #
      # @return [Sequel::SQLite::Database]
      def connect
        @db ||= begin
          db = Sequel.sqlite(DEFAULT_PATH)
          setup_schema!(db)
          db
        end
      end

      # Set up database schema
      # Creates tables if they don't exist
      def setup!
        db = @db || connect
        setup_schema!(db)
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

      private

      # Set up database schema on a connection
      # Creates tables if they don't exist
      #
      # @param db [Sequel::SQLite::Database] Database connection
      def setup_schema!(db)
        # Ensure directory exists
        FileUtils.mkdir_p(File.dirname(DEFAULT_PATH))

        # Create conversations table
        db.create_table?(:conversations) do
          String :id, primary_key: true
          String :user_id, null: false
          String :label
          TrueClass :is_current, default: false
          TrueClass :archived, default: false
          Integer :input_tokens, default: 0
          Integer :output_tokens, default: 0
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
          DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

          index [:user_id, :label], unique: true
          index [:user_id, :archived]
        end

        # Create messages table
        db.create_table?(:messages) do
          primary_key :id
          String :conversation_id, null: false
          String :role, null: false
          String :content, null: false, text: true
          Integer :input_tokens, default: 0
          Integer :output_tokens, default: 0
          DateTime :timestamp, default: Sequel::CURRENT_TIMESTAMP
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

          foreign_key [:conversation_id], :conversations, on_delete: :cascade
          index [:conversation_id]
        end
      end
    end
  end
end

# Establish database connection when models are loaded
# This ensures Sequel models have a valid database connection
Botiasloop::Database.connect
