# AGENTS.md - Developer Guide for botiasloop

This document contains essential information for AI agents working on the botiasloop project.

## Project Overview

botiasloop is a minimal agentic AI application built on the ReAct (Reasoning + Acting) loop pattern. It's a Ruby gem that provides an AI agent with shell access and web search capabilities via OpenRouter.

## Rails Doctrine

We follow the [Rails Doctrine](https://rubyonrails.org/doctrine) principles:

- **Optimize for programmer happiness**: Write beautiful, readable Ruby code
- **Convention over Configuration**: Sensible defaults, minimal setup required
- **The menu is omakase**: Curated stack (ruby_llm, StandardRB, RSpec)
- **No one paradigm**: Practical over pure - use what works
- **Provide sharp knives**: Full shell access without restrictions by design

## Test-First Development (TDD)

All features must be built using TDD:

1. Write a failing test that describes the desired behavior
2. Write minimal code to make the test pass
3. Refactor while keeping tests green
4. Repeat

Never write implementation code without a failing test first. Tests should cover both success and error paths.

## Linting

Code must pass StandardRB with zero offenses:

```bash
# Check for offenses
bundle exec standardrb

# Auto-fix offenses
bundle exec standardrb --fix
```

Never commit code with linting errors. The CI will reject it.

## Build/Lint/Test Commands

```bash
# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/unit/agent_spec.rb

# Run a specific test by line number
bundle exec rspec spec/unit/agent_spec.rb:42

# Run linter
bundle exec standardrb

# Auto-fix linting issues
bundle exec standardrb --fix

# Run default rake task (tests + lint)
bundle exec rake

# Check test coverage (after running tests)
open coverage/index.html
```

## Code Style Guidelines

### General
- Ruby 3.4+ required
- 100 character line limit
- Frozen string literals: `# frozen_string_literal: true` at top of every file
- No trailing whitespace

### Imports
- Group requires: stdlib first, then gems, then local files
- Example:
  ```ruby
  require "json"
  require "securerandom"
  require "ruby_llm"
  require_relative "botiasloop/version"
  ```

### Formatting
- 2 spaces for indentation
- No parentheses for method calls without arguments
- Use parentheses for method calls with arguments
- Prefer `attr_reader` over trivial reader methods
- **Preserve string quote style**: Keep existing quotes as-is (single quotes stay single, double quotes stay double)
- **New strings**: Always use double quotes for any new string literals

### Naming Conventions
- Classes: PascalCase (e.g., `ToolRegistry`, `WebSearch`)
- Methods: snake_case (e.g., `execute_tool`, `build_observation`)
- Constants: SCREAMING_SNAKE_CASE (e.g., `MAX_ITERATIONS`, `EXIT_COMMANDS`)
- Files: snake_case matching class name (e.g., `web_search.rb` for `WebSearch`)

### Error Handling
- Use custom `Botiasloop::Error` class for domain errors
- Let exceptions bubble up (no global rescue)
- Tool failures retry 3 times before raising
- Configuration errors raise immediately

### Documentation
- Use YARD format for all public methods
- Include `@param`, `@return`, and `@raise` tags
- Example:
  ```ruby
  # Execute a shell command
  # @param command [String] Shell command to execute
  # @return [Hash] Result with stdout, stderr, exit_code
  # @raise [Error] On execution failure
  ```

## Architecture Patterns

### Tool System
Tools inherit from `RubyLLM::Tool`:
- Use `description` macro to define tool purpose
- Use `param` macro to define parameters (use `desc:`, not `description:`)
- Implement `execute(**args)` method
- Define `self.tool_name` for registry identification

### ReAct Loop
- Loop runs up to `max_iterations` (default: 20)
- Each iteration: ask LLM → check for tool call → execute tool → continue
- Tool results added via `@chat.add_tool_result(tool_call.id, observation)`
- Final answer returned when no tool call present

### Configuration
- YAML config at `~/.config/botiasloop/config.yml`
- Environment variables override YAML (e.g., `BOTIASLOOP_SEARXNG_URL`)
- Required: `BOTIASLOOP_API_KEY` for OpenRouter

## Critical Implementation Details

### RubyLLM Integration
**CRITICAL**: Tools must be registered with chat instance:
```ruby
chat = RubyLLM.chat(model: config.model)
chat.with_tool(Tools::Shell)
chat.with_tool(Tools::WebSearch.new(searxng_url))
```

**CRITICAL**: Use correct Message API:
- `response.tool_call?` (singular) - returns boolean
- `response.tool_call` - returns ToolCall object
- `tool_call.id`, `tool_call.name`, `tool_call.arguments`

### Conversation Persistence
- Stored as JSONL at `~/conversations/<uuid>.jsonl`
- Each line: `{"role": "user", "content": "...", "timestamp": "..."}`
- Requires `require "fileutils"` for directory creation

### Interactive Mode
- Create conversation once, reuse for all messages
- Log "Starting conversation" only on first message
- Exit commands: `exit`, `quit`, `\q`, Ctrl+C (Interrupt)

## Testing Guidelines

### CRITICAL: Test Isolation - Never Touch Real Data

**NEVER** allow tests to touch real user data, databases, config files, or anything outside the development directory:

- **Database**: Always use in-memory SQLite (`Sequel.sqlite`) for tests
- **Config files**: Never read/write to `~/.config/botiasloop/`
- **User data**: Never touch `~/conversations/` or user home directory
- **System paths**: Stay within project directory and temp directories only

**Pattern for Database Tests:**
```ruby
# spec_helper.rb - Set up in-memory database BEFORE loading botiasloop
require "sequel"

# Pre-create the Database class with in-memory database 
# to prevent file-based auto-connect at bottom of database.rb
module Botiasloop
  class Database
    @db = Sequel.sqlite  # In-memory only!
  end
end
require_relative "../lib/botiasloop/database"
Botiasloop::Database.setup!

# Now load the rest of botiasloop
require "botiasloop"
```

**Pattern for Individual Test Files:**
```ruby
RSpec.describe Botiasloop::Database do
  before do
    # Ensure in-memory database for each test
    Botiasloop::Database.disconnect
    Botiasloop::Database.instance_variable_set(:@db, Sequel.sqlite)
    Botiasloop::Database.setup!
  end
  
  # ... tests that safely use in-memory database
end
```

### Mock External Dependencies
- Mock `RubyLLM.chat` and chat instances
- Mock `Botiasloop::Conversation` for unit tests
- Use WebMock for HTTP requests (WebSearch tool)
- Mock ALL filesystem paths to use temp directories

### Test Structure
```ruby
RSpec.describe Botiasloop::Component do
  let(:mock_dep) { double("dep") }
  
  before do
    allow(Dependency).to receive(:new).and_return(mock_dep)
  end
  
  it "does something" do
    expect(mock_dep).to receive(:method).with(args)
    subject.do_something
  end
end
```

### Coverage Requirements
- Minimum 90% line coverage
- Test both success and error paths
- Test tool execution with mocked responses

## Dependencies

Runtime:
- `ruby_llm ~> 1.12.1` - LLM integration

Development:
- `rspec ~> 3.13.2` - Testing
- `standard ~> 1.54.0` - Linting
- `simplecov ~> 0.22.0` - Coverage
- `webmock ~> 3.26.1` - HTTP mocking
- `vcr ~> 6.4.0` - HTTP recording

## Development Environment (mise)

This project uses [mise](https://mise.jdx.dev/) (formerly rtx) for managing Ruby version and dependencies. mise is a unified version manager for development tools.

### Setup

```bash
# Install mise if not already installed
curl https://mise.run | sh

# Install Ruby and dependencies (run in project root)
mise install
```

### Common Commands

```bash
# Show current tool versions
mise list

# Install/update dependencies from mise.toml
mise install

# Run commands with mise-managed Ruby
mise exec ruby -- bundle install
mise exec ruby -- bundle exec rspec

# Or activate mise in your shell
mise activate
# Then use commands directly
bundle install
bundle exec rspec
```

### Configuration

- `.mise.toml` - Project-level tool configuration
- `.tool-versions` - Alternative version file (legacy)

## Release Workflow

The project uses GitHub Actions to automatically publish the gem to both RubyGems and GitHub Packages when the version is updated.

### How It Works

1. CI runs on every PR and push to main (test + lint)
2. Release runs only when:
   - Push to main branch
   - `lib/botiasloop/version.rb` is modified
   - All tests and linting pass

### Publishing a New Version

1. Update the version in `lib/botiasloop/version.rb`:
   ```ruby
   VERSION = "0.0.3"  # bump the version number
   ```
2. Commit and push to main
3. CI will run tests and linting
4. If all pass, the gem will be published to:
   - RubyGems (https://rubygems.org/gems/botiasloop)
   - GitHub Packages

## Gateway Management

The gateway runs as a systemd user service. To test changes locally:

### Installing and Running

```bash
# Install and enable (auto-start on login)
botiasloop gateway enable

# Start now
botiasloop gateway start
```

### Restarting After Code Changes

**Important**: The `botiasloop gateway restart` command may not work correctly in some environments. Use this process instead:

```bash
# 1. Kill any running gateway processes
pkill -f "botiasloop gateway" || true

# 2. Install the updated gem
mise exec -- bundle exec rake install

# 3. Start fresh (not restart - this ensures clean state)
botiasloop gateway start
```

### Other Useful Commands

```bash
botiasloop gateway status   # Check if running
botiasloop gateway logs     # View logs
botiasloop gateway stop    # Stop the service
botiasloop gateway disable # Disable auto-start
```

### Debugging

If the gateway isn't responding, check:
1. Is the service running? `botiasloop gateway status`
2. Check logs: `botiasloop gateway logs`
3. Kill stale processes: `pkill -f "botiasloop gateway"`
 4. Start fresh: `botiasloop gateway start`


This gem follows the "sharp knives" philosophy - it provides full shell access without restrictions. This is intentional. The gem is designed for dedicated infrastructure, not personal devices.
