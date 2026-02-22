# frozen_string_literal: true

require_relative "skill"
require_relative "loader"

module Botiasloop
  module Skills
    # Registry for managing available skills
    class Registry
      attr_reader :skills

      def initialize
        @skills = Loader.load_all_skills
      end

      # Get all skills as formatted table for system prompt
      # @return [String]
      def skills_table
        return "No skills available." if @skills.empty?

        header = "| Skill Name | Description | Path |"
        separator = "|------------|-------------|------|"
        rows = @skills.map { |skill| "| #{skill.name} | #{skill.description} | #{skill.path} |" }

        [header, separator, *rows].join("\n")
      end

      # Find a skill by name
      # @param name [String]
      # @return [Skill, nil]
      def find(name)
        @skills.find { |skill| skill.name == name }
      end

      # Get all skill names
      # @return [Array<String>]
      def names
        @skills.map(&:name)
      end
    end
  end
end
