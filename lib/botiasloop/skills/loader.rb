# frozen_string_literal: true

module Botiasloop
  module Skills
    # Discovers and loads skills from gem and user directories
    class Loader
      # @return [Array<Skill>] All loaded skills (default + user)
      def self.load_all_skills
        load_default_skills + load_user_skills
      end

      # @return [Array<Skill>] Skills shipped with the gem
      def self.load_default_skills
        skills_dir = File.join(Botiasloop.root, "data", "skills")
        load_from_directory(skills_dir)
      end

      # @return [Array<Skill>] Skills from user's ~/skills/ directory
      def self.load_user_skills
        user_skills_dir = File.expand_path("~/skills")
        load_from_directory(user_skills_dir)
      end

      # Load skills from a specific directory
      # @param dir [String] Directory path containing skill subdirectories
      # @return [Array<Skill>]
      def self.load_from_directory(dir)
        return [] unless File.directory?(dir)

        skills = []
        Dir.entries(dir).each do |entry|
          next if entry == "." || entry == ".."

          skill_path = File.join(dir, entry)
          next unless File.directory?(skill_path)

          skill_md_path = File.join(skill_path, "SKILL.md")
          next unless File.exist?(skill_md_path)

          begin
            skills << Skill.new(skill_path)
          rescue Error => e
            warn "Failed to load skill from #{skill_path}: #{e.message}"
          end
        end

        skills
      end

      # Find a specific skill by name
      # @param name [String] Skill name
      # @return [Skill, nil]
      def self.find_by_name(name)
        load_all_skills.find { |skill| skill.name == name }
      end
    end
  end
end
