# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Botiasloop::Skills::Registry do
  let(:test_dir) { Dir.mktmpdir("registry-test") }

  before do
    # Create test skills
    create_skill("skill-one", "First skill")
    create_skill("skill-two", "Second skill")

    allow(Botiasloop::Skills::Loader).to receive(:load_all_skills).and_return([
      Botiasloop::Skills::Skill.new(File.join(test_dir, "skill-one")),
      Botiasloop::Skills::Skill.new(File.join(test_dir, "skill-two"))
    ])
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  def create_skill(name, description)
    skill_dir = File.join(test_dir, name)
    FileUtils.mkdir_p(skill_dir)
    File.write(
      File.join(skill_dir, "SKILL.md"),
      <<~SKILL
        ---
        name: #{name}
        description: #{description}
        ---

        # #{name}

        Content here.
      SKILL
    )
  end

  describe "#initialize" do
    it "loads all skills on initialization" do
      registry = described_class.new
      expect(registry.skills.length).to eq(2)
    end
  end

  describe "#skills_table" do
    let(:registry) { described_class.new }

    it "returns formatted table with header" do
      table = registry.skills_table
      expect(table).to include("| Skill Name | Description | Path |")
      expect(table).to include("|------------|-------------|------|")
    end

    it "includes all skills in table" do
      table = registry.skills_table
      expect(table).to include("skill-one")
      expect(table).to include("skill-two")
      expect(table).to include("First skill")
      expect(table).to include("Second skill")
    end

    it "shows message when no skills available" do
      allow(Botiasloop::Skills::Loader).to receive(:load_all_skills).and_return([])
      registry = described_class.new
      expect(registry.skills_table).to eq("No skills available.")
    end
  end

  describe "#find" do
    let(:registry) { described_class.new }

    it "finds skill by name" do
      skill = registry.find("skill-one")
      expect(skill).not_to be_nil
      expect(skill.name).to eq("skill-one")
    end

    it "returns nil for non-existent skill" do
      skill = registry.find("nonexistent")
      expect(skill).to be_nil
    end
  end

  describe "#names" do
    let(:registry) { described_class.new }

    it "returns array of skill names" do
      expect(registry.names).to contain_exactly("skill-one", "skill-two")
    end
  end
end
