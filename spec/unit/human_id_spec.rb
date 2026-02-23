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

    it "retries when ID already exists in database" do
      # Create a conversation with a specific ID
      existing_id = "blue-dog-123"
      Botiasloop::Conversation.create(user_id: "test", id: existing_id)

      # Stub FFaker to return the same values to force a collision
      allow(FFaker::Color).to receive(:name).and_return("blue")
      allow(FFaker::AnimalUS).to receive(:common_name).and_return("dog")
      allow(described_class).to receive(:rand).with(100..999).and_return(123, 456)

      # Should retry and generate a different ID
      new_id = described_class.generate
      expect(new_id).not_to eq(existing_id)
      expect(new_id).to match(/\A[a-z]+-[a-z]+-[0-9]{3}\z/)
    end

    it "raises error after maximum retries" do
      # Create conversations to consume all possible IDs for a color-animal combo
      allow(FFaker::Color).to receive(:name).and_return("red")
      allow(FFaker::AnimalUS).to receive(:common_name).and_return("cat")

      # Create all possible IDs for red-cat-XXX
      (100..999).each do |num|
        Botiasloop::Conversation.create(user_id: "test", id: "red-cat-#{num}")
      end

      expect { described_class.generate }.to raise_error(Botiasloop::Error, /Failed to generate unique ID/)
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
      Botiasloop::Conversation.create(user_id: "test", id: "green-bird-456")
      expect(described_class.exists?("green-bird-456")).to be true
    end

    it "returns false if ID does not exist" do
      expect(described_class.exists?("nonexistent-id-999")).to be false
    end

    it "is case insensitive" do
      Botiasloop::Conversation.create(user_id: "test", id: "purple-fish-789")
      expect(described_class.exists?("PURPLE-FISH-789")).to be true
    end
  end
end
