---
name: scheduling
description: Schedule tasks using system cron and at. Use when the user wants to schedule prompts to run automatically at specific times, either recurring (cron) or one-time (at).
metadata:
  author: botiasloop
  version: "1.0"
---

# Scheduling

## Purpose

Schedule prompts to run automatically using system scheduling tools:
- **Cron**: For recurring tasks (daily, weekly, etc.)
- **At**: For one-off tasks ("in 10 minutes", "tomorrow at 9am")

## When to Use

Activate this skill when:
- User asks to schedule something for later
- User wants automated recurring tasks
- User mentions "cron", "schedule", "remind me", "every day/week/hour"
- User mentions "in X minutes" or "tomorrow at X"

## Critical Rules

1. **Use current chat if not specified** - If the user doesn't explicitly provide a chat_id or say "all chats", use the current chat (the chat the user is messaging from).
2. **Choose the right tool** - Use `cron` for recurring tasks, use `at` for one-off tasks
3. **Use the exact format** - Follow the command formats exactly

## Part 1: Recurring Tasks (Cron)

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

## Part 2: One-Off Tasks (At)

Use `at` for tasks that run once at a specific time.

### Time Expressions

| When | At Syntax |
|------|-----------|
| In 10 minutes | `now + 10 minutes` |
| In 1 hour | `now + 1 hour` |
| In 30 minutes | `now + 30 minutes` |
| Tomorrow at 9am | `tomorrow 9am` or `09:00 tomorrow` |
| Tomorrow at 5pm | `17:00 tomorrow` |
| In 2 hours | `now + 2 hours` |
| At 3pm today | `15:00 today` |

### Creating One-Off Tasks

Use this format:
```bash
echo 'botiasloop agent send "<prompt>" --chat-id <chat_id>' | at <time>
```

### Example Interactions

**User: "Remind me in 10 minutes to look at the food in the stove"**

Response:
```
I'll set up a reminder for 10 minutes from now.

echo 'botiasloop agent send "look at the food in the stove" --chat-id <current_chat_id>' | at now + 10 minutes
```

**User: "Remind me in 1 hour to take my medication"**

Response:
```
I'll set up a reminder for 1 hour from now.

echo 'botiasloop agent send "take your medication" --chat-id <current_chat_id>' | at now + 1 hour
```

**User: "Remind me tomorrow at 9am about the meeting"**

Response:
```
I'll set up a reminder for tomorrow at 9am.

echo 'botiasloop agent send "you have a meeting" --chat-id <current_chat_id>' | at 09:00 tomorrow
```

### Managing At Jobs

List all pending at jobs:
```bash
atq
```

Remove a specific job (use the job number from atq):
```bash
atrm <job_number>
```

## Decision Tree

1. Does the user want it to happen **repeatedly** (every day, every week, etc.)?
   → Use **Cron**

2. Does the user want it to happen **once** (in 10 minutes, tomorrow at 9am, etc.)?
   → Use **At**

## Summary

| Use Case | Tool | Command Pattern |
|----------|------|-----------------|
| Recurring tasks | Cron | `<cron_expr> botiasloop agent send "<msg>" --chat-id <id>` |
| One-off tasks | At | `echo 'botiasloop agent send "<msg>" --chat-id <id>' \| at <time>` |
| All chats | Either | Replace `--chat-id <id>` with `--deliver-to-all-chats` |
