---
description: Undo a recent capture — remove it from the vault and record the reversal
permalink: think-os/adapters/claude-code/commands/thinkos-undo-capture
---

Remove captured content from the vault. This is the trust escape hatch: if something was captured that shouldn't have been, this command removes it cleanly and records the reversal in the ledger.

**Safe by default.** Every step shows a diff and asks before mutating anything.

## Step 1 — Fetch recent captures

```bash
bash scripts/thinkos-recent.sh --hours 48 --json
```

Parse the JSON. Extract the `events` array. Filter to events where:
- `mode` is not `noop`, `skipped`, or `undone`
- `output` is not null

Sort by `ts` descending, take the most recent 10 (or all if fewer than 10).

If no actionable events exist, tell the user: "No captures to undo in the last 48 hours."

## Step 2 — Ask which capture to undo

Present a picker. Load via `ToolSearch select:AskUserQuestion` if needed.

```
AskUserQuestion(
  question="Which capture do you want to undo?",
  choices=[
    "<ts> — <source> — <output path>",
    ...for each event...,
    "Cancel"
  ]
)
```

Format each choice as: `HH:MM source: <source> → <output>` using the local time from `ts`.

If the user picks "Cancel", stop immediately. Do not touch anything.

## Step 3 — Show the captured content before removing

1. Read the destination file:
   ```
   mcp__basic-memory__read_note(identifier="<output path>")
   ```
   If Basic Memory is unavailable, fall back to reading the vault file directly via the filesystem.

2. Identify the block written by this capture. The session-capture script uses timestamped section headers (e.g., `## YYYY-MM-DD HH:MM`). For external sources, look for a block dated to within 5 minutes of the capture `ts`.

3. Show the user the identified block as a quoted diff:
   ```
   The following block would be removed from <output path>:

   --- before
   <the captured block>
   ---
   ```

4. Ask for confirmation:
   ```
   AskUserQuestion(
     question="Remove this block from <output path>?",
     choices=["Yes, remove it", "No, keep it"]
   )
   ```

If the user chooses "No, keep it", stop. Do not touch anything.

## Step 4 — Remove the block

1. Edit the destination file to remove the identified block using `mcp__basic-memory__edit_note`:
   ```
   mcp__basic-memory__edit_note(
     identifier="<output path>",
     operation="find_replace",
     find="<exact block text>",
     replace=""
   )
   ```

2. If the edit fails (e.g., content has been edited since the capture), tell the user: "The file content no longer matches the captured block — it may have been edited manually. You'll need to remove it by hand." Do not force any edit.

## Step 5 — Record the reversal in the ledger

Append a new ledger event recording the undo. Write to the vault note `90 System/Capture Log.md` via `mcp__basic-memory__edit_note`:

```
mcp__basic-memory__edit_note(
  identifier="Capture Log",
  operation="append",
  content='{"ts":"<now ISO8601 UTC>","source":"<original source>","detail":{"undone_ts":"<original ts>","undone_output":"<original output>"},"output":null,"mode":"undone","bytes":0}\n'
)
```

If you have shell access, equivalent via direct file append:

```bash
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
python3 - <<'PY'
import json, datetime, os

vault = os.path.expanduser(os.environ.get("THINKOS_HOME") or "~/ThinkOS/vault")
ledger = os.path.join(vault, "90 System", "Capture Log.md")
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
event = {
    "ts": now,
    "source": "<original source>",
    "detail": {
        "undone_ts": "<original ts>",
        "undone_output": "<original output>"
    },
    "output": None,
    "mode": "undone",
    "bytes": 0
}
with open(ledger, "a") as fh:
    fh.write(json.dumps(event) + "\n")
print("Ledger updated.")
PY
```

## Step 6 — Confirm

Tell the user:
- What was removed (one-line summary of the block)
- That the reversal is recorded in the ledger under the original `ts`
- That Basic Memory's index may need a moment to catch up; if they search and still see the content, run `/thinkos-reindex`

## Rules

- Never edit a vault file without showing the exact content to be removed first.
- Never edit a vault file without explicit "Yes, remove it" confirmation.
- If the identified block is ambiguous (multiple matches), abort and tell the user they need to remove it manually: provide the file path and the approximate timestamp to look for.
- The ledger itself is append-only — never delete ledger lines, only append `undone` events.

User message: $ARGUMENTS
