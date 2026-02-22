---
name: skill-creator
description: Create new Agent Skills following the agentskills.io specification. Use when the user wants to create a skill for a specific task, domain, or API. This skill guides you through the complete skill creation process including directory structure, SKILL.md format, and API client creation when needed.
metadata:
  author: botiasloop
  version: "1.0"
---

# Skill Creator

## Purpose

You are a skill creator agent. Your job is to create well-structured, useful skills that help accomplish specific tasks. Skills live in `~/skills/<skill-name>/` directories and follow the agentskills.io specification.

## When to Use

Activate this skill when:
- User explicitly asks to create a skill
- User mentions "skill for X" or "create a skill"
- User wants help with a recurring task that needs instructions
- User needs integration with an API or service

## Critical Rules

1. **ALWAYS source from official documentation** - Never guess or hallucinate API details
2. **Follow the specification exactly** - Invalid skills won't work
3. **Keep SKILL.md compact** - Move details to `references/`
4. **Use templates when creating scripts** - Don't reinvent patterns

## Step-by-Step Process

### Step 1: Understand the Request

Ask clarifying questions:
- What specific task should this skill help with?
- Is this for an API integration? Which API?
- What are the common use cases?

### Step 2: Research API Documentation (If Applicable)

If the skill involves an API:

1. **Search for official documentation first**
   - Use web_search to find official API docs
   - Look for docs at: `https://api.service.com/docs`, `https://developer.service.com/`
   - Check for OpenAPI specs, README files, or official guides

2. **If official docs NOT found:**
   - STOP immediately
   - Tell the user: "I cannot find official documentation for [API name]. Creating a skill without proper documentation would result in incorrect or broken integration."
   - Ask: "Do you have access to official documentation, API reference, or a specification document I can use?"
   - Do NOT proceed without official docs

3. **If alternative (unofficial) docs found:**
   - Tell the user: "I found [alternative source] but could not locate official documentation."
   - Ask: "Should I proceed with this unofficial reference, or do you have official docs?"
   - Only proceed with user explicit permission

4. **Once you have docs, READ them thoroughly:**
   - Use Read tool on documentation files
   - Extract: authentication methods, endpoints, request/response formats, error codes
   - Note any code examples or SDK references

### Step 3: Create the Skill Directory

Create directory structure:
```
~/skills/<skill-name>/
├── SKILL.md          (required)
├── scripts/          (optional, for API clients)
├── references/       (optional, for detailed docs)
└── assets/           (optional, for templates/data)
```

**Naming the skill:**
- Max 64 characters
- Lowercase letters, numbers, hyphens only
- No leading/trailing hyphens
- No consecutive hyphens
- Must describe what it does: `github-api`, `pdf-processor`, `csv-analysis`

### Step 4: Write SKILL.md

**Frontmatter (REQUIRED):**
```yaml
---
name: skill-name
description: Clear description of what this skill does and when to use it. Include keywords that help identify relevant tasks.
metadata:
  author: user-name
  version: "1.0"
---
```

**Body Content:**

Structure for progressive disclosure:

1. **Quick Start** (2-3 sentences) - What this skill enables
2. **When to Use** - Specific scenarios and keywords
3. **Prerequisites** - Required tools, accounts, environment variables
4. **Main Instructions** - Step-by-step guidance for the agent
5. **Examples** - Common patterns, inputs/outputs
6. **Error Handling** - Common issues and solutions
7. **References** - Links to detailed docs in `references/`

**Content Guidelines:**
- Keep under 500 lines
- Be specific and actionable
- Include concrete examples
- Don't omit critical information
- Focus on what the agent should DO

### Step 5: Create API Client Script (If API Skill)

If the skill uses an API, create a CLI script in `scripts/`:

**Location:** `~/skills/<skill-name>/scripts/<api-name>.rb`

**Process:**
1. Copy the template from `assets/ruby_api_cli_template.rb`
2. Customize for the specific API using docs you researched
3. Implement key endpoints based on common use cases
4. Add error handling for API responses
5. Test logic mentally against docs

**Template location:** `data/skills/skill-creator/assets/ruby_api_cli_template.rb`

**Usage in skill instructions:**
```markdown
To call the API, use the CLI script:
`API_KEY=xxx ~/skills/<skill-name>/scripts/<api-name>.rb [options]`
```

### Step 6: Add References (Optional)

Move detailed documentation to `references/`:
- `references/api-reference.md` - Full API docs
- `references/examples.md` - More examples
- `references/troubleshooting.md` - Common issues

Reference them in SKILL.md:
```markdown
## References

- [API Reference](references/api-reference.md) - Full endpoint documentation
```

### Step 7: Validate the Skill

Checklist before finishing:
- [ ] Frontmatter has name and description
- [ ] Name matches directory name
- [ ] Name follows format rules (lowercase, hyphens, max 64 chars)
- [ ] Description explains what AND when to use
- [ ] Body is under 500 lines
- [ ] Includes clear step-by-step instructions
- [ ] API skills have working CLI script (if applicable)
- [ ] All file references use relative paths

### Step 8: Create the Skill

Use shell commands to:
1. Create directory structure
2. Write SKILL.md file
3. Create script files (if applicable)
4. Create reference files (if applicable)

**Example:**
```bash
mkdir -p ~/skills/my-api-skill/scripts
mkdir -p ~/skills/my-api-skill/references

# Write SKILL.md
cat > ~/skills/my-api-skill/SKILL.md << 'SKILL_EOF'
---
name: my-api-skill
description: Interact with MyAPI to fetch data and manage resources.
metadata:
  author: user
  version: "1.0"
---
# MyAPI Skill

## Quick Start

Use this skill to interact with MyAPI for fetching data and managing resources.

## When to Use

- User mentions "MyAPI" or "my api"
- Need to fetch data from MyAPI
- Managing resources on MyAPI

## Prerequisites

- API key in MYAPI_KEY environment variable

## Instructions

1. **Authentication**: Set MYAPI_KEY environment variable
2. **Make requests**: Use the CLI script at `scripts/myapi.rb`
3. **Handle errors**: Check exit codes and error messages

## Examples

### Fetch user data
```bash
MYAPI_KEY=xxx ~/skills/my-api-skill/scripts/myapi.rb --endpoint users --method GET
```

## References

- [API Reference](references/api-reference.md)
SKILL_EOF
```

## Working with API Documentation

### Finding Official Docs

**Search strategies:**
1. `service.com/api/docs`
2. `developer.service.com`
3. `docs.service.com/api`
4. GitHub repos: `service/api-docs`
5. API specifications (OpenAPI/Swagger)

**What to extract:**
- Base URL
- Authentication method (API key, OAuth, token)
- Key endpoints for common operations
- Request/response formats (JSON schema)
- Rate limits
- Error codes

### When Documentation is Incomplete

If official docs are missing key details:
1. Look for SDK source code on GitHub
2. Search for API examples in issues/PRs
3. Use web search for "service API example"
4. Ask user if they have internal docs

### Never Proceed Without Docs

**Critical:** If you cannot find sufficient documentation to implement the API client correctly, you MUST:
1. Stop and explain the situation
2. Request documentation from the user
3. Do not create a broken skill

## Error Handling in Skills

Skills should anticipate and handle:
- Missing environment variables
- Invalid inputs
- API errors (4xx, 5xx responses)
- Rate limiting
- Network failures

Document error handling in SKILL.md body.

## Examples

### Example 1: Simple Task Skill

**Request:** "Create a skill for optimizing PNG images"

**Process:**
1. No API research needed (uses local tools)
2. Name: `png-optimizer`
3. Directory: `~/skills/png-optimizer/`
4. SKILL.md includes: pngquant/oxipng usage, quality options, batch processing

### Example 2: API Integration Skill

**Request:** "Create a skill for the WeatherAPI"

**Process:**
1. Search for "weatherapi.com documentation"
2. Read docs at `https://www.weatherapi.com/docs/`
3. Extract: endpoints, API key auth, response format
4. Name: `weather-api`
5. Create CLI script using template
6. SKILL.md includes: authentication, common queries, response parsing

### Example 3: Rejected (No Docs)

**Request:** "Create a skill for SomeCorp's internal API"

**Response:**
"I cannot find official documentation for SomeCorp's API. Creating a skill without proper documentation would result in incorrect or potentially harmful integration. 

Do you have:
1. Official API documentation (docs site, PDF, README)?
2. API specification (OpenAPI/Swagger)?
3. Example code or SDK?

Please provide documentation and I'll create a complete skill for you."

## Template Usage

When creating API client scripts, always use the Ruby CLI template:

**Template path:** `data/skills/skill-creator/assets/ruby_api_cli_template.rb`

**To use:**
1. Read the template
2. Copy to `~/skills/<skill-name>/scripts/<api-name>.rb`
3. Customize based on API documentation
4. Ensure error handling matches API error responses

## Important Reminders

1. **Always verify with official docs** - Never trust memory or assumptions
2. **Be transparent about documentation gaps** - Tell user when you can't find docs
3. **Don't create broken skills** - Better to wait for docs than ship broken code
4. **Test mentally** - Walk through the skill instructions as if you were executing them
5. **Follow the spec** - Invalid skills won't be recognized by the system

## Success Criteria

A skill is complete when:
- Directory structure is correct
- SKILL.md has valid frontmatter and body
- Name matches directory and follows format rules
- Instructions are clear and actionable
- API clients are based on official documentation
- User has been informed if documentation was limited
