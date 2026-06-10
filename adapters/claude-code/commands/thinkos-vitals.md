---
description: Snapshot of vault health — staleness, budgets, broken links, ledger volume
permalink: think-os/adapters/claude-code/commands/thinkos-vitals
---

Show a one-screen vault health snapshot: HOT/WARM file freshness, line budgets, unreviewed autocaptures, ledger volume, broken links, and section ages for append-only logs.

## Step 1 — Run the script

```bash
bash scripts/thinkos-vitals.sh
```

Pass any flags the user supplied in $ARGUMENTS directly (e.g. `--os-home <path>`). Do not pass `--json` here — the human-readable output is what you display.

Display the output verbatim. Do not summarise, paraphrase, or reformat it. The table is the legible output.

If the script errors (non-zero exit, no output), surface the error message and suggest running `bash scripts/thinkos-doctor.sh` to check setup state.

## Step 2 — Offer next actions

After displaying the output, present this chip-picker. Load via `ToolSearch select:AskUserQuestion` if needed.

```
AskUserQuestion(
  question="What would you like to do?",
  choices=[
    "Address oldest stale file",
    "Mark autocaptures reviewed",
    "Fix broken links",
    "Just close"
  ]
)
```

## Step 3 — Branch per choice

### "Address oldest stale file"

1. Identify the HOT file with the highest `last_reviewed_age_days` that has `status: stale` (not `stub` or `missing`). If all are stubs, tell the user and suggest running `/thinkos-continue` to seed the vault first.
2. Read the stale file via `mcp__basic-memory__read_note(identifier="<file path>")`.
3. Propose a session-recap update: summarise what you know from the current session that is relevant to this file and draft the additions.
4. Say: "Here is a draft update for `<file>`. Shall I save it?"
5. If the user confirms: call `mcp__basic-memory__edit_note` with `operation: find_replace` (or `append` for log-style files) to write the changes, and update the `last_reviewed:` frontmatter date to today's date.

### "Mark autocaptures reviewed"

1. Run `bash scripts/thinkos-vitals.sh --json | python3 -m json.tool` to get the count of unreviewed autocaptures. If it is 0, tell the user "No unreviewed autocaptures in the last 30 days." and exit.
2. Read `90 System/Capture Log.md` via `mcp__basic-memory__read_note`.
3. For each entry where `source` is not `manual` and `reviewed` is absent or false, surface the entry one at a time:
   - Show: timestamp, source, any `output` path.
   - Ask: "Mark as reviewed? (yes / skip / stop)"
   - On "yes": use `mcp__basic-memory__edit_note` with `operation: find_replace` to add `"reviewed": true` to that JSON line in the ledger.
   - On "stop": exit the loop.
4. After the loop, summarise how many were marked reviewed.

### "Fix broken links"

1. Run `bash scripts/thinkos-vitals.sh --json` and parse `broken_links`.
2. If empty, say "No broken links found." and exit.
3. For each broken link, present one at a time:
   - Show: `from`, `to`, `reason`.
   - Ask: "What would you like to do? [Remove the link] [Create the missing target] [Skip]"
   - **Remove**: use `mcp__basic-memory__edit_note` with `operation: find_replace` to delete or replace the wikilink/markdown link in the source file. Replace `[[Target]]` with the plain text of the link label; replace `[text](path)` with just `text`.
   - **Create**: use `mcp__basic-memory__write_note` to create a minimal stub at the target path with frontmatter `title`, `type: note`, and a single line "Stub created by /thinkos-vitals broken-link repair."
   - **Skip**: move to the next link.
4. After all links, summarise what was changed.

### "Just close"

Acknowledge with a single line: "Vault health snapshot complete. Run `/thinkos-vitals` any time." No further action.

## Flags reference

| Flag | Effect |
|---|---|
| `--os-home PATH` | Use a non-default vault path |
| `--json` | Emit raw JSON (for piping; not needed for normal use) |

## Example invocations

- `/thinkos-vitals` — full health snapshot, interactive
- `/thinkos-vitals --os-home /tmp/test-vault` — check a specific vault

User message: $ARGUMENTS
