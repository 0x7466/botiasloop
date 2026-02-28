---
name: cron
description: Schedule recurring tasks using system crontab. Use when the user wants to schedule prompts to run automatically at specific times.
metadata:
  author: botiasloop
  version: "1.0"
---

# Cron Scheduling

## Purpose

Schedule prompts to run automatically at specific times using system crontab.

## When to Use

Activate this skill when:
- User asks to schedule something (e.g., "remind me every morning")
- User wants automated recurring tasks
- User mentions "cron", "schedule", "remind me", "every day/week/hour"

## Critical Rules

1. **Use current chat if not specified** - If the user doesn't explicitly provide a chat_id or say "all chats", use the current chat (the chat the user is messaging from).
2. **Use the exact format** - Follow the crontab entry format exactly

## Step-by-Step Process

### Step 1: Gather Requirements

The user should provide:
1. What prompt/message should run?
2. When should it run? (time, frequency)

If the user doesn't specify which chat, use the current chat. If they want all chats, use `--deliver-to-all-chats`.

### Step 2: Create the Cron Job

Use `crontab -e` to edit the crontab. Add entries in this format:

```
<cron_expr> botiasloop agent send "<prompt>" --chat-id <chat_id>
```

For delivering to all chats:
```
<cron_expr> botiasloop agent send "<prompt>" --deliver-to-all-chats
```

### Step 3: Common Scheduling Patterns

| Frequency | Cron Expression |
|-----------|-----------------|
| Every minute | `* * * * *` |
| Every 5 minutes | `*/5 * * * *` |
| Every hour | `0 * * * *` |
| Every day at 9am | `0 9 * * *` |
| Every day at 5pm | `0 17 * * *` |
| Every weekday at 9am | `0 9 * * 1-5` |
| Every Monday at 9am | `0 9 * * 1` |
| First day of month at 9am | `0 9 1 * *` |

### Step 4: Example Interactions

**User: "Remind me to check server status every morning at 9am"**

Response:
```
I'll set up a cron job to check server status every morning at 9am in this chat.

0 9 * * * botiasloop agent send "check server status" --chat-id <current_chat_id>
```

**User: "Remind me every morning at 9am in all chats"**

Response:
```
I'll set up a cron job to check server status every morning at 9am and deliver to all chats.

0 9 * * * botiasloop agent send "check server status" --deliver-to-all-chats
```

### Step 5: Removing Cron Jobs

To remove a cron job:
1. Use `crontab -e` to edit the crontab
2. Delete the line with the job you want to remove
