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

    it "switches by label when label exists" do
      described_class.switch("user123", "target-uuid")
      described_class.label("target-uuid", "my-project")

      # Clear memory to test fresh lookup
      described_class.instance_variable_set(:@mapping, nil)

      conversation = described_class.switch("user123", "my-project")
      expect(conversation.uuid).to eq("target-uuid")
    end

    it "treats identifier as UUID when no label matches" do
      conversation = described_class.switch("user123", "new-uuid-123")
      expect(conversation.uuid).to eq("new-uuid-123")
    end

    it "raises error for empty identifier" do
      expect {
        described_class.switch("user123", "")
      }.to raise_error(Botiasloop::Error, /Usage: \/switch/)
    end

    it "raises error for nil identifier" do
      expect {
        described_class.switch("user123", nil)
      }.to raise_error(Botiasloop::Error, /Usage: \/switch/)
    end

    it "strips whitespace from identifier" do
      described_class.switch("user123", "target-uuid")
      described_class.label("target-uuid", "my-project")

      described_class.instance_variable_set(:@mapping, nil)

      conversation = described_class.switch("user123", "  my-project  ")
      expect(conversation.uuid).to eq("target-uuid")
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

  describe ".archive" do
    context "when archiving by label" do
      before do
        described_class.switch("user123", "target-uuid")
        described_class.label("target-uuid", "my-project")
        described_class.switch("user123", "other-uuid") # Create another conversation to avoid "current" error
      end

      it "archives a conversation by label" do
        result = described_class.archive("user123", "my-project")
        expect(result).to have_key(:archived)
        expect(result[:archived]).to be_a(Botiasloop::Conversation)
        expect(result[:archived].uuid).to eq("target-uuid")

        # Verify it's archived in the database
        db_conv = Botiasloop::Models::Conversation.find(id: "target-uuid")
        expect(db_conv.archived).to be true
        expect(db_conv.is_current).to be false
      end

      it "raises error when conversation not found" do
        expect {
          described_class.archive("user123", "nonexistent")
        }.to raise_error(Botiasloop::Error, /Conversation 'nonexistent' not found/)
      end

      it "raises error when archiving current conversation with identifier" do
        # Switch back to target-uuid to make it current
        described_class.switch("user123", "target-uuid")

        expect {
          described_class.archive("user123", "my-project")
        }.to raise_error(Botiasloop::Error, /Cannot archive the current conversation/)
      end
    end

    context "when archiving by UUID" do
      before do
        described_class.switch("user123", "target-uuid")
        described_class.switch("user123", "other-uuid") # Create another conversation
      end

      it "archives a conversation by UUID" do
        result = described_class.archive("user123", "target-uuid")
        expect(result).to have_key(:archived)
        expect(result[:archived].uuid).to eq("target-uuid")

        db_conv = Botiasloop::Models::Conversation.find(id: "target-uuid")
        expect(db_conv.archived).to be true
      end
    end

    context "when archiving current conversation (no identifier)" do
      before do
        described_class.switch("user123", "current-uuid")
        described_class.label("current-uuid", "current-project")
      end

      it "archives current conversation and creates a new one" do
        result = described_class.archive("user123")

        expect(result).to have_key(:archived)
        expect(result).to have_key(:new_conversation)
        expect(result[:archived].uuid).to eq("current-uuid")
        expect(result[:new_conversation]).to be_a(Botiasloop::Conversation)

        # Verify archived
        db_conv = Botiasloop::Models::Conversation.find(id: "current-uuid")
        expect(db_conv.archived).to be true
        expect(db_conv.is_current).to be false

        # Verify new conversation is current
        new_db_conv = Botiasloop::Models::Conversation.find(id: result[:new_conversation].uuid)
        expect(new_db_conv.is_current).to be true
      end

      it "creates a new conversation as current" do
        result = described_class.archive("user123")
        new_uuid = result[:new_conversation].uuid

        expect(described_class.current_uuid_for("user123")).to eq(new_uuid)
      end
    end

    context "with nil identifier" do
      before do
        described_class.switch("user123", "existing-uuid")
      end

      it "archives current conversation when nil" do
        result = described_class.archive("user123", nil)
        expect(result).to have_key(:archived)
        expect(result).to have_key(:new_conversation)
      end
    end
  end

  describe "archive integration with other methods" do
    before do
      described_class.switch("user123", "uuid1")
      described_class.label("uuid1", "first-project")
      described_class.switch("user123", "uuid2")
      described_class.label("uuid2", "second-project")
      # Archive the first conversation
      described_class.archive("user123", "first-project")
    end

    it "excludes archived conversations from list_by_user by default" do
      conversations = described_class.list_by_user("user123")
      uuids = conversations.map { |c| c[:uuid] }
      expect(uuids).not_to include("uuid1")
      expect(uuids).to include("uuid2")
    end

    it "includes archived conversations when archived: nil" do
      conversations = described_class.list_by_user("user123", archived: nil)
      uuids = conversations.map { |c| c[:uuid] }
      expect(uuids).to include("uuid1")
      expect(uuids).to include("uuid2")
    end

    it "includes only archived conversations when archived: true" do
      conversations = described_class.list_by_user("user123", archived: true)
      uuids = conversations.map { |c| c[:uuid] }
      expect(uuids).to include("uuid1")
      expect(uuids).not_to include("uuid2")
    end

    it "excludes archived from all_mappings by default" do
      mappings = described_class.all_mappings
      expect(mappings).not_to have_key("uuid1")
      expect(mappings).to have_key("uuid2")
    end

    it "includes archived in all_mappings when include_archived: true" do
      mappings = described_class.all_mappings(include_archived: true)
      expect(mappings).to have_key("uuid1")
      expect(mappings).to have_key("uuid2")
    end

    it "auto-unarchives when switching to archived conversation" do
      # Switch to the archived conversation
      described_class.switch("user123", "first-project")

      # Verify it's no longer archived and is now current
      db_conv = Botiasloop::Models::Conversation.find(id: "uuid1")
      expect(db_conv.archived).to be false
      expect(db_conv.is_current).to be true
    end

    it "auto-unarchives when switching by UUID" do
      described_class.switch("user123", "uuid1")

      db_conv = Botiasloop::Models::Conversation.find(id: "uuid1")
      expect(db_conv.archived).to be false
    end

    it "creates new conversation when current_for encounters only archived conversations" do
      # Archive uuid2 as well
      described_class.archive("user123", "second-project")

      # Now current_for should create a new conversation
      conversation = described_class.current_for("user123")
      expect(conversation.uuid).not_to eq("uuid1")
      expect(conversation.uuid).not_to eq("uuid2")
    end

    it "preserves label after archiving and unarchiving" do
      described_class.switch("user123", "first-project")

      db_conv = Botiasloop::Models::Conversation.find(id: "uuid1")
      expect(db_conv.label).to eq("first-project")
      expect(db_conv.archived).to be false
    end
  end

  describe "list_by_user sorting" do
    it "sorts conversations by updated_at descending" do
      # Create conversations with explicit timestamps
      time1 = Time.now - 3600 # 1 hour ago
      time2 = Time.now - 1800 # 30 minutes ago
      time3 = Time.now # now

      described_class.switch("user123", "uuid1")
      Botiasloop::Models::Conversation.find(id: "uuid1").update(updated_at: time1)

      described_class.switch("user123", "uuid2")
      Botiasloop::Models::Conversation.find(id: "uuid2").update(updated_at: time2)

      described_class.switch("user123", "uuid3")
      Botiasloop::Models::Conversation.find(id: "uuid3").update(updated_at: time3)

      conversations = described_class.list_by_user("user123", archived: nil)
      uuids = conversations.map { |c| c[:uuid] }

      # Most recently updated should be first
      expect(uuids).to eq(["uuid3", "uuid2", "uuid1"])
    end
  end
end
