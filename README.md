# botiasloop

A minimal agentic AI application built on the ReAct (Reasoning + Acting) loop pattern. A Ruby gem inspired by nanobot but designed with Rails doctrine principles.

## Installation

```bash
gem install botiasloop
```

## Configuration

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

## Usage

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

### Gateway Mode

Run botiasloop as a persistent gateway for Telegram and other channels:

```bash
# Start the gateway (foreground)
botiasloop gateway
```

### Systemd Service (Linux)

Manage botiasloop as a systemd user service for background operation and auto-start on login:

```bash
# Install and enable service (auto-start on login)
botiasloop gateway enable

# Start the service
botiasloop gateway start

# Check service status
botiasloop gateway status

# Restart the service
botiasloop gateway restart

# Stop the service
botiasloop gateway stop

# Disable and uninstall service
botiasloop gateway disable
```

The service runs in the background and starts automatically when you log in. View logs with:

```bash
journalctl --user -u botiasloop.service -f
```

### Conversation Persistence

Conversations are automatically saved to:
- `~/conversations/<uuid>.jsonl`

Each line contains a JSON object with role, content, and timestamp.

## Philosophy

botiasloop intentionally provides full shell access without restrictions. This is a sharp knife designed for dedicated infrastructure. No sandboxing, no restrictions - raw power for those who need it.

## Development

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec standardrb

# Check coverage
open coverage/index.html
```

## License

MIT
