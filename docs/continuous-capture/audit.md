---
title: Continuous Capture — Trust Model and Audit Guide
permalink: think-os/docs/continuous-capture/audit
---

# Continuous Capture — Trust Model and Audit Guide

Think OS captures context automatically: session summaries every two hours, and external data from connected tools (Granola, Slack, Gmail, Calendar, Linear, ClickUp) on a scheduled basis. This document explains how to verify what was captured, how to undo anything you didn't want captured, and why the design separates legibility from content.

---

## What the ledger records

Every capture appends one JSON line to the vault note "Capture Log" (at `90 System/Capture Log.md`) via `mcp__basic-memory__edit_note(identifier="Capture Log", operation="append", content="...")`. The ledger records **metadata only**:

- When the capture happened (`ts`)
- Which integration produced it (`source`)
- Source-specific metadata (`detail`) — meeting IDs, channel names, issue keys, session context markers
- Where the output landed in your vault (`output`)
- How it was written (`mode`: append, create, update, noop, skipped)
- How many bytes were written (`bytes`)
- Whether privacy routing intercepted it (`redacted: true`)

The ledger does **not** record the content itself. If you delete or edit the destination vault file, the ledger still shows that the capture happened and where it went — event and output are separate.

This is intentional. The ledger is an audit trail. It answers "did this happen and where did it go?" without duplicating your vault content.

---

## Inspecting captures

### Command line

```bash
# Last 24 hours, all sources
bash scripts/thinkos-recent.sh

# Last 48 hours
bash scripts/thinkos-recent.sh --hours 48

# Only Granola meeting captures
bash scripts/thinkos-recent.sh --source granola

# Confirm what metadata is captured without seeing content
bash scripts/thinkos-recent.sh --redact

# Machine-readable output
bash scripts/thinkos-recent.sh --json
```

### Slash command

In Claude Code: `/thinkos-recent`

After showing the summary table, the agent offers to open the most recent output file from any source group, so you can see the actual vault content that was written.

### Health check

```bash
bash scripts/thinkos-doctor.sh
```

This runs four capture-specific checks:

- `capture:ledger` — ledger exists, every line is valid JSONL
- `capture:last_session` — most recent session capture; warns if more than 4 hours old during 9am–9pm local time
- `capture:24h_volume` — total events in the last 24 hours; warns if zero (suggests automation is not running)
- `capture:redaction_count` — informational count of entries intercepted by privacy routing

---

## Undoing a capture

If a capture landed something you didn't want, `/thinkos-undo-capture` removes it cleanly.

The flow:
1. Lists the last 10 actionable captures with a chip picker.
2. You pick one.
3. The agent reads the destination file and shows you the exact block it would remove.
4. You confirm. Only then does it remove the block.
5. A `mode: undone` event is appended to the ledger, recording the reversal.

The ledger itself is append-only. Undos are recorded as new events, not deletions. This means the audit trail is complete even after an undo.

If the destination file was edited manually after the capture, the undo will refuse to proceed and tell you the exact location to edit by hand.

---

## Rotation

Rotation: TBD. With the ledger now living in the vault as a markdown note (`90 System/Capture Log.md`), rotation will eventually split the note by quarter (e.g., `90 System/Capture Log 2026-Q2.md`). For now the single note grows append-only; size budget is the same as any other Basic Memory note.

`scripts/thinkos-capture-rotate.sh` and `thinkos-doctor.sh`'s `capture:ledger` check are aware of this change. Rotation is a no-op until a quarterly-split strategy is implemented.

---

## Privacy routing

If a capture is intercepted by privacy routing (personal markers — comp, salary, HR, health, family, performance), the event is written to the ledger with `"redacted": true` and the `detail` field is cleared. The `output` records where it was routed (personal hub), but the `detail` content is not stored in the ledger.

You can confirm routing without seeing content:

```bash
bash scripts/thinkos-recent.sh --redact
```

This replaces all `detail` values with `<redacted>` in the output — useful for showing someone else the structure of your capture activity without exposing any content.

---

## Why event and output are separate

Once a capture is written to the vault, the vault file can be edited — by you, by another agent, or by Basic Memory's reindex. The ledger record is immutable. This means:

- You can audit what was captured even if the vault file no longer contains it.
- `/thinkos-undo-capture` knows what to look for even if surrounding content has shifted.
- Rotation of the vault file does not break the audit trail.

The ledger is the receipt. The vault file is the result. They are related but independent.
