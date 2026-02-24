# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::Database do
  before do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
  end

  describe ".connect" do
    it "connects to the database" do
      db = Botiasloop::Database.connect
      expect(db).to be_a(Sequel::SQLite::Database)
    end

    it "returns a database instance" do
      db = Botiasloop::Database.connect
      expect(db).to be_a(Sequel::SQLite::Database)
      expect(db).to respond_to(:[])
    end
  end

  describe ".setup!" do
    it "creates the conversations table" do
      Botiasloop::Database.setup!
      db = Botiasloop::Database.connect
      expect(db.table_exists?(:conversations)).to be true
    end

    it "creates the messages table" do
      Botiasloop::Database.setup!
      db = Botiasloop::Database.connect
      expect(db.table_exists?(:messages)).to be true
    end

    it "creates the conversations table with correct columns" do
      Botiasloop::Database.setup!
      db = Botiasloop::Database.connect
      schema = db.schema(:conversations)

      columns = schema.map { |col| col.first }
      expect(columns).to include(:id)
      expect(columns).to include(:label)
      expect(columns).to include(:archived)
      expect(columns).to include(:verbose)
      expect(columns).to include(:input_tokens)
      expect(columns).to include(:output_tokens)
      expect(columns).to include(:created_at)
      expect(columns).to include(:updated_at)
    end

    it "creates the messages table with correct columns" do
      Botiasloop::Database.setup!
      db = Botiasloop::Database.connect
      schema = db.schema(:messages)

      columns = schema.map { |col| col.first }
      expect(columns).to include(:id)
      expect(columns).to include(:conversation_id)
      expect(columns).to include(:role)
      expect(columns).to include(:content)
      expect(columns).to include(:timestamp)
      expect(columns).to include(:created_at)
    end
  end

  describe ".reset!" do
    it "clears all data from tables" do
      Botiasloop::Database.setup!
      db = Botiasloop::Database.connect

      # Insert test data
      db[:conversations].insert(id: "test-uuid", label: "test-label", archived: 0)
      db[:messages].insert(conversation_id: "test-uuid", role: "user", content: "hello")

      # Reset
      Botiasloop::Database.reset!

      expect(db[:conversations].count).to eq(0)
      expect(db[:messages].count).to eq(0)
    end
  end
end
