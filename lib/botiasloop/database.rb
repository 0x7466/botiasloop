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
        db[:chats].delete if db.table_exists?(:chats)
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

        # Create chats table
        db.create_table?(:chats) do
          primary_key :id
          String :channel, null: false
          String :external_id, null: false
          String :user_identifier
          String :current_conversation_id
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
          DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

          index %i[channel external_id], unique: true
        end

        # Create conversations table
        db.create_table?(:conversations) do
          String :id, primary_key: true
          String :label
          TrueClass :archived, default: false
          TrueClass :verbose, default: false
          Integer :input_tokens, default: 0
          Integer :output_tokens, default: 0
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
          DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP

          index :label, unique: true
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
