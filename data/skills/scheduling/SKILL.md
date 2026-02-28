---
name: scheduling
description: Schedule tasks using system cron and at. Use when the user wants to schedule prompts to run automatically at specific times, either recurring (cron) or one-time (at).
metadata:
  author: botiasloop
  version: "1.0"
---

# Scheduling

## Purpose

Schedule tasks to run automatically using system scheduling tools:
- **Cron**: For recurring tasks (daily, weekly, etc.)
- **At**: For one-off tasks ("in 10 minutes", "tomorrow at 9am")

## Critical Understanding

**You are scheduling YOURSELF to run later.**

The `botiasloop agent send` command is not a message to the user. It is a command that:
1. Runs the agent (you) later with a prompt
2. That prompt tells you what to DO when you wake up
3. Your response to that prompt gets delivered to the chat

**WRONG:** `botiasloop agent send "Take your medication!"`  
This sends the literal text "Take your medication!" to the user, which makes no sense.

**CORRECT:** `botiasloop agent send "remind the user to take their medication"`  
This wakes you up, you read the instruction, and you compose an appropriate reminder message.

## Critical Rules

1. **Use current chat if not specified** - If the user doesn't explicitly provide a chat_id or say "all chats", use the current chat (the chat the user is messaging from).
2. **Choose the right tool** - Use `cron` for recurring tasks, use `at` for one-off tasks
3. **The prompt is your instruction** - Write what you should DO, not what you should SAY

## Part 1: Recurring Tasks (Cron)

### Step 1: Gather Requirements

The user should provide:
1. What reminder/task should run?
2. When should it run? (time, frequency)

If the user doesn't specify which chat, use the current chat. If they want all chats, use `--deliver-to-all-chats`.

### Step 2: Create the Cron Job

Use `crontab -e` to edit the crontab. Add entries in this format:

```
<cron_expr> botiasloop agent send "<what you should do>" --chat-id <chat_id>
```

For delivering to all chats:
```
<cron_expr> botiasloop agent send "<what you should do>" --deliver-to-all-chats
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

Analysis:
- User wants: A reminder about checking server status
- When: Every day at 9am
- The prompt should tell ME what to do: "remind the user to check server status"

Response:
```
I'll set up a cron job to remind you to check server status every morning at 9am in this chat.

0 9 * * * botiasloop agent send "remind the user to check server status" --chat-id <current_chat_id>
```

**User: "Remind me every morning at 9am in all chats"**

Response:
```
I'll set up a cron job to remind you to check server status every morning at 9am and deliver to all chats.

0 9 * * * botiasloop agent send "remind the user to check server status" --deliver-to-all-chats
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
echo 'botiasloop agent send "<what you should do>" --chat-id <chat_id>' | at <time>
```

### Example Interactions

**User: "Remind me in 10 minutes to look at the food in the stove"**

Analysis:
- User wants: A reminder to check the stove
- When: In 10 minutes
- The prompt should tell ME what to do: "remind the user to look at the food in the stove"

Response:
```
I'll set up a reminder for 10 minutes from now.

echo 'botiasloop agent send "remind the user to look at the food in the stove" --chat-id <current_chat_id>' | at now + 10 minutes
```

**User: "Remind me in 1 hour to take my medication"**

Analysis:
- The prompt should be: "remind the user to take their medication" (not "take your medication!")

Response:
```
I'll set up a reminder for 1 hour from now.

echo 'botiasloop agent send "remind the user to take their medication" --chat-id <current_chat_id>' | at now + 1 hour
```

**User: "Remind me tomorrow at 9am about the meeting"**

Analysis:
- The prompt should be: "remind the user about their meeting" (not "you have a meeting!")

Response:
```
I'll set up a reminder for tomorrow at 9am.

echo 'botiasloop agent send "remind the user about their meeting" --chat-id <current_chat_id>' | at 09:00 tomorrow
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

## Common Mistakes to Avoid

❌ **WRONG:** `botiasloop agent send "Take your medication!"`  
✅ **CORRECT:** `botiasloop agent send "remind the user to take their medication"`

❌ **WRONG:** `botiasloop agent send "Check the stove!"`  
✅ **CORRECT:** `botiasloop agent send "remind the user to check the stove"`

❌ **WRONG:** `botiasloop agent send "Server status report"`  
✅ **CORRECT:** `botiasloop agent send "check server status and report findings to the user"`

## Summary

| Use Case | Tool | Command Pattern |
|----------|------|-----------------|
| Recurring tasks | Cron | `<cron_expr> botiasloop agent send "remind the user to <action>" --chat-id <id>` |
| One-off tasks | At | `echo 'botiasloop agent send "remind the user to <action>" --chat-id <id>' \| at <time>` |
| All chats | Either | Replace `--chat-id <id>` with `--deliver-to-all-chats` |

**Remember: The prompt is YOUR instruction, not the message to the user!**
