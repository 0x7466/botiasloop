# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tempfile"

RSpec.describe Botiasloop::ConversationManager do
  let(:temp_dir) { Dir.mktmpdir("botiasloop_test") }

  before do
    # Mock all filesystem paths to use temp directory - NEVER touch real user directories
    allow(described_class).to receive(:mapping_file).and_return(File.join(temp_dir, "conversations.json"))
    allow(described_class).to receive(:current_file).and_return(File.join(temp_dir, "current.json"))
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

      it "stores the mapping with user_id" do
        conversation = described_class.current_for("user123")
        uuid = described_class.current_uuid_for("user123")
        expect(uuid).to eq(conversation.uuid)

        mapping_file = File.join(temp_dir, "conversations.json")
        saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
        expect(saved_data[uuid.to_sym]).to eq({user_id: "user123", label: nil})
      end

      it "saves to persistent storage" do
        described_class.current_for("user123")
        mapping_file = File.join(temp_dir, "conversations.json")
        expect(File.exist?(mapping_file)).to be true

        saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
        expect(saved_data.values).to all(include(:user_id, :label))
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

    it "persists the switch with user_id" do
      described_class.switch("user123", "persisted-uuid")
      mapping_file = File.join(temp_dir, "conversations.json")
      saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
      expect(saved_data[:"persisted-uuid"]).to eq({user_id: "user123", label: nil})
    end

    it "overwrites existing mapping" do
      described_class.switch("user123", "first-uuid")
      described_class.switch("user123", "second-uuid")
      expect(described_class.current_uuid_for("user123")).to eq("second-uuid")
    end

    it "clears label when switching to different conversation" do
      described_class.switch("user123", "first-uuid")
      described_class.label("first-uuid", "old-label")
      described_class.switch("user123", "second-uuid")

      # second-uuid should have no label initially
      expect(described_class.label("second-uuid")).to be_nil
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

    it "initializes with no label" do
      conversation = described_class.create_new("user123")
      expect(described_class.label(conversation.uuid)).to be_nil
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

    it "returns all conversation mappings" do
      described_class.switch("user1", "uuid1")
      described_class.switch("user2", "uuid2")

      mappings = described_class.all_mappings
      expect(mappings).to eq({
        "uuid1" => {"user_id" => "user1", "label" => nil},
        "uuid2" => {"user_id" => "user2", "label" => nil}
      })
    end

    it "returns a copy of mappings" do
      described_class.switch("user1", "uuid1")
      mappings = described_class.all_mappings
      mappings["uuid2"] = {"user_id" => "user2", "label" => nil}

      # Original should be unchanged
      expect(described_class.all_mappings).to eq({"uuid1" => {"user_id" => "user1", "label" => nil}})
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
      expect(saved_data).not_to have_key(:"test-uuid")
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
      expect(saved_data).to eq({})
    end
  end

  describe ".label" do
    before do
      described_class.switch("user123", "test-uuid")
    end

    it "returns nil when conversation has no label" do
      expect(described_class.label("test-uuid")).to be_nil
    end

    it "returns the label when set" do
      described_class.label("test-uuid", "my-label")
      expect(described_class.label("test-uuid")).to eq("my-label")
    end

    it "returns nil for non-existent conversation" do
      expect(described_class.label("non-existent-uuid")).to be_nil
    end
  end

  describe ".label= (setter)" do
    before do
      described_class.switch("user123", "test-uuid")
    end

    it "sets the label for a conversation" do
      described_class.label("test-uuid", "my-project")
      expect(described_class.label("test-uuid")).to eq("my-project")
    end

    it "persists the label" do
      described_class.label("test-uuid", "persisted-label")

      mapping_file = File.join(temp_dir, "conversations.json")
      saved_data = JSON.parse(File.read(mapping_file), symbolize_names: true)
      expect(saved_data[:"test-uuid"][:label]).to eq("persisted-label")
    end

    it "allows valid characters: alphanumeric, dashes, underscores" do
      valid_labels = ["my-project", "my_project", "MyProject123", "test-123_test"]
      valid_labels.each do |label|
        described_class.label("test-uuid", label)
        expect(described_class.label("test-uuid")).to eq(label)
      end
    end

    it "raises error for invalid characters" do
      invalid_labels = ["my label", "my.label", "my/label", "label@email", "label#hash"]
      invalid_labels.each do |label|
        expect {
          described_class.label("test-uuid", label)
        }.to raise_error(Botiasloop::Error, /Invalid label format/)
      end
    end

    it "raises error when label already used by same user for different conversation" do
      described_class.label("test-uuid", "shared-label")
      described_class.switch("user123", "another-uuid")

      expect {
        described_class.label("another-uuid", "shared-label")
      }.to raise_error(Botiasloop::Error, /Label 'shared-label' already in use/)
    end

    it "allows same label for different users" do
      described_class.label("test-uuid", "shared-label")
      described_class.switch("user456", "different-uuid")
      described_class.label("different-uuid", "shared-label")

      expect(described_class.label("test-uuid")).to eq("shared-label")
      expect(described_class.label("different-uuid")).to eq("shared-label")
    end

    it "allows updating label for same conversation" do
      described_class.label("test-uuid", "first-label")
      described_class.label("test-uuid", "second-label")

      expect(described_class.label("test-uuid")).to eq("second-label")
    end

    it "allows setting same label on same conversation (no-op)" do
      described_class.label("test-uuid", "same-label")
      expect { described_class.label("test-uuid", "same-label") }.not_to raise_error
    end

    it "raises error for non-existent conversation" do
      expect {
        described_class.label("non-existent-uuid", "label")
      }.to raise_error(Botiasloop::Error, /Conversation not found/)
    end
  end

  describe ".label_exists?" do
    before do
      described_class.switch("user123", "uuid1")
      described_class.switch("user456", "uuid2")
      described_class.label("uuid1", "user1-label")
      described_class.label("uuid2", "user2-label")
    end

    it "returns true when label exists for user" do
      expect(described_class.label_exists?("user123", "user1-label")).to be true
    end

    it "returns false when label does not exist for user" do
      expect(described_class.label_exists?("user123", "nonexistent")).to be false
    end

    it "returns false when checking other user's label" do
      expect(described_class.label_exists?("user123", "user2-label")).to be false
    end

    it "excludes specified uuid when checking" do
      expect(described_class.label_exists?("user123", "user1-label", exclude_uuid: "uuid1")).to be false
    end
  end

  describe ".list_by_user" do
    it "returns empty array when user has no conversations" do
      expect(described_class.list_by_user("unknown_user")).to eq([])
    end

    it "returns all conversations for a user with labels" do
      described_class.switch("user123", "uuid1")
      described_class.switch("user123", "uuid2")
      described_class.label("uuid1", "first-convo")

      conversations = described_class.list_by_user("user123")
      expect(conversations.length).to eq(2)
      expect(conversations).to include({uuid: "uuid1", label: "first-convo"})
      expect(conversations).to include({uuid: "uuid2", label: nil})
    end

    it "only returns conversations for specified user" do
      described_class.switch("user123", "uuid1")
      described_class.switch("user456", "uuid2")

      conversations = described_class.list_by_user("user123")
      expect(conversations.length).to eq(1)
      expect(conversations.first[:uuid]).to eq("uuid1")
    end
  end

  describe ".find_by_label" do
    before do
      described_class.switch("user123", "uuid1")
      described_class.switch("user456", "uuid2")
      described_class.label("uuid1", "my-project")
      described_class.label("uuid2", "other-project")
    end

    it "returns uuid for existing label" do
      expect(described_class.find_by_label("user123", "my-project")).to eq("uuid1")
    end

    it "returns nil for non-existent label" do
      expect(described_class.find_by_label("user123", "nonexistent")).to be_nil
    end

    it "does not find other user's labels" do
      expect(described_class.find_by_label("user123", "other-project")).to be_nil
    end
  end

  describe "persistence across instances" do
    it "loads existing mappings from file" do
      # Create a mapping
      described_class.switch("user123", "persisted-uuid")

      # Clear the in-memory cache
      described_class.instance_variable_set(:@mapping, nil)

      # Now accessing current_for should load from file
      conversation = described_class.current_for("user123")
      expect(conversation.uuid).to eq("persisted-uuid")
    end

    it "loads labels from file" do
      described_class.switch("user123", "persisted-uuid")
      described_class.label("persisted-uuid", "my-label")

      # Clear the in-memory cache
      described_class.instance_variable_set(:@mapping, nil)

      # Label should be loaded from file
      expect(described_class.label("persisted-uuid")).to eq("my-label")
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
