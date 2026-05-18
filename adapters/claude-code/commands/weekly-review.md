---
description: Weekly OS digest — refresh Current Focus, surface drift, end-of-week review
permalink: think-os/adapters/claude-code/commands/weekly-review
---

Run the weekly OS review playbook. Reads the past 7 days of work-log entries, surfaces patterns, proposes a refreshed Current Focus, and flags any drift or stale notes.

## Step 1 — Load the weekly-review prompt

Read the cron prompt as the authoritative playbook for this command:

```bash
cat scripts/cron-prompts/weekly-review.txt
```

Execute every instruction in that file as if it were written here. The file is the source of truth; this wrapper just ensures it is loaded.

## Step 2 — Preflight checks

Before running the playbook:

1. Read `01 Now/Work Log.md` via `mcp__basic-memory__read_note` to confirm recent entries exist.
2. Read `01 Now/Current Focus.md` via `mcp__basic-memory__read_note` to check the `covers_week` field.
3. If the log has fewer than 3 entries for the past 7 days, warn the user before continuing — the digest will be thin.

## Step 3 — Execute the playbook

Follow the steps from `weekly-review.txt` in order. Do not skip steps. Surface all outputs inline.

## Step 4 — Propose updates (confirm before writing)

After the playbook runs:

- Propose an updated `Current Focus.md` with revised `covers_week`.
- Propose any new Decisions or Learnings worth capturing.
- **Do not write anything until the user confirms each item.** Show the diff or summary first.

## Notes

- This is a read-heavy, write-careful command. Default posture: propose, don't apply.
- If Basic Memory MCP is unavailable, fall back to direct reads under `$OS_HOME`.

User message: $ARGUMENTS
