# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

RSpec.describe Botiasloop::ConversationManager do
  let(:temp_dir) { Dir.mktmpdir("botiasloop_test") }

  before do
    allow(described_class).to receive(:mapping_file).and_return(File.join(temp_dir, "conversations.json"))
    described_class.clear_all
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe ".current_for" do
    context "when user has no existing conversation" do
      it "creates a new conversation" do
        conversation = described_class.current_for("user123")
        expect(conversation).to be_a(Botiasloop::Conversation)
        expect(conversation.uuid).to be_a(String)
      end

      it "stores the mapping" do
        conversation = described_class.current_for("user123")
        uuid = described_class.current_uuid_for("user123")
        expect(uuid).to eq(conversation.uuid)
      end

      it "saves to persistent storage" do
        described_class.current_for("user123")
        mapping_file = File.join(temp_dir, "conversations.json")
        expect(File.exist?(mapping_file)).to be true

        saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
        expect(saved_data[:conversations]).to have_key(:user123)
      end
    end

    context "when user already has a conversation" do
      before do
        described_class.switch("user123", "existing-uuid")
      end

      it "returns existing conversation" do
        conversation = described_class.current_for("user123")
        expect(conversation.uuid).to eq("existing-uuid")
      end

      it "does not create a new conversation" do
        expect(Botiasloop::Conversation).not_to receive(:new).with(no_args)
        described_class.current_for("user123")
      end
    end

    it "handles different users independently" do
      conversation1 = described_class.current_for("user1")
      conversation2 = described_class.current_for("user2")

      expect(conversation1.uuid).not_to eq(conversation2.uuid)
      expect(described_class.current_uuid_for("user1")).to eq(conversation1.uuid)
      expect(described_class.current_uuid_for("user2")).to eq(conversation2.uuid)
    end
  end

  describe ".switch" do
    it "switches user to the specified conversation uuid" do
      described_class.switch("user123", "new-uuid")
      expect(described_class.current_uuid_for("user123")).to eq("new-uuid")
    end

    it "returns the switched-to conversation" do
      conversation = described_class.switch("user123", "new-uuid")
      expect(conversation).to be_a(Botiasloop::Conversation)
      expect(conversation.uuid).to eq("new-uuid")
    end

    it "persists the switch" do
      described_class.switch("user123", "persisted-uuid")
      mapping_file = File.join(temp_dir, "conversations.json")
      saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
      expect(saved_data[:conversations][:user123]).to eq("persisted-uuid")
    end

    it "overwrites existing mapping" do
      described_class.switch("user123", "first-uuid")
      described_class.switch("user123", "second-uuid")
      expect(described_class.current_uuid_for("user123")).to eq("second-uuid")
    end
  end

  describe ".create_new" do
    before do
      allow(SecureRandom).to receive(:uuid).and_return("new-generated-uuid")
    end

    it "creates a new conversation" do
      conversation = described_class.create_new("user123")
      expect(conversation).to be_a(Botiasloop::Conversation)
      expect(conversation.uuid).to eq("new-generated-uuid")
    end

    it "switches user to the new conversation" do
      described_class.create_new("user123")
      expect(described_class.current_uuid_for("user123")).to eq("new-generated-uuid")
    end

    it "returns the new conversation" do
      conversation = described_class.create_new("user123")
      expect(conversation.uuid).to eq("new-generated-uuid")
    end

    it "overwrites existing mapping" do
      described_class.switch("user123", "old-uuid")
      described_class.create_new("user123")
      expect(described_class.current_uuid_for("user123")).to eq("new-generated-uuid")
    end
  end

  describe ".current_uuid_for" do
    it "returns nil when user has no conversation" do
      expect(described_class.current_uuid_for("unknown_user")).to be_nil
    end

    it "returns the uuid when user has a conversation" do
      described_class.switch("user123", "test-uuid")
      expect(described_class.current_uuid_for("user123")).to eq("test-uuid")
    end
  end

  describe ".all_mappings" do
    it "returns empty hash when no mappings exist" do
      expect(described_class.all_mappings).to eq({})
    end

    it "returns all user-to-conversation mappings" do
      described_class.switch("user1", "uuid1")
      described_class.switch("user2", "uuid2")

      mappings = described_class.all_mappings
      expect(mappings).to eq({"user1" => "uuid1", "user2" => "uuid2"})
    end

    it "returns a copy of mappings" do
      described_class.switch("user1", "uuid1")
      mappings = described_class.all_mappings
      mappings["user2"] = "uuid2"

      # Original should be unchanged
      expect(described_class.all_mappings).to eq({"user1" => "uuid1"})
    end
  end

  describe ".remove" do
    it "removes the user's conversation mapping" do
      described_class.switch("user123", "test-uuid")
      described_class.remove("user123")
      expect(described_class.current_uuid_for("user123")).to be_nil
    end

    it "persists the removal" do
      described_class.switch("user123", "test-uuid")
      described_class.remove("user123")

      mapping_file = File.join(temp_dir, "conversations.json")
      saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
      expect(saved_data[:conversations]).not_to have_key(:user123)
    end

    it "handles removing non-existent user gracefully" do
      expect { described_class.remove("non_existent_user") }.not_to raise_error
    end
  end

  describe ".clear_all" do
    it "removes all conversation mappings" do
      described_class.switch("user1", "uuid1")
      described_class.switch("user2", "uuid2")
      described_class.clear_all

      expect(described_class.all_mappings).to eq({})
    end

    it "persists the cleared state" do
      described_class.switch("user1", "uuid1")
      described_class.clear_all

      mapping_file = File.join(temp_dir, "conversations.json")
      saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
      expect(saved_data[:conversations]).to eq({})
    end
  end

  describe "persistence across instances" do
    it "loads existing mappings from file" do
      # Create a mapping
      described_class.switch("user123", "persisted-uuid")

      # Clear the in-memory cache by accessing private method
      described_class.instance_variable_set(:@mapping, nil)

      # Now accessing current_for should load from file
      conversation = described_class.current_for("user123")
      expect(conversation.uuid).to eq("persisted-uuid")
    end

    it "handles corrupted JSON gracefully" do
      mapping_file = File.join(temp_dir, "conversations.json")
      FileUtils.mkdir_p(File.dirname(mapping_file))
      File.write(mapping_file, "invalid json{")

      # Clear the in-memory cache
      described_class.instance_variable_set(:@mapping, nil)

      # Should return empty hash and create new conversation
      conversation = described_class.current_for("user123")
      expect(conversation).to be_a(Botiasloop::Conversation)
    end
  end
end
