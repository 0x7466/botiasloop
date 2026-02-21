# frozen_string_literal: true

# Helper methods for environment variable manipulation in tests
module EnvHelpers
  # Temporarily set environment variables for the duration of the block
  # @param vars [Hash] Environment variables to set
  # @yield Block to execute with modified environment
  # @return [Object] Result of the block
  def with_env(vars)
    original = {}
    vars.each do |key, value|
      original[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    original.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end

RSpec.configure do |config|
  config.include(EnvHelpers)
end
