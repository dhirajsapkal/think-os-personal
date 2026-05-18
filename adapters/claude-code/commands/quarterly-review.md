---
description: Quarterly OS maintenance — archive rotation, prune stale, audit HOT files
permalink: think-os/adapters/claude-code/commands/quarterly-review
---

Run the quarterly OS maintenance playbook. Rotates `Work Log.md` to archive, prunes stale projects, audits HOT-tier files, and proposes a clean state for the next quarter.

## Step 1 — Load the quarterly-archive prompt

Read the cron prompt as the authoritative playbook for this command:

```bash
cat scripts/cron-prompts/quarterly-archive.txt
```

Execute every instruction in that file as if it were written here. The file is the source of truth; this wrapper just ensures it is loaded.

## Step 2 — Preflight checks

Before running the playbook:

1. Confirm the current date so the archive filename is correct (e.g. `work-log-2026-Q1.md`).
2. Read `02 Projects/Project Index.md` via `mcp__basic-memory__read_note` to identify candidates for archival.
3. Read `01 Now/Current Focus.md` to check if it is past its `covers_week` field — flag if so.

## Step 3 — Execute the playbook

Follow the steps from `quarterly-archive.txt` in order. Do not skip steps. Surface all proposed changes inline as diffs or bullet lists.

## Step 4 — Staged confirmation

This command touches many files. Apply changes in stages, one section at a time, waiting for confirmation before each:

1. Archive rotation (`Work Log.md` → archive file)
2. Stale project pruning (propose moves to `99 Archive/`)
3. HOT-tier audit (flag files past their freshness window)
4. Current Focus refresh

**Never batch all writes into one unconfirmed operation.**

## Notes

- All writes use `mcp__basic-memory__edit_note` or `mcp__basic-memory__write_note`. Never `cat >` to vault files.
- If Basic Memory MCP is unavailable, list proposed changes but do not write — tell the user to run the writes manually.

User message: $ARGUMENTS
