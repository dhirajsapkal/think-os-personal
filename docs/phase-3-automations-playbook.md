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

After Phase 1 (install) and Phase 2 (context seeding), your Think OS has identity, projects, focus, and people — but markdown files go stale if no one maintains them. Phase 3 sets up **scheduled jobs** that run automatically on a cron schedule:

- **Daily reindex** so external edits (Obsidian, your editor) flow into Basic Memory.
- **Weekly review** so `Current Focus.md` rolls over to next week without you remembering.
- **Quarterly archive** so `Work Log.md` doesn't grow unbounded.

These aren't notifications — they're maintenance. Your vault gets healthier over time on its own.

---

## How Phase 3 scheduling works

Phase 3 triggers run as **local launchd jobs** — the same mechanism Phase A session capture uses. Each job is a `templates/LaunchAgents/com.thinkos.<name>.plist` that invokes a single generic dispatcher: `scripts/thinkos-cron-run.sh <name>`. The dispatcher knows whether the task is deterministic (e.g., `basic-memory reindex` for daily-reindex) or LLM-prompted (reads `scripts/cron-prompts/<name>.txt` and runs `claude -p` against it).

Key properties:

- **They run locally**, on your Mac, via launchd. Installation writes a `.plist` and loads it with `launchctl`.
- **They fire on cron schedules** — same expressions as Linux cron (`0 7 * * 1-5` = 7am weekdays).
- **Jobs that need LLM synthesis** spawn a local `claude -p` session with your vault's MCP tools available.
- **They write to your local vault** — which is why they must be local. Remote triggers run on Anthropic's cloud infrastructure and cannot write to `~/ThinkOS/vault/` on your machine.

**Laptop-wake caveat:** launchd jobs only fire when your Mac is awake. If your Mac sleeps through a scheduled time (e.g., 4am reindex), launchd catches up on next wake — or skips that fire, depending on the job's `StartCalendarInterval` settings. The original "your laptop can be asleep" framing was wrong for these jobs; that only holds for remote triggers that write to cloud-accessible storage (project vaults, Slack notifications). Phase 3 jobs write to your personal hub vault, which is local.

Each LLM-synthesis fire uses Anthropic API tokens. For low-frequency maintenance tasks, token usage is low — a daily reindex takes no tokens (it is a deterministic script call); the weekly review and quarterly archive each spawn one Claude session.

---

## The recommended automation set

When the user runs `/thinkos-automate`, the agent offers these by default. Each is opt-in (Y/N).

### 1. Daily reindex — `0 4 * * *` (every day at 4am)

**Why**: Basic Memory's index drifts if you edit vault files outside an agent session (Obsidian, your text editor). The reindex keeps search results accurate.

**What runs**: A shell script that runs:
```bash
basic-memory reindex --project think-os
```
No LLM call. No API tokens. Pure deterministic command.

**Cost**: zero API tokens. The script runs directly; no Claude session is spawned.

### 2. Weekly review — `0 20 * * 0` (Sunday 8pm)

**Why**: `Current Focus.md` should reflect THIS week. Stale focus is the highest-cost failure mode in a file-based agent OS — the agent makes confident wrong answers from old data.

**What runs**: A Claude session that:
1. Reads the past 7 days of `01 Now/Work Log.md` entries via Basic Memory.
2. Surfaces patterns (which projects took most time, what got blocked, what's emerging).
3. Drafts an updated `01 Now/Current Focus.md` covering next week.
4. Writes the draft to `01 Now/Current Focus.md.draft` (NOT the live file) for the user to review and approve on Monday morning.

**Cost**: spawns one local `claude -p` session that reads ~7 days of vault content and drafts an updated focus file. Uses Anthropic API tokens. Whether that's covered by your Claude plan or charged as pay-as-you-go depends on your account.

### 3. Quarterly archive — `0 21 1-7 1,4,7,10 0` (first Sunday of Jan/Apr/Jul/Oct, 9pm)

**Why**: `Work Log.md` grows unbounded. After a quarter (~90 entries), it's huge. Archive what's old, keep what's recent.

**What runs**: A Claude session that:
1. Reads `01 Now/Work Log.md`.
2. Moves entries older than 90 days to `99 Archive/work-log-YYYY-QN.md`.
3. Audits HOT-tier files for line bloat (anything over its target line count gets flagged).
4. Prunes stale entries from `02 Projects/Project Index.md` (projects with no activity in 6+ months get marked dormant).
5. Writes a quarterly summary to `99 Archive/quarterly-summary-YYYY-QN.md`.

**Cost**: fires 4 times a year. Spawns one local `claude -p` session per fire. Token usage scales with vault size.

### 4. Daily morning brief — `0 7 * * 1-5` (7am Mon-Fri) — *optional*

**Why**: Some users want a written brief in their inbox or vault each morning. Others find it noisy.

**What runs**: A Claude session that:
1. Reads Identity, Current Focus, Tasks, and last 24h of Work Log entries.
2. Reads Calendar events for today (via MCP if `Granola` / `Google Calendar` MCPs are installed).
3. Writes a brief markdown summary to `01 Now/briefs/YYYY-MM-DD-brief.md`.

**Cost**: spawns one local `claude -p` session per fire. Reads HOT-tier files + today's calendar events (if MCP connected). Whether you're billed depends on your Claude plan.

**Skip if**: You already use `/thinkos-morning` interactively each day. Then there's no benefit to scheduling.

---

## The `/thinkos-automate` flow

When the user invokes `/thinkos-automate`, do this:

### Step 0 — Check state

Confirm Phase 2 is complete by reading `~/.thinkos/wizard-state.json`. If `phase != complete`, tell the user: "Phase 2 (context seeding) hasn't finished yet. Run `/thinkos-continue` first — that ensures your Current Focus and other HOT files actually have content for the scheduled jobs to update."

If the user wants to proceed anyway, that's fine. The triggers can be created against an empty vault; they just won't have much to do.

### Step 1 — Explain what this is

Show the user a brief framing:

> Phase 3 installs local launchd jobs that keep your Think OS fresh automatically. Jobs run on your Mac — they fire when your Mac is awake (if the Mac sleeps through a scheduled time, the job catches up on next wake or skips that fire). LLM-synthesis jobs (weekly review, quarterly archive, morning brief) use Anthropic API tokens when they run; the daily reindex does not. I'll offer you four pre-built automations; you choose which to install.

### Step 2 — Offer each automation (one at a time)

For each of the four (reindex, weekly-review, quarterly-archive, morning-brief), ask:

> Want me to set up <name>? It runs on schedule `<cron>` (translated to English: e.g., "every Sunday at 8pm"). Cost: <estimate>. [Y/n]

Wait for each answer before moving to the next.

### Step 3 — Install the launchd jobs

For each Y answer, install via:

```bash
bash scripts/install-launchd-job.sh <name>
```

This writes `templates/LaunchAgents/com.thinkos.<name>.plist` to `~/Library/LaunchAgents/`, runs `launchctl load` on it, and wires the plist to invoke `scripts/thinkos-cron-run.sh <name>` at fire time. LLM-prompted tasks read their prompt from `scripts/cron-prompts/<name>.txt`; daily-reindex is a special case (deterministic, hardcoded in the dispatcher).

The job configs for each trigger are:

#### Daily reindex
```
name: thinkos-daily-reindex
schedule: "0 4 * * *"   # 4am daily
dispatcher: scripts/thinkos-cron-run.sh daily-reindex
# Deterministic command, hardcoded in the dispatcher:
#   basic-memory reindex --project think-os
# No claude -p call.
```

#### Weekly review
```
name: thinkos-weekly-review
schedule: "0 20 * * 0"   # Sunday 8pm
dispatcher: scripts/thinkos-cron-run.sh weekly-review
prompt_file: scripts/cron-prompts/weekly-review.txt
# Dispatcher reads the prompt file and runs `claude -p` against it.
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
name: thinkos-quarterly-archive
schedule: "0 21 1-7 1,4,7,10 0"   # first Sunday of Jan/Apr/Jul/Oct, 9pm
dispatcher: scripts/thinkos-cron-run.sh quarterly-archive
prompt_file: scripts/cron-prompts/quarterly-archive.txt
# Dispatcher reads the prompt file and runs `claude -p` against it.
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
name: thinkos-morning-brief
schedule: "0 7 * * 1-5"   # 7am Mon-Fri
dispatcher: scripts/thinkos-cron-run.sh morning-brief
prompt_file: scripts/cron-prompts/morning-brief.txt
# Dispatcher reads the prompt file and runs `claude -p` against it.
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

### Step 4 — Show the user what was installed

After installing each job, list them back:

> Installed 3 local launchd jobs:
>   1. Daily reindex — fires at 4am every day (no API tokens)
>   2. Weekly review — fires Sunday 8pm (one Claude session per fire)
>   3. Quarterly archive — fires first Sunday of Jan/Apr/Jul/Oct, 9pm (one Claude session per fire)
>
> They run when your Mac is awake. If your Mac sleeps through a scheduled time, the job catches up on next wake (or skips that fire). To list or remove jobs later, run `/thinkos-automate list` or `/thinkos-automate remove <name>`.

### Step 5 — Common follow-up questions to expect

**"Do I need to keep Claude Code open for these to run?"**
Claude Code doesn't need to be open, but your Mac does need to be awake. These are local launchd jobs, not remote cloud triggers. If your Mac is asleep at the scheduled time, the job fires on next wake (or is skipped, depending on the job type).

**"What if a job fails?"**
launchd will retry on the next scheduled interval. If it fails repeatedly, you'll see warnings in `/thinkos-doctor` output.

**"How much will this cost?"**
The daily reindex costs zero API tokens — it is a direct script call. The weekly review, quarterly archive, and morning brief each spawn a local `claude -p` session; token usage depends on vault size. Whether that usage counts against your Claude plan or pay-as-you-go depends on your account.

**"Can I add my own?"**
For jobs that write to your personal vault: add a new prompt file at `scripts/cron-prompts/<name>.txt`, add a case branch to `run_task()` in `scripts/thinkos-cron-run.sh`, register the schedule in `scripts/install-launchd-job.sh`, then install via `bash scripts/install-launchd-job.sh <name>`. For jobs that don't write to your local vault (Slack notifications, project vault pushes): use the `schedule` skill or `RemoteTrigger` for remote triggers instead.

---

## Listing / managing existing jobs

When the user runs `/thinkos-automate list`, check `~/Library/LaunchAgents/` for `com.thinkos.*.plist` files and run `launchctl list | grep thinkos` to show load status. Show:
- Name / description
- Cron schedule (translated to English)
- Loaded/unloaded status

When the user runs `/thinkos-automate remove <name>`, run `launchctl unload ~/Library/LaunchAgents/com.thinkos.<name>.plist` and delete the plist, after confirmation.

---

## Scope notes

- **Briefs go to vault files, not Slack/email.** If you want Slack delivery, write a separate remote trigger (via the `schedule` skill) that reads the brief file and sends it (requires Slack OAuth via your plugin bundle). That use case — sending a notification, no vault write — is appropriate for a remote trigger.
- **Jobs run locally.** They fire when your Mac is awake. Laptops that sleep through midnight will miss the 4am reindex; it catches up on the next boot/wake.
- **Remote triggers are still available** via the `schedule` skill for use cases that fit: writing to project vaults (git-backed, push-accessible remotely), sending Slack/email notifications, or anything that does not need to write to your local personal hub.
- **Stale-data alerting** is manual via `/thinkos-stale`.

---

## What comes next — continuous capture

Phase 3 automations handle scheduled maintenance. For ongoing passive logging of what you actually work on, see continuous capture:

- **Session capture** (Layer A, live) — `/thinkos-autosave on` starts a launchd job that appends a one-line stub to Work Log every 2 hours. No LLM call.
- **External ingestion** (Layer B, opt-in per source) — Granola, Slack, Gmail, Calendar, Linear, ClickUp. Configure via `/thinkos-capture-setup`.
- **Audit ledger** (Layer C) — every capture is recorded in `~/.thinkos/capture-log.jsonl`. Review with `/thinkos-recent`; undo with `/thinkos-undo-capture`.

Design: `docs/continuous-capture/README.md`.
