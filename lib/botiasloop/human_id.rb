# frozen_string_literal: true

require "ffaker"

module Botiasloop
  # Generates human-readable identifiers for conversations
  # Format: color-animal-XXX (e.g., blue-dog-123)
  # All IDs are stored and compared in lowercase for case-insensitivity
  module HumanId
    MAX_RETRIES = 10

    # Generate a unique human-readable ID
    # Checks database for collisions and retries if needed
    #
    # @return [String] Unique ID in format color-animal-XXX
    # @raise [Error] If unable to generate unique ID after max retries
    def self.generate
      retries = 0

      loop do
        id = build_id
        return id unless exists?(id)

        retries += 1
        raise Error, "Failed to generate unique ID after #{MAX_RETRIES} attempts" if retries >= MAX_RETRIES
      end
    end

    # Normalize an ID to lowercase for storage and comparison
    #
    # @param id [String, nil] ID to normalize
    # @return [String] Normalized lowercase ID
    def self.normalize(id)
      id.to_s.downcase.strip
    end

    # Check if an ID already exists in the database
    # Case-insensitive comparison
    #
    # @param id [String] ID to check
    # @return [Boolean] True if ID exists
    def self.exists?(id)
      normalized = normalize(id)
      Conversation.where(Sequel.function(:lower, :id) => normalized).count > 0
    end

    # Build a single ID attempt
    #
    # @return [String] ID in format color-animal-XXX
    def self.build_id
      color = FFaker::Color.name.downcase.tr(" ", "-")
      animal = FFaker::AnimalUS.common_name.downcase.tr(" ", "-")
      number = rand(100..999)

      "#{color}-#{animal}-#{number}"
    end
  end
end
