# frozen_string_literal: true

module Botiasloop
  module Skills
    # Represents a skill loaded from a SKILL.md file
    # Follows the agentskills.io specification
    class Skill
      attr_reader :name, :description, :path, :metadata, :license, :compatibility, :skill_md_path, :body

      # @param path [String] Path to skill directory containing SKILL.md
      def initialize(path)
        @path = File.expand_path(path)
        @skill_md_path = File.join(@path, "SKILL.md")

        raise Error, "Skill not found: #{@skill_md_path}" unless File.exist?(@skill_md_path)

        parse_skill_md
      end

      # @return [String] Full content of SKILL.md
      def content
        @content ||= File.read(@skill_md_path)
      end

      private

      def parse_skill_md
        file_content = content

        if file_content =~ /^---\s*$
?(.*?)\n^---\s*$
?(.*)$/m
          frontmatter = ::Regexp.last_match(1)
          @body = ::Regexp.last_match(2).strip
        else
          raise Error, "Invalid SKILL.md format (missing frontmatter): #{@skill_md_path}"
        end

        metadata = parse_frontmatter(frontmatter)

        @name = metadata["name"]
        @description = metadata["description"]
        @license = metadata["license"]
        @compatibility = metadata["compatibility"]
        @metadata = metadata["metadata"] || {}

        validate!
      end

      def parse_frontmatter(frontmatter)
        require "yaml"
        YAML.safe_load(frontmatter, permitted_classes: [Date, Time])
      rescue Psych::SyntaxError => e
        raise Error, "Invalid YAML frontmatter in #{@skill_md_path}: #{e.message}"
      end

      def validate!
        raise Error, "Missing 'name' in skill frontmatter: #{@skill_md_path}" if @name.nil? || @name.empty?
        raise Error, "Missing 'description' in skill frontmatter: #{@skill_md_path}" if @description.nil? || @description.empty?

        validate_name_format!
      end

      def validate_name_format!
        # Max 64 characters, lowercase alphanumeric and hyphens only
        # Must not start or end with hyphen, no consecutive hyphens
        unless @name =~ /\A[a-z0-9]+(-[a-z0-9]+)*\z/ && @name.length <= 64
          raise Error, "Invalid skill name '#{@name}' in #{@skill_md_path}. " \
            "Must be 1-64 chars, lowercase alphanumeric and hyphens only, " \
            "no leading/trailing/consecutive hyphens."
        end
      end
    end
  end
end
