# frozen_string_literal: true

require_relative "lib/botiasloop/version"

Gem::Specification.new do |spec|
  spec.name = "botiasloop"
  spec.version = Botiasloop::VERSION
  spec.authors = ["Tobias Feistmantl"]
  spec.email = ["tobias@feistmantl.io"]
  spec.summary = "Minimal agentic AI application with ReAct loop"
  spec.description = "A minimal Ruby gem for building agentic AI applications using the ReAct (Reasoning + Acting) loop pattern"
  spec.homepage = "https://github.com/0x7466/botiasloop"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.files = Dir["lib/**/*", "bin/*", "README.md", "LICENSE"]
  spec.bindir = "bin"
  spec.executables = ["botiasloop"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "ruby_llm", "~> 1.12.1"
  spec.add_dependency "telegram-bot-ruby", "~> 2.5"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.13.2"
  spec.add_development_dependency "vcr", "~> 6.4.0"
  spec.add_development_dependency "webmock", "~> 3.26.1"
  spec.add_development_dependency "standard", "~> 1.54.0"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
