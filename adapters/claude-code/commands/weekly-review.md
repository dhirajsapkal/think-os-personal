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

Execute every instruction in that file as if it were written here, **except where this wrapper overrides it** — notably the Current Focus write in Step 4 below (the wrapper's REPLACE-and-prune flow wins over any draft-file or append instruction in the cron prompt).

## Step 2 — Preflight checks

Before running the playbook:

1. Confirm recent Work Log entries exist — **never read the full Work Log** (~9.3k tokens). Use the scoped extraction: `bash <repo>/scripts/thinkos-recent.sh --worklog --days 7 --json` (resolve `<repo>` from `repo_path` in `~/.thinkos/install-manifest.json`, fallback `~/code/think-os`). Fallback: `mcp__basic-memory__search_notes` with `after_date=<today − 7d>`.
2. Read `01 Now/Current Focus.md` via `mcp__basic-memory__read_note` (small HOT file — whole read is correct; skip if already loaded this session) to check the `covers_week` field.
3. If the log has fewer than 3 entries for the past 7 days, warn the user before continuing — the digest will be thin.

## Step 3 — Execute the playbook

Follow the steps from `weekly-review.txt` in order. Do not skip steps. Surface all outputs inline.

## Step 4 — Refresh Current Focus: REPLACE-and-prune (confirm before writing)

Current Focus must contain **exactly one week** — never two concatenated week blocks. Append is forbidden here; the refresh is a replace. The mechanics, in order, after the user confirms the proposed content:

1. **Build the new week block** — covering next week (Mon–Sun), matching the existing file's structure.
2. **Archive the outgoing week** — append the outgoing week's block to the Work Log as a dated entry:

   ```
   mcp__basic-memory__edit_note(identifier="01 Now/Work Log", operation="append", content="\n## <today YYYY-MM-DD> — Current Focus archive (week of <outgoing covers_week>)\n<outgoing week's block verbatim>")
   ```

3. **Replace the live file** — `mcp__basic-memory__edit_note(identifier="Current Focus", operation="replace", content="<new week block>")` so the body holds only the incoming week. Update the `covers_week` frontmatter to the new Mon–Sun range as part of the same write.

If the current file already contains more than one week block (legacy append damage), prune now: archive every outgoing block to Work Log in step 2, keep only the new week in step 3.

Also propose any new Decisions or Learnings worth capturing.

**Do not write anything until the user confirms each item.** Show the diff or summary first.

## Notes

- This is a read-heavy, write-careful command. Default posture: propose, don't apply.
- If Basic Memory MCP is unavailable, fall back to direct reads under `$OS_HOME`.

User message: $ARGUMENTS
