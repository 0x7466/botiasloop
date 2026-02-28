# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  minimum_coverage 89
end

require "bundler/setup"
require "sequel"
require "webmock/rspec"

# Load and configure RubyLLM BEFORE loading botiasloop
# This follows RubyLLM's test pattern - configure before any provider is created
require "ruby_llm"
RubyLLM.configure do |config|
  config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY", "test")
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "test")
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", "test")
end

# Set up in-memory database BEFORE loading botiasloop
# Pre-create the Database class with in-memory database to prevent file-based auto-connect
module Botiasloop
  class Database
    @db = Sequel.sqlite
  end
end

require_relative "../lib/botiasloop/database"
Botiasloop::Database.setup!

# Now load the rest of botiasloop (Agent.instance will use the pre-configured RubyLLM)
require "botiasloop"

require "vcr"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") do
    ENV.fetch("OPENROUTER_API_KEY", "test-api-key")
  end
end

# Custom matcher module for command registry
module CommandRegistryMatchers
  class CommandRegistryMatcher
    def initialize(name)
      @name = name
    end

    def matches?(registry)
      @registry = registry
      registry[@name].is_a?(Class)
    end

    def failure_message
      "expected #{@registry.inspect} to have command :#{@name}"
    end

    def failure_message_when_negated
      "expected #{@registry.inspect} not to have command :#{@name}"
    end
  end

  def have_command(name)
    CommandRegistryMatcher.new(name)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Include custom matchers
  config.include(CommandRegistryMatchers)

  # Transaction rollback for database tests - keeps test DB clean
  config.around(:each) do |example|
    Botiasloop::Database.connect.transaction(rollback: :always, savepoint: true) do
      example.run
    end
  end
end
