# botiasloop - Implementation Plan

## Overview

botiasloop is a minimal agentic AI application built on the ReAct (Reasoning + Acting) loop pattern. It's a Ruby gem inspired by nanobot but designed with Rails doctrine principles and extreme minimalism for v0.0.1.

## Core Philosophy

Following the Rails Doctrine:
- **Optimize for programmer happiness**: Beautiful, readable Ruby code
- **Convention over Configuration**: Sensible defaults, minimal setup
- **Omakase**: Curated stack (ruby_llm, StandardRB, RSpec)
- **Provide sharp knives**: Full shell access without restrictions
- **No one paradigm**: Practical over pure

**botiasloop intentionally provides full shell access.** Raw power without restrictions. This is the foundation of the gem.

## Architecture

### Directory Structure

```
botiasloop/
├── bin/
│   └── botiasloop                    # CLI executable
├── lib/
│   ├── botiasloop.rb                 # Main entry point
│   └── botiasloop/
│       ├── version.rb                # Version constant
│       ├── agent.rb                  # Main orchestrator
│       ├── loop.rb                   # ReAct cycle implementation
│       ├── config.rb                 # YAML configuration loader
│       ├── conversation.rb           # UUID generation and persistence
│       └── tools/
│           ├── registry.rb           # Tool registration system
│           ├── shell.rb              # Shell execution tool
│           └── web_search.rb         # SearXNG search tool
├── spec/
│   ├── spec_helper.rb                # RSpec configuration
│   ├── unit/                         # Unit tests
│   │   ├── botiasloop_spec.rb
│   │   ├── agent_spec.rb
│   │   ├── config_spec.rb
│   │   ├── conversation_spec.rb
│   │   ├── loop_spec.rb
│   │   └── tools/
│   │       ├── registry_spec.rb
│   │       ├── shell_spec.rb
│   │       └── web_search_spec.rb
│   └── integration/                  # Integration tests (VCR)
│       └── agent_spec.rb
├── .rspec                            # RSpec configuration
├── .standard.yml                     # StandardRB configuration
├── .gitignore
├── Gemfile                           # Dependencies
├── Rakefile                          # Build tasks
├── botiasloop.gemspec                # Gem specification (see Gemspec Details below)
├── PLAN.md                           # This document
└── README.md                         # User documentation
```

## Components

### 1. Configuration (`lib/botiasloop/config.rb`)

**Responsibilities:**
- Load YAML configuration from `~/.config/botiasloop/config.yml`
- Provide default values
- Validate required settings

**Configuration File Location:**
- Path: `~/.config/botiasloop/config.yml`

**Default Configuration:**
```yaml
model: moonshotai/kimi-k2.5
max_iterations: 20
searxng_url: http://localhost:8080
```

**Environment Variables:**
- `BOTIASLOOP_API_KEY` (required): OpenRouter API key
- `BOTIASLOOP_SEARXNG_URL` (optional): Override SearXNG URL

**Interface:**
```ruby
class Config
  def self.load(path = nil) -> Config
  def model -> String
  def max_iterations -> Integer
  def searxng_url -> String
  def api_key -> String
end
```

### 2. Conversation (`lib/botiasloop/conversation.rb`)

**Responsibilities:**
- Generate UUID for each conversation
- Persist messages to JSONL file
- Load conversation history

**Storage Location:**
- Path: `~/conversations/<uuid>.jsonl`
- Format: One JSON object per line

**JSONL Format:**
```json
{"role": "user", "content": "Hello", "timestamp": "2026-02-20T10:00:00Z"}
{"role": "assistant", "content": "Hi there!", "timestamp": "2026-02-20T10:00:01Z"}
```

**Interface:**
```ruby
class Conversation
  def initialize(uuid = nil) -> Conversation
  def uuid -> String
  def add(role, content) -> void
  def history -> Array<Hash>
  def path -> String
end
```

### 3. Tools

#### Tool Registry (`lib/botiasloop/tools/registry.rb`)

**Responsibilities:**
- Register available tools
- Provide tool schemas to LLM via ruby_llm
- Execute tool calls

**Interface:**
```ruby
class Tools::Registry
  def initialize -> Registry
  def register(tool) -> void
  def schemas -> Array<Hash>
  def execute(name, arguments) -> Result
  def names -> Array<String>
end
```

#### Shell Tool (`lib/botiasloop/tools/shell.rb`)

**Responsibilities:**
- Execute shell commands
- Return stdout, stderr, exit code
- No restrictions (sharp knife)

**ruby_llm Tool Definition:**
```ruby
class Tools::Shell < RubyLLM::Tool
  description "Execute a shell command and return the output"
  param :command, type: :string, description: "The shell command to execute", required: true

  def execute(command:)
    # Execute command
  end
end
```

**Interface:**
```ruby
class Tools::Shell < RubyLLM::Tool
  def execute(command:) -> Result
  
  class Result
    def stdout -> String
    def stderr -> String
    def exit_code -> Integer
    def success? -> Boolean
  end
end
```

#### Web Search Tool (`lib/botiasloop/tools/web_search.rb`)

**Responsibilities:**
- Query SearXNG JSON API
- Return search results

**ruby_llm Tool Definition:**
```ruby
class Tools::WebSearch < RubyLLM::Tool
  description "Search the web using SearXNG"
  param :query, type: :string, description: "The search query", required: true

  def execute(query:)
    # Query SearXNG
  end
end
```

**Interface:**
```ruby
class Tools::WebSearch < RubyLLM::Tool
  def initialize(searxng_url) -> WebSearch
  def execute(query:) -> Result
  
  class Result
    def results -> Array<Hash>
    def to_s -> String
  end
end
```

### 4. ReAct Loop (`lib/botiasloop/loop.rb`)

**Responsibilities:**
- Implement ReAct pattern: Reason → Action → Observation
- Manage iteration limit (max 20)
- Handle tool execution and retries (3 attempts)
- Build conversation context

**ReAct Pattern:**
1. User provides input
2. LLM reasons and decides on action (or final answer)
3. If action: Execute tool, get observation
4. Add observation to context
5. Repeat from step 2 until final answer or max iterations

**Interface:**
```ruby
class Loop
  def initialize(chat, registry, max_iterations: 20) -> Loop
  def run(conversation, user_input) -> String
  
  private
  def iterate(messages) -> Response
  def execute_tool(tool_call) -> Observation
  def build_observation(result) -> String
end
```

### 5. Agent (`lib/botiasloop/agent.rb`)

**Responsibilities:**
- Orchestrate components
- Handle conversation lifecycle
- Provide main interface
- Configure ruby_llm with OpenRouter

**Interface:**
```ruby
class Agent
  def initialize(config = nil) -> Agent
  def chat(message, conversation: nil) -> String
  def interactive -> void
end
```

### 6. CLI (`bin/botiasloop`)

**Modes:**
1. **One-shot**: `botiasloop "what's the weather?"`
2. **Interactive**: `botiasloop` (REPL)

**Exit Commands (Interactive Mode):**
- `exit`, `quit`, `\q`, `Ctrl+C`

**Implementation:**
```ruby
#!/usr/bin/env ruby

require 'botiasloop'

if ARGV.empty?
  # Interactive mode
  agent = Botiasloop::Agent.new
  agent.interactive
else
  # One-shot mode
  agent = Botiasloop::Agent.new
  puts agent.chat(ARGV.join(" "))
end
```

## CLI Usage Examples

### Installation

```bash
gem install botiasloop
```

### Configuration

Create `~/.config/botiasloop/config.yml`:

```yaml
model: moonshotai/kimi-k2.5
max_iterations: 20
searxng_url: http://localhost:8080
```

Set environment variable:

```bash
export BOTIASLOOP_API_KEY="your-openrouter-api-key"
```

### One-shot Mode

```bash
# Ask a question
botiasloop "What's the weather in Tokyo?"

# Multi-word query
botiasloop "Search for the latest Ruby 3.4 features"

# With shell command
botiasloop "List all files in the current directory using ls -la"
```

### Interactive Mode

```bash
# Start interactive session
botiasloop

# You: What's the weather in Tokyo?
# Agent: Let me search for that...
# [Search results and response]
# 
# You: exit
# [Session ends]
```

### Conversation Persistence

Conversations are automatically saved to:
- `~/conversations/<uuid>.jsonl`

Each line contains a JSON object with role, content, and timestamp.

## Dependencies

### Runtime
- `ruby_llm` (~> 1.12.1): Unified LLM API with OpenRouter support
- `logger`: Standard Ruby logging

### Development
- `rspec` (~> 3.13.2): Testing framework (stable)
- `vcr` (~> 6.4.0): Record/replay HTTP interactions
- `webmock` (~> 3.26.1): HTTP request stubbing
- `standard` (~> 1.54.0): Ruby linting/formatting
- `simplecov` (~> 0.22.0): Code coverage

## Testing Strategy

### Test-First Development (TDD)

All components will be built using TDD:
1. Write failing test
2. Write minimal code to pass
3. Refactor
4. Repeat

### Test Structure

**Unit Tests:**
- Test individual classes in isolation
- Mock dependencies
- Fast execution

**Integration Tests:**
- Test component interactions
- Use VCR for HTTP interactions
- Slower but test real behavior

### Coverage Target

90-100% code coverage using SimpleCov

## Implementation Order

1. **Project Setup**
   - Create directory structure
   - Initialize git repository
   - Create gemspec
   - Setup RSpec
   - Setup StandardRB
   - Setup SimpleCov

2. **Version & Entry Point**
   - `lib/botiasloop/version.rb`
   - `lib/botiasloop.rb`

3. **Configuration (TDD)**
   - Write specs first
   - Implement Config class

4. **Conversation (TDD)**
   - Write specs first
   - Implement Conversation class

5. **Tools (TDD)**
   - Write specs first
   - Implement Registry
   - Implement Shell tool
   - Implement WebSearch tool

6. **ReAct Loop (TDD)**
   - Write specs first
   - Implement Loop class

7. **Agent (TDD)**
   - Write specs first
   - Implement Agent class
   - Configure ruby_llm with OpenRouter

8. **CLI**
   - Create bin/botiasloop
   - Test manually

9. **Documentation**
   - Write README.md
   - Add YARD documentation

10. **Final Review**
    - Run all tests
    - Check coverage
    - Run StandardRB
    - Create initial commit

## Code Style

### StandardRB Configuration

```yaml
# .standard.yml
parallel: true
format: progress
```

### Line Length

100 characters maximum

### Documentation

Use YARD format for all public methods:

```ruby
# Load configuration from file
#
# @param path [String, nil] Path to config file (default: ~/.config/botiasloop/config.yml)
# @return [Config] Configuration instance
# @raise [Errno::ENOENT] If config file not found
```

## Error Handling

- Use standard Ruby exceptions
- No global rescue (let exceptions bubble up)
- Tool failures retry 3 times, then raise
- Configuration errors raise immediately

## Logging

- Use standard Ruby Logger
- Output to stderr
- Plain text format
- INFO level (not configurable in v0.0.1)

Example:
```ruby
logger = Logger.new($stderr)
logger.info "Starting conversation #{uuid}"
```

## Security Considerations

**botiasloop intentionally provides full shell access.**

This is a sharp knife. The gem is designed to run on dedicated infrastructure, not personal devices. No sandboxing, no restrictions.

Future versions may add:
- Allow lists for commands
- Confirmation prompts
- Sandbox mode

But the core philosophy remains: raw power for those who need it.

## ruby_llm Integration

The gem uses ruby_llm (v1.12.1) for LLM communication:

### Configuration

```ruby
RubyLLM.configure do |config|
  config.openrouter_api_key = ENV['BOTIASLOOP_API_KEY']
end
```

### Chat Initialization

```ruby
chat = RubyLLM.chat(model: config.model)
chat.with_tool(Tools::Shell)
chat.with_tool(Tools::WebSearch)
```

### Tool Definition

Tools inherit from `RubyLLM::Tool`:

```ruby
class Shell < RubyLLM::Tool
  description "Execute shell commands"
  param :command, type: :string, required: true
  
  def execute(command:)
    # Implementation
  end
end
```

## Future Enhancements (Post v0.0.1)

- Persistent memory between sessions
- Additional LLM providers
- More tools (file operations, API calls)
- Streaming responses
- Configuration validation
- Plugin system
- Multi-modal support

## Success Criteria

v0.0.1 is complete when:

1. All tests pass (RSpec)
2. Code coverage >= 90%
3. StandardRB passes with no offenses
4. CLI works in both one-shot and interactive modes
5. Can successfully execute ReAct loop with shell and web_search tools
6. Conversations persist to JSONL files
7. README documents basic usage

## Development Workflow

1. Create feature branch from main
2. Write tests first
3. Implement feature
4. Run tests: `bundle exec rspec`
5. Check coverage: `open coverage/index.html`
6. Run linter: `bundle exec standardrb`
7. Commit with descriptive message
8. Push branch
9. Create PR (if collaborating)
10. Merge to main

## Initial Commit Contents

The initial commit will include:
- Complete project structure
- All source files
- All test files
- Configuration files
- README.md
- PLAN.md

## Gemspec Details

The `botiasloop.gemspec` file will contain:

```ruby
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
  
  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.13.2"
  spec.add_development_dependency "vcr", "~> 6.4.0"
  spec.add_development_dependency "webmock", "~> 3.26.1"
  spec.add_development_dependency "standard", "~> 1.54.0"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
end
```

## Notes

- Ruby 3.4+ required
- Uses mise for Ruby version management
- Follows RubyGems naming conventions
- MIT License
