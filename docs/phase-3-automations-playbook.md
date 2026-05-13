---
type: agent-playbook
audience: ai-agent
tags:
- automations
- scheduled-tasks
- phase-3
- triggers
- cron
permalink: think-os/phase-3-automations-playbook
---

# Phase 3 — Automations & Scheduled Tasks

How Think OS stays fresh without you remembering to maintain it.

This is the canonical playbook for the `/thinkos-automate` slash command. When a user runs `/thinkos-automate`, the agent reads this file and follows it to set up scheduled triggers in Claude Code.

---

## What this is

After Phase 1 (install) and Phase 2 (context seeding), your Think OS has identity, projects, focus, and people — but markdown files go stale if no one maintains them. Phase 3 sets up **scheduled triggers** that run automatically on a cron schedule:

- **Daily reindex** so external edits (Obsidian, your editor) flow into Basic Memory.
- **Weekly review** so `Current Focus.md` rolls over to next week without you remembering.
- **Quarterly archive** so `Work Log.md` doesn't grow unbounded.

These aren't notifications — they're maintenance. Your vault gets healthier over time on its own.

---

## How Claude Code scheduling works

Claude Code supports **remote scheduled triggers** through the `schedule` skill and the `CronCreate` / `CronList` / `CronDelete` tools. Key properties:

- **They run remotely**, not in your local Claude Code session. You don't need to keep an app open or a terminal running.
- **They fire on cron expressions** — same syntax as Linux cron (`0 7 * * 1-5` = 7am weekdays).
- **They run a small Claude session** with whatever prompt you defined, with access to your MCPs and tools.
- **They write to your filesystem and vault** the same way an in-session agent would.

Each fire uses Anthropic API tokens. For low-frequency maintenance tasks, token usage is low — a daily 4am reindex takes ~500-2000 tokens.

---

## The recommended automation set

When the user runs `/thinkos-automate`, the agent offers these by default. Each is opt-in (Y/N).

### 1. Daily reindex — `0 4 * * *` (every day at 4am)

**Why**: Basic Memory's index drifts if you edit vault files outside an agent session (Obsidian, your text editor). The reindex keeps search results accurate.

**What runs**: A tiny Claude session that calls `Bash` once to run:
```bash
basic-memory reindex --project think-os
```

**Cost**: each fire spawns a tiny Claude session (one Bash call). Token usage is minimal. Whether you're billed depends on your Claude plan.

### 2. Weekly review — `0 20 * * 0` (Sunday 8pm)

**Why**: `Current Focus.md` should reflect THIS week. Stale focus is the highest-cost failure mode in a file-based agent OS — the agent makes confident wrong answers from old data.

**What runs**: A Claude session that:
1. Reads the past 7 days of `01 Now/Work Log.md` entries via Basic Memory.
2. Surfaces patterns (which projects took most time, what got blocked, what's emerging).
3. Drafts an updated `01 Now/Current Focus.md` covering next week.
4. Writes the draft to `01 Now/Current Focus.md.draft` (NOT the live file) for the user to review and approve on Monday morning.

**Cost**: reads ~7 days of vault content and drafts an updated focus file. Whether you're billed depends on your Claude plan.

### 3. Quarterly archive — `0 21 1-7 1,4,7,10 0` (first Sunday of Jan/Apr/Jul/Oct, 9pm)

**Why**: `Work Log.md` grows unbounded. After a quarter (~90 entries), it's huge. Archive what's old, keep what's recent.

**What runs**: A Claude session that:
1. Reads `01 Now/Work Log.md`.
2. Moves entries older than 90 days to `99 Archive/work-log-YYYY-QN.md`.
3. Audits HOT-tier files for line bloat (anything over its target line count gets flagged).
4. Prunes stale entries from `02 Projects/Project Index.md` (projects with no activity in 6+ months get marked dormant).
5. Writes a quarterly summary to `99 Archive/quarterly-summary-YYYY-QN.md`.

**Cost**: fires 4 times a year. Token usage scales with vault size.

### 4. Daily morning brief — `0 7 * * 1-5` (7am Mon-Fri) — *optional*

**Why**: Some users want a written brief in their inbox or vault each morning. Others find it noisy.

**What runs**: A Claude session that:
1. Reads Identity, Current Focus, Tasks, and last 24h of Work Log entries.
2. Reads Calendar events for today (via MCP if `Granola` / `Google Calendar` MCPs are installed).
3. Writes a brief markdown summary to `01 Now/briefs/YYYY-MM-DD-brief.md`.

**Cost**: reads HOT-tier files + today's calendar events (if MCP connected). Whether you're billed depends on your Claude plan.

**Skip if**: You already use `/thinkos-morning` interactively each day. Then there's no benefit to scheduling.

---

## The `/thinkos-automate` flow

When the user invokes `/thinkos-automate`, do this:

### Step 0 — Check state

Confirm Phase 2 is complete by reading `~/.thinkos/wizard-state.json`. If `phase != complete`, tell the user: "Phase 2 (context seeding) hasn't finished yet. Run `/thinkos-continue` first — that ensures your Current Focus and other HOT files actually have content for the scheduled jobs to update."

If the user wants to proceed anyway, that's fine. The triggers can be created against an empty vault; they just won't have much to do.

### Step 1 — Explain what this is

Show the user a brief framing:

> Phase 3 sets up scheduled triggers that keep your Think OS fresh automatically. Triggers run remotely (no app needs to stay open) and use a small amount of Anthropic API tokens per fire. I'll offer you four pre-built automations; you choose which to enable.

### Step 2 — Offer each automation (one at a time)

For each of the four (reindex, weekly-review, quarterly-archive, morning-brief), ask:

> Want me to set up <name>? It runs on schedule `<cron>` (translated to English: e.g., "every Sunday at 8pm"). Cost: <estimate>. [Y/n]

Wait for each answer before moving to the next.

### Step 3 — Create the triggers

For each Y answer, use the `schedule` skill (or `CronCreate` tool — load via `ToolSearch select:CronCreate` if needed). The trigger config for each is:

#### Daily reindex
```
schedule: "0 4 * * *"
prompt: |
  Run `basic-memory reindex --project think-os` via the Bash tool.
  Output any errors as a single line. If successful, exit silently.
```

#### Weekly review
```
schedule: "0 20 * * 0"
prompt: |
  Read the past 7 days of entries from 01 Now/Work Log.md via
  mcp__basic-memory__search_notes (filter by recent dates).

  Identify patterns: which projects consumed most time, what got
  blocked, what's emerging.

  Read the current 01 Now/Current Focus.md to understand prior
  framing.

  Draft an updated Current Focus.md covering next week (Mon-Sun).
  Match the existing file's structure.

  Write the draft to 01 Now/Current Focus.md.draft (NOT to the live
  file) via mcp__basic-memory__write_note. The user reviews and
  approves on Monday.

  Append a brief one-paragraph summary of this session to
  01 Now/Work Log.md noting the review ran.
```

#### Quarterly archive
```
schedule: "0 21 1-7 1,4,7,10 0"
prompt: |
  Read 01 Now/Work Log.md fully.

  Move entries with dates older than 90 days from today to
  99 Archive/work-log-<YYYY>-Q<N>.md (create the archive file
  if it doesn't exist).

  Read 02 Projects/Project Index.md. For each project with no
  activity in 180+ days (check the project's last-touched stamp),
  flag it as candidate for archive.

  Audit HOT-tier files for line counts:
    - 05 Profile/Identity.md > 100 lines: flag
    - 01 Now/Current Focus.md > 100 lines: flag
    - 02 Projects/Project Index.md > 200 lines: flag
    - 90 System/OS Instructions.md > 150 lines: flag

  Write a quarterly summary to 99 Archive/quarterly-summary-<YYYY>-Q<N>.md
  with: what was archived, what was flagged for pruning, what looks
  healthy. The user reviews and acts on the flags manually.
```

#### Daily morning brief (only if user said yes)
```
schedule: "0 7 * * 1-5"
prompt: |
  Read these via mcp__basic-memory__read_note or search_notes:
    - 05 Profile/Identity.md (briefly)
    - 01 Now/Current Focus.md
    - 01 Now/Tasks.md
    - 01 Now/Work Log.md (last 24h of entries only)

  If the Google Calendar MCP is registered and connected, also pull
  today's events via mcp__claude_ai_Google_Calendar__list_events.

  Synthesize a single-page morning brief in markdown:
    - "Good morning. Today is <date>."
    - Top 3 priorities for the day (from Current Focus + Tasks)
    - Calendar events for the day (if any)
    - "Yesterday you logged..." (1-2 line summary)
    - Any open threads or blockers worth re-surfacing

  Write to 01 Now/briefs/<YYYY-MM-DD>-brief.md via
  mcp__basic-memory__write_note.

  Keep it under 30 lines. Lead with the answer to "what should I
  start on?" — no preamble.
```

### Step 4 — Show the user what was created

After creating each trigger, list them back:

> Created 3 scheduled triggers:
>   1. Daily reindex — fires at 4am every day
>   2. Weekly review — fires Sunday 8pm
>   3. Quarterly archive — fires first Sunday of Jan/Apr/Jul/Oct, 9pm
>
> You don't need to do anything — they run on their own. To list, edit, or remove them later, run `/thinkos-automate list` or `/thinkos-automate remove <name>`.

### Step 5 — Common follow-up questions to expect

**"Do I need to keep Claude Code open for these to run?"**
No. Triggers run on Anthropic's infrastructure. Your laptop can be asleep.

**"What if a trigger fails?"**
The next run will retry. If it fails repeatedly, you'll see warnings in `/thinkos-doctor` output.

**"How much will this cost?"**
Token usage depends on vault size and how much each trigger reads/writes. Whether that usage counts against your Claude plan or pay-as-you-go depends on your account.

**"Can I add my own?"**
Yes — use the `schedule` skill directly or `CronCreate` tool. Anything you can prompt an agent to do, you can schedule. Common candidates:
- "Every Monday 9am, draft a Slack message summarizing the past week to my team."
- "Every Friday 5pm, draft an end-of-week update for me."
- "Every hour during work hours, check Linear for new tickets assigned to me and append to Tasks.md."

---

## Listing / managing existing triggers

When the user runs `/thinkos-automate list`, use `CronList` to enumerate active triggers. Show:
- Name / description
- Cron schedule (translated to English)
- Last fire time
- Last status (success/fail)

When the user runs `/thinkos-automate remove <name>`, use `CronDelete` after confirmation.

---

## Scope notes

- **Briefs go to vault files, not Slack/email.** If you want Slack delivery, write a follow-up agent prompt that reads the brief file and sends it (requires Slack OAuth via your plugin bundle).
- **Triggers run remotely.** There is no machine-local cron option.
- **Stale-data alerting** is manual via `/thinkos-stale`.
