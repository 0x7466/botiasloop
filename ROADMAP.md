# ROADMAP.md - botiasloop Development Roadmap

This document outlines the planned features and improvements for botiasloop.

## Priority Order

### 1. System Prompt
- [x] Pass to RubyLLM chat initialization
- [x] Default prompt establishes ReAct pattern and available tools

### 2. Channel Support
- [x] Create `Botiasloop::Channels` module
- [x] Each channel is a separate class with common interface
- [ ] Support multiple channels simultaneously
- [ ] **Webhook** channel - HTTP endpoint for integrations
- [x] **Telegram** channel - Bot API integration
- [ ] **Matrix** channel - Matrix protocol support
- [x] Handle channel-specific message formatting
- [x] Channel configuration in YAML

### 3. Slash Commands
- [ ] `/reset` - Clear conversation history
- [ ] `/status` - Show current model, token usage, iteration count
- [ ] `/model <name>` - Switch model for this conversation
- [ ] `/label <name>` - Set label for current conversation
- [ ] `/conversations` - List all conversations
- [ ] `/switch <label|uuid>` - Switch to different conversation
- [ ] `/new` - Start new conversation
- [ ] `/continue` - Continue a conversation that reached max iterations
- [x] `/help` - Show available commands
- [ ] Allow skills to register custom slash commands
- [ ] Different behavior in CLI vs channels

### 4. Conversation Management in Channels
- [ ] Per-channel conversation isolation
- [ ] Store conversation metadata separately from messages
- [ ] `/archive <label>` - archive old conversation

### 5. Conversation Labels
- [ ] Add `label` field to Conversation
- [ ] Labels are unique per user (not globally unique)
- [ ] Switch conversations: `/switch holiday-planning` instead of `/switch a1b2c3...`
- [ ] Auto-generate labels if not provided (e.g., "conversation-1", "conversation-2")

### 6. Skills Support
- [ ] Load skills from `~/skills/` directory
- [ ] Skills are Ruby classes/modules
- [ ] Examples: CodeReview, DataAnalysis, WebScraping, GitOperations
- [ ] Skills can register their own tools and system prompt extensions
- [ ] Allow skills to be enabled/disabled per conversation
- [ ] Skill configuration in YAML
- [ ] Skill dependencies (skills can require other skills)
- [ ] Skill versioning
- [ ] Skill composition (combine multiple skills)

### 7. Persistent Memory
- [ ] Vector database for semantic search (SQLite with sqlite-vss)
- [ ] Store important facts extracted from conversations
- [ ] Retrieve relevant memories at conversation start
- [ ] Allow user to explicitly save/forget memories
- [ ] Privacy: local-only storage, user-controlled
- [ ] Memory types: facts, preferences, learned patterns

### 8. Custom Tools Support
- [ ] Load tools from `~/tools/` directory
- [ ] Support Ruby files (inherit from RubyLLM::Tool)
- [ ] Support JSON schema definitions for simple tools
- [ ] Auto-discovery and registration on startup
- [ ] Hot-reload during development (optional)

## Additional Features

### Conversation Compaction
- [ ] Trigger automatically when token count exceeds threshold (configurable)
- [ ] Trigger manually via `/compact` slash command
- [ ] Use LLM to generate summary of conversation so far
- [ ] Replace old messages with summary + recent messages (keep last N messages intact)
- [ ] Preserve tool results and important context
- [ ] Store compaction history

### Continuation Handling
- [ ] Don't raise error on max iterations in interactive/channel modes
- [ ] Present summary to user: "I've been working for X iterations..."
- [ ] Options: Continue (reset counter), Summarize and stop, Cancel
- [ ] In channels, could auto-continue with warning message
- [ ] Track continuation count to prevent infinite loops

### Subagents
- [ ] Subagents are separate botiasloop instances with different configurations
- [ ] Specialized subagents: Researcher, Coder, Reviewer, etc.
- [ ] Main agent delegates tasks to subagents
- [ ] Subagents report back to main agent
- [ ] Subagent configuration via YAML or programmatic
- [ ] Resource limits per subagent (max iterations, allowed tools)

### Multi-User Support
- [ ] Each user has isolated configuration, tools, skills, conversations
- [ ] Shared system-wide defaults (optional)
- [ ] User-specific channels (e.g., each user has their own Telegram bot)
- [ ] No cross-user conversation access (privacy)

### Streaming Responses
- [ ] RubyLLM supports streaming
- [ ] Update CLI to show tokens as they arrive
- [ ] Channels need to handle partial message updates
- [ ] Configurable (enable/disable per channel)

### Configuration Validation
- [ ] Check required fields (API key)
- [ ] Validate URLs (searxng_url, channel webhooks)
- [ ] Test connections on startup (optional)
- [ ] Suggest fixes for common issues
- [ ] Configuration migration (auto-update old configs)

### Better Error Handling
- [ ] Graceful handling of API rate limits
- [ ] Retry with exponential backoff
- [ ] Clear error messages for common failures
- [ ] Suggest alternatives (e.g., different model if one fails)
- [ ] Error reporting in channels (don't crash the bot)

### Logging and Observability
- [ ] Structured logging (JSON)
- [ ] Log levels (debug, info, warn, error)
- [ ] Log to file and/or stdout
- [ ] Tool execution logging
- [ ] Performance metrics (token usage, latency, iteration counts)

### Testing Utilities
- [ ] Test doubles for Agent, Conversation, Tools
- [ ] Mock LLM responses
- [ ] Test fixtures for common scenarios
- [ ] RSpec matchers
- [ ] Channel testing helpers

### Optional Sandboxed Shell
- [ ] Docker container execution for shell commands
- [ ] Firejail or similar sandboxing tools
- [ ] Whitelist/blacklist commands
- [ ] Read-only mode option
- [ ] Confirmation for destructive operations (rm, dd, etc.)
- [ ] Per-channel sandbox settings

### Secrets Management
- [ ] Support for secret managers (1Password, Bitwarden, etc.)
- [ ] Keyring integration (Linux keyring, macOS Keychain)
- [ ] Never log API keys or secrets
- [ ] Rotate keys without restart
- [ ] Encrypted conversation storage (optional)

### Permission System
- [ ] User whitelist/blacklist per channel
- [ ] Rate limiting per user
- [ ] Tool permissions (e.g., only admins can use shell)
- [ ] Conversation privacy (private vs shared)
- [ ] Role-based access control (RBAC)

### Audit Logging
- [ ] Log all tool executions
- [ ] Log all conversations (if enabled)
- [ ] Log configuration changes
- [ ] Tamper-proof logging
- [ ] Export audit logs

### Multi-Modal Support
- [ ] Image analysis (vision models)
- [ ] Audio transcription (whisper)
- [ ] File attachments in conversations
- [ ] OCR for documents

### Plugin System
- [ ] Load plugins from gems (botiasloop-* naming convention)
- [ ] Hooks for: initialization, message processing, tool registration, channel setup
- [ ] Plugin configuration in YAML
- [ ] Plugin marketplace/discovery

### Web Dashboard
- [ ] Sinatra or Rails-based
- [ ] Real-time updates (WebSocket/SSE)
- [ ] Conversation browser and search
- [ ] Configuration UI
- [ ] Metrics dashboard
- [ ] User management (for multi-user setups)

### Cron Support
- [ ] Agent can create and manage its own cron jobs via shell access
- [ ] Document best practices for agent-managed cron
- [ ] Example skill demonstrating cron job creation
- [ ] No separate workflow engine needed (sharp knives philosophy)

### Identity and Operator Configuration
- [ ] Load IDENTITY.md from `~/IDENTITY.md`
- [ ] Load OPERATOR.md from `~/OPERATOR.md`
- [ ] IDENTITY.md defines agent personality, name, and behavior
- [ ] OPERATOR.md defines operator preferences and context
- [ ] Both files support Markdown formatting
- [ ] Dynamic reloading without restart

### Daemon / Background Running
- [ ] Systemd service support (Linux)
- [ ] launchd support (macOS)
- [ ] Background process with PID file
- [ ] Signal handling (SIGTERM, SIGHUP for reload)
- [ ] Graceful shutdown with conversation persistence
- [ ] Docker daemon mode support
- [ ] Log to file when running as daemon

## Implementation Principles

Throughout all development, we follow these principles:

1. **Sharp Knives**: Keep the philosophy of raw power and minimal restrictions
2. **Test-First**: All features built using TDD with comprehensive coverage
3. **Rails Doctrine**: Optimize for programmer happiness, convention over configuration
4. **Privacy First**: Local-first, user-controlled data
5. **Unix Philosophy**: Do one thing well, compose with other tools
6. **Progressive Enhancement**: Core works without optional features

## Contributing

When implementing features from this roadmap:
1. Start with a failing test
2. Implement the minimal code to pass
3. Refactor while keeping tests green
4. Ensure zero StandardRB offenses
5. Update documentation
6. Check off completed items in this roadmap
