# frozen_string_literal: true

require "spec_helper"

RSpec.describe Botiasloop::ConversationManager do
  before do
    described_class.clear_all
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
        uuid = described_class.current_id_for("user123")
        expect(uuid).to eq(conversation.uuid)

        # Verify via database
        db_conv = Botiasloop::Conversation.find(id: uuid)
        expect(db_conv.user_id).to eq("user123")
        expect(db_conv.label).to be_nil
      end

      it "saves to persistent storage" do
        conversation = described_class.current_for("user123")
        uuid = conversation.uuid

        # Verify via database
        db_conv = Botiasloop::Conversation.find(id: uuid)
        expect(db_conv).not_to be_nil
        expect(db_conv.user_id).to eq("user123")
      end
    end

    context "when user already has a conversation" do
      before do
        Botiasloop::Conversation.create(id: "existing-user-123", user_id: "user123", is_current: true)
      end

      it "returns existing conversation" do
        conversation = described_class.current_for("user123")
        expect(conversation.uuid).to eq("existing-user-123")
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
      expect(described_class.current_id_for("user1")).to eq(conversation1.uuid)
      expect(described_class.current_id_for("user2")).to eq(conversation2.uuid)
    end
  end

  describe ".switch" do
    it "switches user to the specified conversation uuid" do
      Botiasloop::Conversation.create(id: "new-uuid", user_id: "user123")
      described_class.switch("user123", "new-uuid")
      expect(described_class.current_id_for("user123")).to eq("new-uuid")
    end

    it "returns the switched-to conversation" do
      Botiasloop::Conversation.create(id: "new-uuid", user_id: "user123")
      conversation = described_class.switch("user123", "new-uuid")
      expect(conversation).to be_a(Botiasloop::Conversation)
      expect(conversation.uuid).to eq("new-uuid")
    end

    it "persists the switch with user_id" do
      Botiasloop::Conversation.create(id: "persisted-uuid", user_id: "user123")
      described_class.switch("user123", "persisted-uuid")

      # Verify via database
      db_conv = Botiasloop::Conversation.find(id: "persisted-uuid")
      expect(db_conv.user_id).to eq("user123")
      expect(db_conv.label).to be_nil
      expect(db_conv.is_current).to be true
    end

    it "overwrites existing mapping" do
      Botiasloop::Conversation.create(id: "first-uuid", user_id: "user123", is_current: true)
      Botiasloop::Conversation.create(id: "second-uuid", user_id: "user123")
      described_class.switch("user123", "second-uuid")
      expect(described_class.current_id_for("user123")).to eq("second-uuid")
    end

    it "clears label when switching to different conversation" do
      Botiasloop::Conversation.create(id: "first-uuid", user_id: "user123", label: "old-label", is_current: true)
      Botiasloop::Conversation.create(id: "second-uuid", user_id: "user123")
      described_class.switch("user123", "second-uuid")

      # second-uuid should have no label initially
      expect(described_class.label("second-uuid")).to be_nil
    end

    it "switches by label when label exists" do
      Botiasloop::Conversation.create(id: "target-uuid", user_id: "user123", label: "my-project", is_current: true)

      conversation = described_class.switch("user123", "my-project")
      expect(conversation.uuid).to eq("target-uuid")
    end

    it "treats identifier as UUID when no label matches" do
      Botiasloop::Conversation.create(id: "new-uuid-123", user_id: "user123")
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
      Botiasloop::Conversation.create(id: "target-uuid", user_id: "user123", label: "my-project", is_current: true)

      conversation = described_class.switch("user123", "  my-project  ")
      expect(conversation.uuid).to eq("target-uuid")
    end
  end

  describe ".create_new" do
    before do
      allow(Botiasloop::HumanId).to receive(:generate).and_return("blue-dog-123")
    end

    it "creates a new conversation" do
      conversation = described_class.create_new("user123")
      expect(conversation).to be_a(Botiasloop::Conversation)
      expect(conversation.uuid).to eq("blue-dog-123")
    end

    it "switches user to the new conversation" do
      described_class.create_new("user123")
      expect(described_class.current_id_for("user123")).to eq("blue-dog-123")
    end

    it "returns the new conversation" do
      conversation = described_class.create_new("user123")
      expect(conversation.uuid).to eq("blue-dog-123")
    end

    it "overwrites existing mapping" do
      Botiasloop::Conversation.create(id: "old-user-456", user_id: "user123", is_current: true)
      described_class.create_new("user123")
      expect(described_class.current_id_for("user123")).to eq("blue-dog-123")
    end

    it "initializes with no label" do
      conversation = described_class.create_new("user123")
      expect(described_class.label(conversation.uuid)).to be_nil
    end
  end

  describe ".current_id_for" do
    it "returns nil when user has no conversation" do
      expect(described_class.current_id_for("unknown_user")).to be_nil
    end

    it "returns the uuid when user has a conversation" do
      Botiasloop::Conversation.create(id: "test-uuid", user_id: "user123", is_current: true)
      expect(described_class.current_id_for("user123")).to eq("test-uuid")
    end
  end

  describe ".all_mappings" do
    it "returns empty hash when no mappings exist" do
      expect(described_class.all_mappings).to eq({})
    end

    it "returns all conversation mappings" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user1", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user2", is_current: true)

      mappings = described_class.all_mappings
      expect(mappings).to eq({
        "test-convo-111" => {"user_id" => "user1", "label" => nil},
        "test-convo-222" => {"user_id" => "user2", "label" => nil}
      })
    end

    it "returns a copy of mappings" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user1", is_current: true)
      mappings = described_class.all_mappings
      mappings["test-convo-222"] = {"user_id" => "user2", "label" => nil}

      # Original should be unchanged
      expect(described_class.all_mappings).to eq({"test-convo-111" => {"user_id" => "user1", "label" => nil}})
    end
  end

  describe ".remove" do
    it "removes the user's conversation mapping" do
      Botiasloop::Conversation.create(id: "test-uuid", user_id: "user123", is_current: true)
      described_class.remove("user123")
      expect(described_class.current_id_for("user123")).to be_nil
    end

    it "persists the removal" do
      Botiasloop::Conversation.create(id: "test-uuid", user_id: "user123", is_current: true)
      described_class.remove("user123")

      # Verify via database - conversation should be destroyed
      expect(Botiasloop::Conversation.find(id: "test-uuid")).to be_nil
    end

    it "handles removing non-existent user gracefully" do
      expect { described_class.remove("non_existent_user") }.not_to raise_error
    end
  end

  describe ".clear_all" do
    it "removes all conversation mappings" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user1", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user2", is_current: true)
      described_class.clear_all

      expect(described_class.all_mappings).to eq({})
    end

    it "persists the cleared state" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user1", is_current: true)
      described_class.clear_all

      # Verify via database - all conversations should be deleted
      expect(Botiasloop::Conversation.count).to eq(0)
    end
  end

  describe ".label" do
    before do
      Botiasloop::Conversation.create(id: "test-uuid", user_id: "user123", is_current: true)
    end

    it "returns nil when conversation has no label" do
      expect(described_class.label("test-uuid")).to be_nil
    end

    it "returns the label when set" do
      described_class.set_label("test-uuid", "my-label")
      expect(described_class.label("test-uuid")).to eq("my-label")
    end

    it "returns nil for non-existent conversation" do
      expect(described_class.label("non-existent-uuid")).to be_nil
    end
  end

  describe ".label= (setter)" do
    before do
      Botiasloop::Conversation.create(id: "test-uuid", user_id: "user123", is_current: true)
    end

    it "sets the label for a conversation" do
      described_class.set_label("test-uuid", "my-project")
      expect(described_class.label("test-uuid")).to eq("my-project")
    end

    it "persists the label" do
      described_class.set_label("test-uuid", "persisted-label")

      # Verify via database - reload from DB
      db_conv = Botiasloop::Conversation.find(id: "test-uuid")
      expect(db_conv.label).to eq("persisted-label")
    end

    it "allows valid characters: alphanumeric, dashes, underscores" do
      valid_labels = ["my-project", "my_project", "MyProject123", "test-123_test"]
      valid_labels.each do |label|
        described_class.set_label("test-uuid", label)
        expect(described_class.label("test-uuid")).to eq(label)
      end
    end

    it "raises error for invalid characters" do
      invalid_labels = ["my label", "my.project", "my/label", "label@email", "label#hash"]
      invalid_labels.each do |label|
        expect {
          described_class.set_label("test-uuid", label)
        }.to raise_error(Botiasloop::Error, /Invalid label format/)
      end
    end

    it "raises error when label already used by same user for different conversation" do
      described_class.set_label("test-uuid", "shared-label")
      Botiasloop::Conversation.create(id: "another-uuid", user_id: "user123")

      expect {
        described_class.set_label("another-uuid", "shared-label")
      }.to raise_error(Botiasloop::Error, /Label 'shared-label' already in use/)
    end

    it "allows same label for different users" do
      described_class.set_label("test-uuid", "shared-label")
      Botiasloop::Conversation.create(id: "different-uuid", user_id: "user456", is_current: true)
      described_class.set_label("different-uuid", "shared-label")

      expect(described_class.label("test-uuid")).to eq("shared-label")
      expect(described_class.label("different-uuid")).to eq("shared-label")
    end

    it "allows updating label for same conversation" do
      described_class.set_label("test-uuid", "first-label")
      described_class.set_label("test-uuid", "second-label")

      expect(described_class.label("test-uuid")).to eq("second-label")
    end

    it "allows setting same label on same conversation (no-op)" do
      described_class.set_label("test-uuid", "same-label")
      expect { described_class.set_label("test-uuid", "same-label") }.not_to raise_error
    end

    it "raises error for non-existent conversation" do
      expect {
        described_class.set_label("non-existent-uuid", "label")
      }.to raise_error(Botiasloop::Error, /Conversation not found/)
    end
  end

  describe ".label_exists?" do
    before do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", label: "user1-label", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user456", label: "user2-label", is_current: true)
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
      expect(described_class.label_exists?("user123", "user1-label", exclude_id: "test-convo-111")).to be false
    end
  end

  describe ".list_by_user" do
    it "returns empty array when user has no conversations" do
      expect(described_class.list_by_user("unknown_user")).to eq([])
    end

    it "returns all conversations for a user with labels" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", label: "first-convo", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user123")

      conversations = described_class.list_by_user("user123")
      expect(conversations.length).to eq(2)
      expect(conversations).to include(hash_including({id: "test-convo-111", label: "first-convo"}))
      expect(conversations).to include(hash_including({id: "test-convo-222", label: nil}))
    end

    it "only returns conversations for specified user" do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user456", is_current: true)

      conversations = described_class.list_by_user("user123")
      expect(conversations.length).to eq(1)
      expect(conversations.first[:id]).to eq("test-convo-111")
    end
  end

  describe ".find_by_label" do
    before do
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", label: "my-project", is_current: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user456", label: "other-project", is_current: true)
    end

    it "returns uuid for existing label" do
      expect(described_class.find_by_label("user123", "my-project")).to eq("test-convo-111")
    end

    it "returns nil for non-existent label" do
      expect(described_class.find_by_label("user123", "nonexistent")).to be_nil
    end

    it "does not find other user's labels" do
      expect(described_class.find_by_label("user123", "other-project")).to be_nil
    end
  end

  describe "persistence across instances" do
    it "loads existing mappings from database" do
      # Create a conversation in database
      Botiasloop::Conversation.create(id: "persisted-uuid", user_id: "user123", is_current: true)

      # Now accessing current_for should load from database
      conversation = described_class.current_for("user123")
      expect(conversation.uuid).to eq("persisted-uuid")
    end

    it "loads labels from database" do
      Botiasloop::Conversation.create(id: "persisted-uuid", user_id: "user123", label: "my-label", is_current: true)

      # Label should be loaded from database
      expect(described_class.label("persisted-uuid")).to eq("my-label")
    end
  end

  describe ".archive" do
    context "when archiving by label" do
      before do
        Botiasloop::Conversation.create(id: "target-uuid", user_id: "user123", label: "my-project")
        Botiasloop::Conversation.create(id: "other-uuid", user_id: "user123", is_current: true)
      end

      it "archives a conversation by label" do
        result = described_class.archive("user123", "my-project")
        expect(result).to have_key(:archived)
        expect(result[:archived]).to be_a(Botiasloop::Conversation)
        expect(result[:archived].uuid).to eq("target-uuid")

        # Verify it's archived in the database
        db_conv = Botiasloop::Conversation.find(id: "target-uuid")
        expect(db_conv.archived).to be true
        expect(db_conv.is_current).to be false
      end

      it "raises error when conversation not found" do
        expect {
          described_class.archive("user123", "nonexistent")
        }.to raise_error(Botiasloop::Error, /Conversation 'nonexistent' not found/)
      end

      it "raises error when archiving current conversation with identifier" do
        # Make target-uuid current
        Botiasloop::Conversation.where(id: "target-uuid").update(is_current: true)
        Botiasloop::Conversation.where(id: "other-uuid").update(is_current: false)

        expect {
          described_class.archive("user123", "my-project")
        }.to raise_error(Botiasloop::Error, /Cannot archive the current conversation/)
      end
    end

    context "when archiving by UUID" do
      before do
        Botiasloop::Conversation.create(id: "target-uuid", user_id: "user123")
        Botiasloop::Conversation.create(id: "other-uuid", user_id: "user123", is_current: true)
      end

      it "archives a conversation by UUID" do
        result = described_class.archive("user123", "target-uuid")
        expect(result).to have_key(:archived)
        expect(result[:archived].uuid).to eq("target-uuid")

        db_conv = Botiasloop::Conversation.find(id: "target-uuid")
        expect(db_conv.archived).to be true
      end
    end

    context "when archiving current conversation (no identifier)" do
      before do
        Botiasloop::Conversation.create(id: "current-uuid", user_id: "user123", label: "current-project", is_current: true)
      end

      it "archives current conversation and creates a new one" do
        result = described_class.archive("user123")

        expect(result).to have_key(:archived)
        expect(result).to have_key(:new_conversation)
        expect(result[:archived].uuid).to eq("current-uuid")
        expect(result[:new_conversation]).to be_a(Botiasloop::Conversation)

        # Verify archived
        db_conv = Botiasloop::Conversation.find(id: "current-uuid")
        expect(db_conv.archived).to be true
        expect(db_conv.is_current).to be false

        # Verify new conversation is current
        new_db_conv = Botiasloop::Conversation.find(id: result[:new_conversation].uuid)
        expect(new_db_conv.is_current).to be true
      end

      it "creates a new conversation as current" do
        result = described_class.archive("user123")
        new_uuid = result[:new_conversation].uuid

        expect(described_class.current_id_for("user123")).to eq(new_uuid)
      end
    end

    context "with nil identifier" do
      before do
        Botiasloop::Conversation.create(id: "existing-user-123", user_id: "user123", is_current: true)
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
      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", label: "first-project", archived: true)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user123", label: "second-project", is_current: true)
    end

    it "excludes archived conversations from list_by_user by default" do
      conversations = described_class.list_by_user("user123")
      ids = conversations.map { |c| c[:id] }
      expect(ids).not_to include("test-convo-111")
      expect(ids).to include("test-convo-222")
    end

    it "includes archived conversations when archived: nil" do
      conversations = described_class.list_by_user("user123", archived: nil)
      ids = conversations.map { |c| c[:id] }
      expect(ids).to include("test-convo-111")
      expect(ids).to include("test-convo-222")
    end

    it "includes only archived conversations when archived: true" do
      conversations = described_class.list_by_user("user123", archived: true)
      ids = conversations.map { |c| c[:id] }
      expect(ids).to include("test-convo-111")
      expect(ids).not_to include("test-convo-222")
    end

    it "excludes archived from all_mappings by default" do
      mappings = described_class.all_mappings
      expect(mappings).not_to have_key("test-convo-111")
      expect(mappings).to have_key("test-convo-222")
    end

    it "includes archived in all_mappings when include_archived: true" do
      mappings = described_class.all_mappings(include_archived: true)
      expect(mappings).to have_key("test-convo-111")
      expect(mappings).to have_key("test-convo-222")
    end

    it "auto-unarchives when switching to archived conversation" do
      # Switch to the archived conversation
      described_class.switch("user123", "first-project")

      # Verify it's no longer archived and is now current
      db_conv = Botiasloop::Conversation.find(id: "test-convo-111")
      expect(db_conv.archived).to be false
      expect(db_conv.is_current).to be true
    end

    it "auto-unarchives when switching by UUID" do
      described_class.switch("user123", "test-convo-111")

      db_conv = Botiasloop::Conversation.find(id: "test-convo-111")
      expect(db_conv.archived).to be false
    end

    it "creates new conversation when current_for encounters only archived conversations" do
      # Create a third conversation and make it current first
      Botiasloop::Conversation.create(id: "test-convo-333", user_id: "user123", is_current: true)
      Botiasloop::Conversation.where(id: "test-convo-222").update(is_current: false)

      # Archive uuid2
      described_class.archive("user123", "second-project")

      # Make uuid3 archived as well (current cannot be archived with identifier)
      described_class.archive("user123")

      # Now current_for should create a new conversation since all are archived
      conversation = described_class.current_for("user123")
      expect(conversation.uuid).not_to eq("test-convo-111")
      expect(conversation.uuid).not_to eq("test-convo-222")
      expect(conversation.uuid).not_to eq("test-convo-333")
    end

    it "preserves label after archiving and unarchiving" do
      described_class.switch("user123", "first-project")

      db_conv = Botiasloop::Conversation.find(id: "test-convo-111")
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

      Botiasloop::Conversation.create(id: "test-convo-111", user_id: "user123", updated_at: time1, is_current: false)
      Botiasloop::Conversation.create(id: "test-convo-222", user_id: "user123", updated_at: time2, is_current: false)
      Botiasloop::Conversation.create(id: "test-convo-333", user_id: "user123", updated_at: time3, is_current: true)

      conversations = described_class.list_by_user("user123", archived: nil)
      ids = conversations.map { |c| c[:id] }

      # Most recently updated should be first
      expect(ids).to eq(["test-convo-333", "test-convo-222", "test-convo-111"])
    end
  end
end
