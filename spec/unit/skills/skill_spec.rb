# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Botiasloop::Skills::Skill do
  let(:valid_skill_dir) { Dir.mktmpdir("valid-skill") }
  let(:invalid_skill_dir) { Dir.mktmpdir("invalid-skill") }

  after do
    FileUtils.rm_rf(valid_skill_dir)
    FileUtils.rm_rf(invalid_skill_dir)
  end

  describe "#initialize" do
    context "with valid SKILL.md" do
      before do
        File.write(
          File.join(valid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: test-skill
            description: A test skill for testing purposes.
            metadata:
              author: test
              version: "1.0"
            ---

            # Test Skill

            This is the body content.
          SKILL
        )
      end

      it "parses name from frontmatter" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.name).to eq("test-skill")
      end

      it "parses description from frontmatter" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.description).to eq("A test skill for testing purposes.")
      end

      it "parses metadata from frontmatter" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.metadata).to eq({"author" => "test", "version" => "1.0"})
      end

      it "stores the skill path" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.path).to eq(valid_skill_dir)
      end

      it "stores full SKILL.md content" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.content).to include("name: test-skill")
        expect(skill.content).to include("This is the body content.")
      end

      it "extracts body content without frontmatter" do
        skill = described_class.new(valid_skill_dir)
        expect(skill.body).to eq("# Test Skill\n\nThis is the body content.")
      end
    end

    context "with missing SKILL.md" do
      it "raises an error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Skill not found/)
      end
    end

    context "with missing frontmatter" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          "This is just body content without frontmatter."
        )
      end

      it "raises an error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid SKILL.md format/)
      end
    end

    context "with missing required fields" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            metadata:
              version: "1.0"
            ---

            Body content.
          SKILL
        )
      end

      it "raises error for missing name" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Missing 'name'/)
      end
    end

    context "with invalid name format" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: InvalidName
            description: Test description.
            ---

            Body content.
          SKILL
        )
      end

      it "raises error for uppercase letters" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid skill name/)
      end
    end

    context "with name starting with hyphen" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: -invalid
            description: Test description.
            ---

            Body content.
          SKILL
        )
      end

      it "raises error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid skill name/)
      end
    end

    context "with name ending with hyphen" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: invalid-
            description: Test description.
            ---

            Body content.
          SKILL
        )
      end

      it "raises error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid skill name/)
      end
    end

    context "with consecutive hyphens" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: invalid--name
            description: Test description.
            ---

            Body content.
          SKILL
        )
      end

      it "raises error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid skill name/)
      end
    end

    context "with name too long" do
      before do
        File.write(
          File.join(invalid_skill_dir, "SKILL.md"),
          <<~SKILL
            ---
            name: #{"a" * 65}
            description: Test description.
            ---

            Body content.
          SKILL
        )
      end

      it "raises error" do
        expect {
          described_class.new(invalid_skill_dir)
        }.to raise_error(Botiasloop::Error, /Invalid skill name/)
      end
    end
  end
end
