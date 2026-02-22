# BotiasLoop

A minimal agentic AI application built on the ReAct (Reasoning + Acting) loop pattern. BotiasLoop provides an AI agent with shell access and web search capabilities via OpenRouter, designed for dedicated infrastructure following the Rails Doctrine.

[![Ruby](https://img.shields.io/badge/ruby-3.4%2B-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![StandardRB](https://img.shields.io/badge/code_style-standard-success.svg)](https://github.com/standardrb/standard)

## Philosophy

**Sharp Knives**: BotiasLoop intentionally provides full shell access without restrictions. This is a feature, not a bug. It's designed for dedicated infrastructure where raw power is needed, not personal devices. The agent can execute any shell command, read any file, and make system changes.

Following the Rails Doctrine:
- **Optimize for programmer happiness**: Beautiful, readable Ruby code
- **Convention over Configuration**: Sensible defaults, minimal setup required
- **The menu is omakase**: Curated stack (ruby_llm, StandardRB, RSpec)
- **No one paradigm**: Practical over pure - use what works

## Features

### Core
- **ReAct Loop**: AI reasons, acts using tools, observes results, and repeats
- **Shell Access**: Execute any shell command (full system access)
- **Web Search**: Search the web via SearXNG
- **Conversation Persistence**: SQLite-backed conversation storage with UUID tracking
- **Token Tracking**: Monitor input/output tokens per conversation

### Channels
- **CLI Mode**: Interactive REPL for local usage
- **Telegram Bot**: Chat with the agent via Telegram
- **Multi-Channel**: Run multiple channels simultaneously
- **Boot Auto-Start**: systemd service with automatic startup on boot

### Commands
Slash commands for conversation management:
- `/new` - Start a new conversation
- `/switch <label|uuid>` - Switch to a different conversation
- `/label <name>` - Label the current conversation
- `/conversations` - List all conversations
- `/reset` - Clear current conversation history
- `/compact` - Summarize and archive old messages
- `/status` - Show current model, token usage
- `/archive` - Archive old conversations
- `/system_prompt` - Show current system prompt
- `/help` - Show available commands

### Skills System
Skills follow the [agentskills.io](https://agentskills.io) specification:
- Load default skills from `data/skills/`
- Load custom skills from `~/skills/`
- Progressive disclosure: name/description in system prompt, full content on demand
- Includes `skill-creator` skill for creating new skills

## Installation

### Prerequisites

- Ruby 3.4 or higher
- OpenRouter API key
- (Optional) SearXNG instance for web search

### Via RubyGems

```bash
gem install botiasloop
```

### From Source

```bash
git clone https://github.com/0x7466/botiasloop.git
cd botiasloop
bundle install
bundle exec rake install
```

### Using mise (Recommended)

```bash
# Install mise if not already installed
curl https://mise.run | sh

# Install Ruby and dependencies
mise install

# Run with mise-managed Ruby
mise exec ruby -- bundle install
```

## Configuration

Create `~/.config/botiasloop/config.yml`:

```yaml
# Required: OpenRouter configuration
providers:
  openrouter:
    api_key: "your-openrouter-api-key"  # Or set BOTIASLOOP_API_KEY env var
    model: "moonshotai/kimi-k2.5"       # Any OpenRouter model

# Optional: Web search configuration
tools:
  web_search:
    searxng_url: "http://localhost:8080"  # Your SearXNG instance

# Optional: Maximum ReAct iterations (default: 20)
max_iterations: 20

# Optional: Telegram channel
channels:
  telegram:
    bot_token: "your-telegram-bot-token"
    allowed_users: []  # Empty = allow all, or list specific user IDs
```

### Environment Variables

- `BOTIASLOOP_API_KEY` - OpenRouter API key (overrides config file)
- `BOTIASLOOP_SEARXNG_URL` - SearXNG URL (overrides config file)

## Usage

### CLI Mode

Start interactive REPL:

```bash
botiasloop cli
```

Exit with: `exit`, `quit`, `\q`, or Ctrl+C

### Gateway Mode (Telegram Bot)

Start the gateway to enable Telegram and other channels:

```bash
# Run in foreground
botiasloop gateway

# Systemd service management (boot auto-start)
botiasloop gateway enable   # Install and enable boot auto-start
botiasloop gateway start    # Start the service now
botiasloop gateway status   # Check service status
botiasloop gateway stop     # Stop the service
botiasloop gateway disable  # Disable boot auto-start and uninstall
```

### One-Shot Mode

Send a single message:

```bash
botiasloop "What's the weather in Tokyo?"
```

### Example Session

```bash
$ botiasloop cli

botiasloop v0.0.1 - Interactive Mode
Type 'exit', 'quit', or '\q' to exit

You: What files are in this directory?

Agent: I'll check what files are in the current directory for you.

[Tool] Executing shell with arguments: {"command"=>"ls -la"}

Exit: 0
Stdout:
total 128
drwxr-xr-x  10 user  staff   320 Feb 22 14:00 .
drwxr-xr-x   5 user  staff   160 Feb 22 13:00 ..
-rw-r--r--   1 user  staff  2345 Feb 22 14:00 README.md
...

Here are the files in your current directory...

You: /label my-project

Agent: **Conversation labeled as `my-project`**

You: exit

Goodbye!
```

## Development

### Setup

```bash
# Clone repository
git clone https://github.com/0x7466/botiasloop.git
cd botiasloop

# Install dependencies
bundle install
```

### Testing

Test-first development is required:

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/unit/agent_spec.rb

# Run specific test by line number
bundle exec rspec spec/unit/agent_spec.rb:42

# Check coverage (after running tests)
open coverage/index.html
```

### Linting

Code must pass StandardRB with zero offenses:

```bash
# Check for offenses
bundle exec standardrb

# Auto-fix offenses
bundle exec standardrb --fix
```

### Default Rake Task

```bash
# Run tests + linting
bundle exec rake
```

## Architecture

```
botiasloop/
├── bin/
│   └── botiasloop              # CLI executable
├── lib/
│   ├── botiasloop.rb           # Main entry point
│   └── botiasloop/
│       ├── agent.rb            # Main orchestrator
│       ├── loop.rb             # ReAct cycle implementation
│       ├── config.rb           # Configuration management
│       ├── conversation.rb     # Conversation persistence (SQLite)
│       ├── tool.rb             # Base tool class
│       ├── tools/
│       │   ├── registry.rb     # Tool registration
│       │   ├── shell.rb        # Shell execution
│       │   └── web_search.rb   # SearXNG search
│       ├── skills/
│       │   ├── skill.rb        # Skill model
│       │   ├── loader.rb       # Skill loading
│       │   └── registry.rb     # Skill registry
│       ├── commands/
│       │   ├── registry.rb     # Command registry
│       │   ├── context.rb      # Execution context
│       │   └── *.rb            # Individual commands
│       ├── channels/
│       │   ├── base.rb         # Channel base class
│       │   ├── cli.rb          # CLI channel
│       │   └── telegram.rb     # Telegram bot
│       └── channels_manager.rb # Multi-channel orchestration
├── data/
│   └── skills/                 # Default skills
├── spec/                       # Test suite
└── README.md                   # This file
```

## Security

⚠️ **IMPORTANT**: BotiasLoop provides full shell access. The AI agent can:
- Execute any shell command
- Read, write, and delete any file
- Install software
- Modify system configuration
- Access network resources

**Use only on dedicated infrastructure**, never on personal devices or production systems containing sensitive data.

### Future Security Features (Roadmap)
- Sandboxed execution (Docker/Firejail)
- Command whitelist/blacklist
- Confirmation for destructive operations
- Read-only mode option
- Secret management integration

## Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed planned features including:

- **Persistent Memory**: Vector database for semantic search
- **Custom Tools**: Load tools from `~/tools/`
- **Conversation Compaction**: Automatic summarization
- **Subagents**: Specialized agent instances
- **Streaming Responses**: Real-time token display
- **Multi-Modal**: Image analysis, audio transcription
- **Web Dashboard**: Browser-based management UI
- **Plugin System**: Load plugins from gems

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests first (TDD required)
4. Implement the feature
5. Ensure all tests pass: `bundle exec rspec`
6. Ensure zero linting offenses: `bundle exec standardrb`
7. Commit with descriptive message
8. Push to your fork
9. Create a Pull Request

### Development Principles

- **Test-First**: All features built using TDD
- **Sharp Knives**: Keep raw power, minimal restrictions
- **Rails Doctrine**: Optimize for programmer happiness
- **Privacy First**: Local-first, user-controlled data
- **Unix Philosophy**: Do one thing well, compose with other tools

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Built by [Tobias Feistmantl](https://github.com/0x7466) with inspiration from nanobot and the Ruby on Rails doctrine.

Powered by:
- [ruby_llm](https://github.com/crmne/ruby_llm) - Unified LLM API
- [OpenRouter](https://openrouter.ai/) - Unified LLM API gateway
- [SearXNG](https://docs.searxng.org/) - Privacy-respecting metasearch

---

**⚡ Built with sharp knives. Use responsibly.**
