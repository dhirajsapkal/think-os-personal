---
description: Show recent captures from the ledger — what was captured and where it landed
permalink: think-os/adapters/claude-code/commands/thinkos-recent
---

Show what has been captured in the last 24 hours (or N hours if the user passes `--hours N`).

## Step 1 — Run the script

```bash
bash scripts/thinkos-recent.sh [--hours N] [--source X] [--redact]
```

Pass any flags the user supplied in $ARGUMENTS directly. Default to `--hours 24` if none given.

If the script exits with "No captures yet", tell the user the ledger hasn't been written to yet — this is normal before any session-capture or external-ingest automation runs.

## Step 2 — Present the output

Display the grouped table from the script directly. Do not summarise or paraphrase it — the raw table is the legible output.

If the total is 0 but the ledger exists, note: "Automations may be paused or the last session predates the window. Run `/thinkos-doctor` to check capture health."

## Step 3 — Offer to inspect a specific source (interactive)

After the table, ask:

```
AskUserQuestion(
  question="Want to inspect any specific capture?",
  choices=["<source1>", "<source2>", ..., "No thanks"]
)
```

Build the choices list from the source groups that appeared in the output. Only offer sources that actually appeared. Always include "No thanks" as the last option.

**On pick:**
1. Re-run `bash scripts/thinkos-recent.sh --source <picked> --json` to get the events for that source.
2. From the JSON, extract the `output` path of the most recent non-null event.
3. Read the destination file via `mcp__basic-memory__read_note(identifier="<output path>")` or the filesystem if Basic Memory is unavailable.
4. Show the last 30 lines of that file with a label: "Latest output: `<path>`".

Do NOT read vault content unless the user explicitly picks a source in step 3. The ledger view alone is the default.

## Flags reference

| Flag | Effect |
|------|--------|
| `--hours N` | Show last N hours instead of 24 |
| `--source X` | Pre-filter to one source |
| `--redact` | Show structure without revealing any detail values — useful for confirming what *could* be captured without exposing content |
| `--json` | Machine output (for piping/scripting) |

## Example invocations

- `/thinkos-recent` — last 24h, all sources
- `/thinkos-recent --hours 48` — last two days
- `/thinkos-recent --source granola` — only Granola meeting captures
- `/thinkos-recent --redact` — confirm capture metadata without content

User message: $ARGUMENTS
