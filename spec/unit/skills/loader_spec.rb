# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Botiasloop::Skills::Loader do
  let(:test_dir) { Dir.mktmpdir("skills-test") }
  let(:user_skills_dir) { File.join(test_dir, "user-skills") }
  let(:default_skills_dir) { File.join(test_dir, "default-skills") }

  before do
    FileUtils.mkdir_p(user_skills_dir)
    FileUtils.mkdir_p(default_skills_dir)

    # Create valid test skills
    create_skill(default_skills_dir, "default-skill-1", "First default skill")
    create_skill(default_skills_dir, "default-skill-2", "Second default skill")
    create_skill(user_skills_dir, "user-skill", "User custom skill")
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  def create_skill(base_dir, name, description)
    skill_dir = File.join(base_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(
      File.join(skill_dir, "SKILL.md"),
      <<~SKILL
        ---
        name: #{name}
        description: #{description}
        ---

        # #{name}

        Skill content here.
      SKILL
    )
  end

  describe ".load_from_directory" do
    it "loads all valid skills from a directory" do
      skills = described_class.load_from_directory(default_skills_dir)
      expect(skills.length).to eq(2)
      expect(skills.map(&:name)).to contain_exactly("default-skill-1", "default-skill-2")
    end

    it "returns empty array for non-existent directory" do
      skills = described_class.load_from_directory("/nonexistent/path")
      expect(skills).to be_empty
    end

    it "returns empty array for empty directory" do
      empty_dir = Dir.mktmpdir("empty-skills")
      skills = described_class.load_from_directory(empty_dir)
      expect(skills).to be_empty
      FileUtils.rm_rf(empty_dir)
    end

    it "skips directories without SKILL.md" do
      FileUtils.mkdir_p(File.join(default_skills_dir, "not-a-skill"))
      skills = described_class.load_from_directory(default_skills_dir)
      expect(skills.length).to eq(2)
    end

    it "warns about invalid skills but continues loading" do
      invalid_dir = File.join(default_skills_dir, "invalid-skill")
      FileUtils.mkdir_p(invalid_dir)
      File.write(File.join(invalid_dir, "SKILL.md"), "Invalid content without frontmatter")

      expect {
        skills = described_class.load_from_directory(default_skills_dir)
        expect(skills.length).to eq(2)
      }.to output(/Failed to load skill/).to_stderr
    end
  end

  describe ".load_user_skills" do
    it "loads skills from user directory" do
      user_skill = Botiasloop::Skills::Skill.new(File.join(user_skills_dir, "user-skill"))
      allow(described_class).to receive(:load_user_skills).and_return([user_skill])

      skills = described_class.load_user_skills
      expect(skills.length).to eq(1)
      expect(skills.first.name).to eq("user-skill")
    end

    it "returns empty array when user directory does not exist" do
      allow(described_class).to receive(:load_user_skills).and_return([])

      skills = described_class.load_user_skills
      expect(skills).to be_empty
    end
  end

  describe ".find_by_name" do
    before do
      allow(described_class).to receive(:load_all_skills).and_return([
        Botiasloop::Skills::Skill.new(default_skills_dir + "/default-skill-1"),
        Botiasloop::Skills::Skill.new(user_skills_dir + "/user-skill")
      ])
    end

    it "finds skill by name" do
      skill = described_class.find_by_name("user-skill")
      expect(skill).not_to be_nil
      expect(skill.name).to eq("user-skill")
    end

    it "returns nil for non-existent skill" do
      skill = described_class.find_by_name("nonexistent")
      expect(skill).to be_nil
    end
  end
end
