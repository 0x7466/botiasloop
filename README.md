# 🤖 BotiasLoop

[![Ruby](https://img.shields.io/badge/ruby-3.4%2B-red.svg)](https://www.ruby-lang.org/)
[![Gem Version](https://img.shields.io/gem/v/botiasloop.svg)](https://rubygems.org/gems/botiasloop)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![StandardRB](https://img.shields.io/badge/code_style-standard-success.svg)](https://github.com/standardrb/standard)
[![Tests](https://img.shields.io/badge/tests-rspec-brightgreen.svg)]()

> **Think. Act. Repeat.**
>
> A minimal agentic AI application built on the ReAct (Reasoning + Acting) loop pattern.

BotiasLoop gives your AI agent **full shell access** and **web search capabilities** via multiple LLM providers. Designed for dedicated infrastructure following the Rails Doctrine — beautiful code, sensible defaults, sharp knives.

---

## 🚀 Installation

### Prerequisites

- Ruby 3.4 or higher
- API key from your preferred LLM provider (see supported providers below)
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

---

## ⚡ Quick Start

```bash
# 1. Configure your API key
export BOTIASLOOP_API_KEY="your-api-key"

# 2. Start chatting
botiasloop cli

# 3. Ask anything!
You: What's the weather in Tokyo?

Agent: I'll search for the current weather in Tokyo for you.

[Tool] Executing web_search with arguments: {"query"=>"current weather Tokyo Japan"}

The weather in Tokyo is currently...
```

---

## ✨ Features

### 🧠 Core Capabilities

- **ReAct Loop** — AI reasons, acts using tools, observes results, and repeats
- **12+ LLM Providers** — OpenRouter, OpenAI, Anthropic, Gemini, DeepSeek, Mistral, Perplexity, Ollama, and more
- **Shell Access** — Execute any shell command (full system access)
- **Web Search** — Search the web via SearXNG integration
- **Token Tracking** — Monitor input/output tokens per conversation

### 💬 Channels & Interfaces

- **CLI Mode** — Interactive REPL for local usage
- **Telegram Bot** — Chat with your agent anywhere
- **Multi-Channel** — Run CLI + Telegram simultaneously
- **One-Shot Mode** — Single command execution

### 🗄️ Conversation Management

- **Persistent Storage** — JSONL-backed conversation history
- **UUID Tracking** — Every conversation has a unique ID
- **Auto-Labeling** — Conversations get human-readable names
- **Conversation Switching** — Jump between active chats
- **Archiving** — Keep your workspace clean

### 🛠️ Built-in Tools

| Tool | Description |
|------|-------------|
| 🔧 `shell` | Execute any shell command |
| 🔍 `web_search` | Search the web via SearXNG |

### 📚 Skills System

Skills follow the [agentskills.io](https://agentskills.io) specification:

- Load default skills from `data/skills/`
- Load custom skills from `~/skills/`
- Progressive disclosure: name/description in system prompt, full content on demand
- Includes `skill-creator` skill for creating new skills

### ⌨️ Slash Commands

Manage conversations with intuitive commands:

| Command | Description |
|---------|-------------|
| `/new` | Start a new conversation |
| `/switch <label\|uuid>` | Switch to a different conversation |
| `/label <name>` | Label the current conversation |
| `/conversations` | List all conversations |
| `/reset` | Clear current conversation history |
| `/compact` | Summarize and archive old messages |
| `/status` | Show current model, token usage |
| `/archive` | Archive old conversations |
| `/system_prompt` | Show current system prompt |
| `/verbose` | Toggle verbose mode (show tool calls) |
| `/help` | Show available commands |

---

## 🎨 Philosophy

### Sharp Knives 🔪

BotiasLoop intentionally provides **full shell access without restrictions**. This is a feature, not a bug. It's designed for dedicated infrastructure where raw power is needed, not personal devices.

The agent can:
- Execute any shell command
- Read, write, and delete any file
- Install software
- Modify system configuration
- Access network resources

### Rails Doctrine 🚂

Following the [Rails Doctrine](https://rubyonrails.org/doctrine):

- **Optimize for programmer happiness** — Beautiful, readable Ruby code
- **Convention over Configuration** — Sensible defaults, minimal setup required
- **The menu is omakase** — Curated stack (ruby_llm, StandardRB, RSpec)
- **No one paradigm** — Practical over pure - use what works

---

## 📖 Usage

### CLI Mode

Start interactive REPL:

```bash
botiasloop cli
```

Exit with: `exit`, `quit`, `\q`, or Ctrl+C

### One-Shot Mode

Send a single message:

```bash
botiasloop "What's the weather in Tokyo?"
```

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
botiasloop gateway logs     # View service logs
botiasloop gateway disable  # Disable boot auto-start and uninstall
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

You: /verbose

Agent: **Verbose mode enabled** — You will now see reasoning and tool execution details.

You: exit

Goodbye!
```

---

## ⚙️ Configuration

Create `~/.config/botiasloop/config.yml`:

### OpenRouter (Recommended)

```yaml
providers:
  openrouter:
    api_key: "your-openrouter-api-key"
    model: "moonshotai/kimi-k2.5"
```

### OpenAI

```yaml
providers:
  openai:
    api_key: "your-openai-api-key"
    model: "gpt-4o"
```

### Anthropic

```yaml
providers:
  anthropic:
    api_key: "your-anthropic-api-key"
    model: "claude-3-5-sonnet-20241022"
```

### Ollama (Local)

```yaml
providers:
  ollama:
    api_base: "http://localhost:11434/v1"
    model: "llama3.2"
```

### Full Configuration Example

```yaml
# Required: Provider configuration
providers:
  openrouter:
    api_key: "your-api-key"
    model: "moonshotai/kimi-k2.5"

# Optional: Web search configuration
tools:
  web_search:
    searxng_url: "http://localhost:8080"

# Optional: Maximum ReAct iterations (default: 20)
max_iterations: 20

# Optional: Telegram channel
channels:
  telegram:
    bot_token: "your-telegram-bot-token"
    allowed_users: ["your_telegram_username"]  # Required: must contain at least one username

# Optional: Logging
logger:
  level: "info"  # debug, info, warn, error
  destination: "stdout"  # stdout, stderr, or path to log file
```

### Environment Variables

Environment variables override config file values:

| Variable | Description |
|----------|-------------|
| `BOTIASLOOP_API_KEY` | API key for the active provider |
| `BOTIASLOOP_SEARXNG_URL` | SearXNG URL for web search |
| `BOTIASLOOP_LOG_LEVEL` | Log level (debug, info, warn, error) |

---

## 🔒 Security

⚠️ **IMPORTANT**: BotiasLoop provides **full shell access**. The AI agent can:
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

---

## 🛠️ Development

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

---

## 📁 Architecture

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
│       ├── conversation.rb     # Conversation persistence
│       ├── conversation_manager.rb  # Multi-conversation management
│       ├── auto_label.rb       # Auto-labeling conversations
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
│       ├── channels_manager.rb # Multi-channel orchestration
│       └── systemd_service.rb  # Service management
├── data/
│   └── skills/                 # Default skills
├── spec/                       # Test suite
└── README.md                   # This file
```

---

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed planned features:

- **Persistent Memory** — Vector database for semantic search
- **Custom Tools** — Load tools from `~/tools/`
- **Conversation Compaction** — Automatic summarization
- **Subagents** — Specialized agent instances
- **Streaming Responses** — Real-time token display
- **Multi-Modal** — Image analysis, audio transcription
- **Web Dashboard** — Browser-based management UI
- **Plugin System** — Load plugins from gems

---

## 🤝 Contributing

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

- **Test-First** — All features built using TDD
- **Sharp Knives** — Keep raw power, minimal restrictions
- **Rails Doctrine** — Optimize for programmer happiness
- **Privacy First** — Local-first, user-controlled data
- **Unix Philosophy** — Do one thing well, compose with other tools

---

## 📜 License

MIT License — see [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

Built by [Tobias Feistmantl](https://github.com/0x7466) with inspiration from nanobot and the Ruby on Rails doctrine.

Powered by:
- [ruby_llm](https://github.com/crmne/ruby_llm) — Unified LLM API
- [OpenRouter](https://openrouter.ai/) — Unified LLM API gateway
- [SearXNG](https://docs.searxng.org/) — Privacy-respecting metasearch

---

**⚡ Built with sharp knives. Use responsibly.**
