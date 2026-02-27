# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::HumanId do
  before do
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end

  describe ".generate" do
    it "generates an ID in the format word-word-XXX" do
      id = described_class.generate
      expect(id).to match(/\A[a-z]+(-[a-z]+)+-[0-9]{3}\z/)
    end

    it "generates unique IDs" do
      ids = 10.times.map { described_class.generate }
      expect(ids.uniq.length).to eq(10)
    end
  end

  describe ".normalize" do
    it "converts to lowercase" do
      expect(described_class.normalize("Blue-Dog-123")).to eq("blue-dog-123")
    end

    it "strips whitespace" do
      expect(described_class.normalize("  blue-dog-123  ")).to eq("blue-dog-123")
    end

    it "handles nil" do
      expect(described_class.normalize(nil)).to eq("")
    end

    it "handles empty string" do
      expect(described_class.normalize("")).to eq("")
    end
  end

  describe ".exists?" do
    it "returns true if ID exists in database" do
      Botiasloop::Conversation.create(id: "green-bird-456")
      expect(described_class.exists?("green-bird-456")).to be true
    end

    it "returns false if ID does not exist" do
      expect(described_class.exists?("nonexistent-id-999")).to be false
    end

    it "is case insensitive" do
      Botiasloop::Conversation.create(id: "purple-fish-789")
      expect(described_class.exists?("PURPLE-FISH-789")).to be true
    end
  end
end
