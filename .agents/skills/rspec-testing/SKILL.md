---
name: rspec-testing
description: Write effective RSpec tests for botiasloop. Use when creating new tests, refactoring existing tests, or reviewing test coverage. Covers TDD workflow, mocking patterns, custom matchers, and botiasloop-specific conventions.
metadata:
  author: botiasloop
  version: "1.0"
---

# RSpec Testing for botiasloop

## Quick Start

botiasloop follows strict TDD with 90% minimum coverage. Tests should be readable, maintainable, and follow Ruby community conventions. Use `instance_double` for mocks, organize setup logically, and test both public and private methods.

## Prerequisites

- RSpec 3.13.2+
- Understanding of Ruby object model
- Familiarity with mocking/stubbing concepts

## Testing Philosophy

botiasloop follows Rails Doctrine principles:
- **Test-First Development**: Write failing test first, then implementation
- **90% coverage minimum**: SimpleCov enforces this in spec_helper.rb
- **Sharp knives**: Full testing access without artificial restrictions
- **Test behavior AND implementation**: Private methods are unit tested via `send`

### TDD Workflow

1. Write a failing test describing desired behavior
2. Write minimal code to make it pass
3. Refactor while keeping tests green
4. Repeat

Never write implementation code without a failing test first.

## Core Patterns

### 1. Organizing Test Structure

Group related declarations together with proper spacing:

```ruby
RSpec.describe Botiasloop::Agent do
  # 1. Let blocks and subject together
  let(:config) { instance_double(Botiasloop::Config, max_iterations: 10) }
  let(:agent) { described_class.new(config) }
  
  # 2. Empty line separates from hooks
  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
  end
  
  # 3. Another empty line before examples
  describe "#initialize" do
    it "accepts a config" do
      expect(agent.instance_variable_get(:@config)).to eq(config)
    end
  end
end
```

**Rules:**
- No empty lines after `describe`/`context` descriptions
- One empty line between example groups
- One empty line after `let`/`subject`/`before` blocks
- Group `let`/`subject` together, separate from hooks

### 2. Use describe for Methods, context for Scenarios

```ruby
# Good - describes what you're testing
describe "#chat" do
  context "when given a message" do
    it "returns a response" do
      # ...
    end
  end
  
  context "when conversation is provided" do
    it "uses the existing conversation" do
      # ...
    end
  end
end

# Bad - context describes methods
describe "#chat" do
  context "#initialize" do
    # ...
  end
end
```

### 3. Verified Doubles with instance_double

Always use `instance_double` over `double` to catch API mismatches:

```ruby
# Good - verifies methods exist on the class
let(:config) do
  instance_double(Botiasloop::Config,
    openrouter_model: "test/model",
    max_iterations: 10,
    searxng_url: "http://searxng:8080",
    openrouter_api_key: "test-api-key")
end

# Bad - no verification
let(:config) { double("config", openrouter_model: "test/model") }
```

**Note:** Use `double` only when the class doesn't exist yet or is dynamic.

### 4. Testing Private Methods

botiasloop unit tests private methods via `send`:

```ruby
describe "#system_prompt" do
  let(:registry) { Botiasloop::Tools::Registry.new }
  
  before do
    registry.register(Botiasloop::Tools::Shell)
  end
  
  it "includes ReAct guidance" do
    prompt = agent.send(:system_prompt, registry)
    expect(prompt).to include("You operate in a ReAct loop")
  end
  
  it "lists available tools" do
    prompt = agent.send(:system_prompt, registry)
    expect(prompt).to include("- shell: Execute a shell command")
  end
end
```

**Guidelines:**
- Private method tests live in separate `describe` blocks
- Pass required dependencies as arguments
- Focus on behavior, not implementation details

### 5. Complex Setup with before Blocks

For components with many dependencies, mock in `before` blocks:

```ruby
describe "#chat" do
  let(:agent) { described_class.new(config) }
  let(:conversation) { instance_double(Botiasloop::Conversation) }
  let(:mock_loop) { instance_double(Botiasloop::Loop) }
  let(:mock_chat) { double("chat") }
  
  before do
    allow(Botiasloop::Conversation).to receive(:new).and_return(conversation)
    allow(Botiasloop::Loop).to receive(:new).and_return(mock_loop)
    allow(conversation).to receive(:uuid).and_return("test-uuid")
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_tool)
    allow(mock_chat).to receive(:with_instructions)
  end
  
  it "creates a conversation if none provided" do
    expect(Botiasloop::Conversation).to receive(:new)
    agent.chat("Hello")
  end
end
```

**Tips:**
- Use `allow` for default stubs, `expect` for assertions
- Keep related mocks together
- Name doubles descriptively (`mock_chat` vs `chat`)

### 6. Custom Matchers for Domain Concepts

Define matchers for common assertions:

```ruby
# In spec_helper.rb
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
  end
  
  def have_command(name)
    CommandRegistryMatcher.new(name)
  end
end

RSpec.configure do |config|
  config.include(CommandRegistryMatchers)
end

# Usage in tests
expect(registry).to have_command(:help)
```

### 7. Bulk Assertions

Use `is_expected.to` for simple cases, `aggregate_failures` for related checks:

```ruby
# Good - single subject, multiple related expectations
it "returns result with all fields" do
  result = tool.execute(command: "echo hello")
  
  aggregate_failures do
    expect(result[:stdout]).to eq("hello\n")
    expect(result[:exit_code]).to eq(0)
    expect(result[:success?]).to be true
  end
end

# Good - using is_expected with subject
subject(:result) { tool.execute(command: "echo hello") }

it { is_expected.to include(stdout: "hello\n") }
it { is_expected.to include(exit_code: 0) }
```

**Rule:** One expectation per example when possible, or use `aggregate_failures` for related checks.

### 8. Stubbing External Dependencies

Use WebMock for HTTP, VCR for complex external calls:

```ruby
# spec_helper.rb setup
require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") do
    ENV.fetch("OPENROUTER_API_KEY", "test-api-key")
  end
end

# In tests
RSpec.describe Botiasloop::Tools::WebSearch, :vcr do
  it "searches the web" do
    result = tool.execute(query: "ruby programming")
    expect(result).to include("ruby")
  end
end
```

**Guidelines:**
- Use `:vcr` metadata tag for HTTP requests
- Always filter sensitive data (API keys, tokens)
- Record cassettes once, commit them to repo

### 9. Testing Tool Classes

Tools inherit from `RubyLLM::Tool`. Test the `execute` method:

```ruby
RSpec.describe Botiasloop::Tools::Shell do
  describe "#execute" do
    let(:tool) { described_class.new }
    
    it "executes a simple command" do
      result = tool.execute(command: "echo hello")
      expect(result[:stdout]).to eq("hello\n")
    end
    
    it "captures stderr separately" do
      result = tool.execute(command: "echo error >&2")
      expect(result[:stderr]).to eq("error\n")
      expect(result[:stdout]).to eq("")
    end
    
    it "returns non-zero exit code on failure" do
      result = tool.execute(command: "exit 1")
      expect(result[:exit_code]).to eq(1)
      expect(result[:success?]).to be false
    end
  end
  
  describe "Result" do
    let(:result) { described_class::Result.new("stdout", "stderr", 0) }
    
    it "provides accessors" do
      expect(result.stdout).to eq("stdout")
      expect(result.stderr).to eq("stderr")
      expect(result.exit_code).to eq(0)
    end
    
    it "converts to string" do
      expect(result.to_s).to include("stdout")
    end
  end
end
```

### 10. Avoid Common Anti-patterns

```ruby
# Bad - Don't use should in descriptions
it "should return the summary" do
  # ...
end

# Good
it "returns the summary" do
  # ...
end

# Bad - Don't use instance variables
before do
  @user = User.new
end

it "works" do
  expect(@user.name).to eq("test")
end

# Good - Use let
let(:user) { User.new(name: "test") }

it "works" do
  expect(user.name).to eq("test")
end

# Bad - Don't use before(:all) for database records
before(:all) do
  @user = User.create!(name: "test")  # Won't be rolled back!
end

# Good - Use let! or before(:each)
let!(:user) { User.create!(name: "test") }  # Rolled back after each example
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run single file
bundle exec rspec spec/unit/agent_spec.rb

# Run specific line
bundle exec rspec spec/unit/agent_spec.rb:42

# With coverage
bundle exec rspec
open coverage/index.html

# Run linter
bundle exec standardrb
bundle exec standardrb --fix
```

## References

- [RSpec Style Guide Summary](references/rspec-style-guide.md) - Key patterns from rspec.rubystyle.guide
- [Thoughtbot Testing Guide](references/thoughtbot-guide.md) - Best practices from thoughtbot/guides
- [botiasloop AGENTS.md](/AGENTS.md) - Project-specific conventions
- [RSpec Official Docs](https://rspec.info/) - Complete RSpec documentation
