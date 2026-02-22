---
name: skill-creator
description: Create Agent Skills for the botiasloop project following the agentskills.io specification. Use when users want to create new skills, add capabilities to the agent system, or extend functionality with domain-specific instructions.
metadata:
  author: botiasloop
  version: "1.0"
---

# Skill Creator for botiasloop

## Overview

This skill guides you through creating Agent Skills for botiasloop. Skills are reusable instruction sets that help agents perform specialized tasks.

## Required Reading

Before creating any skill, you **MUST**:

1. **Read the full Agent Skills specification**: [references/SPECIFICATION.md](references/SPECIFICATION.md)
2. **Read official documentation** for whatever the skill is about (libraries, APIs, tools, etc.)
3. **Abort if official docs are unavailable** - never create a skill without proper documentation

## Skill Structure

```
skill-name/
├── SKILL.md                    # Required - main instructions
└── references/                 # Optional - additional docs
    └── domain-reference.md     # Official docs for the skill's domain
```

## Creating a Skill

### Step 1: Choose a Name

- Lowercase letters, numbers, and hyphens only
- Max 64 characters
- Must match directory name
- No leading/trailing hyphens, no consecutive hyphens
- Good: `rails-testing`, `api-client`, `docker-deploy`
- Bad: `RailsTesting`, `api--client`, `-docker`

### Step 2: Create Frontmatter

```yaml
---
name: your-skill-name
description: Clear description of what this skill does and when to use it. Include keywords that help identify relevant tasks.
metadata:
  author: botiasloop
  version: "1.0"
---
```

### Step 3: Write Compact Instructions

Keep SKILL.md under 500 lines. Structure for progressive disclosure:

1. **Quick Start** - 2-3 sentence summary
2. **Prerequisites** - Required tools/knowledge
3. **Step-by-Step Instructions** - Clear, actionable steps
4. **Examples** - Common patterns and edge cases
5. **References** - Links to detailed docs

### Step 4: Include References (Optional)

Include as needed:
- Domain-specific references (official docs)
- SPECIFICATION.md only in skill-creator skill itself

## botiasloop-Specific Guidelines

### Code Style

- Follow Ruby conventions from AGENTS.md
- 2 spaces, 100 char limit, frozen string literals
- Use StandardRB formatting
- Test-first development (TDD)

### Tool Integration

Skills that use tools must:
- Inherit from `RubyLLM::Tool`
- Use `description` and `param` macros
- Implement `execute(**args)` method
- Define `self.tool_name` for registry
- Reference: [AGENTS.md - Architecture Patterns](AGENTS.md)

### Testing Requirements

All skills should mention:
- Mock external dependencies in tests
- Test both success and error paths
- Maintain 90%+ coverage
- Use RSpec with descriptive contexts

### Content Constraints

- Be compact but complete
- No missing critical information
- No unnecessary verbosity
- Focus on botiasloop patterns
- Include error handling guidance

## Validation

After creating a skill:

1. Check frontmatter validity
2. Verify name matches directory
3. Ensure under 500 lines
4. Review against SPECIFICATION.md (located in skill-creator/references/)

## Example Skill Layout

```markdown
---
name: example-skill
description: Does X when Y is needed. Use for Z scenarios.
metadata:
  author: botiasloop
  version: "1.0"
---

# Example Skill

## Quick Start

Brief overview of what this skill enables.

## Prerequisites

- Required tool 1
- Required tool 2

## Instructions

1. First step
2. Second step
3. Third step

## Examples

### Basic usage

```ruby
code_example_here
```

### Edge case

How to handle common issues.

## References

- [Official docs](references/official-docs.md) - Include domain-specific documentation
```

## Critical Rules

1. **ALWAYS read official docs first** - Never create blind
2. **Keep it compact** - Under 500 lines, focused content
3. **Match botiasloop style** - Follow AGENTS.md conventions
4. **No speculation** - Only documented, verified information
5. **References are optional** - Include SPECIFICATION.md only in skill-creator itself
