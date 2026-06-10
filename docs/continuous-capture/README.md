---
type: design
status: active
tags:
- continuous-capture
- architecture
- phase-a
- phase-b
- phase-c
permalink: think-os/continuous-capture/README
---

# Continuous Capture

How Think OS passively ingests your work context so your vault stays current without manual maintenance.

---

## The three layers

Continuous capture has three layers. Each layer builds on the previous one.

### Layer A — Session capture (Phase A)

**What**: A local launchd job scans recent Claude Code session activity and appends a one-line entry per session (cwd, file count, last commit) to `01 Now/Work Log.md`. No LLM call; no file contents leave your machine.

**When**: The launchd job runs every ~2 hours during work hours, when the Mac is awake. A Claude Code Stop hook — firing automatically when a session ends — is a future improvement (see `docs/automation-roadmap.md`); it is not how the shipped layer works.

**Privacy**: Session entries stay in the personal hub.

**Cadence**: Every ~2 hours during work hours. Toggle with `/thinkos-autosave on|off|status`.

**Docs**: `docs/continuous-capture/session-capture.md` (Phase A scope).

---

### Layer B — Audit ledger (Phase B)

**What**: Every capture event across all three layers writes a structured JSON line to the vault note "Capture Log" (at `90 System/Capture Log.md`) via `mcp__basic-memory__edit_note`. The ledger is the trust layer — it answers "what did Think OS write, when, from what source, and where."

**Format (one line per event)**:
```json
{"ts":"...","source":"granola","detail":{"meeting_id":"...","title":"..."},"output":"04 Knowledge/Meetings/2026-05-14-product-sync.md","mode":"create","bytes":4821}
```

**Why a ledger**: Without an audit trail, a passive capture system is opaque. The ledger lets you inspect, verify, and delete captures you didn't want. It also provides the deduplication cursor for external-source triggers (each trigger reads the ledger to find the last capture timestamp, avoiding re-ingestion).

**Docs**: `docs/continuous-capture/capture-log-schema.md` and `docs/continuous-capture/audit.md` (Phase B scope — defines the schema this layer conforms to).

---

### Layer C — External ingestion (Phase C, this layer)

**What**: Local launchd jobs pull from external sources — meetings, calendar, task tools, email, Slack — and write vault files. Each source has a playbook document in `docs/continuous-capture/sources/`.

**When**: Each source runs on its own schedule. Granola and Slack run hourly; Calendar, Linear, ClickUp, and Gmail run once daily at 6am. Jobs only fire when the Mac is awake.

**Privacy**: Every source applies a keyword-based privacy routing rule. Sensitive content routes to the personal hub regardless of active vault. Ledger entries for sensitive items are redacted (identifier only; no content).

**Opt-in**: No external source is enabled by default. The user runs `/thinkos-capture-setup` to enable sources one at a time in the safe→sensitive order.

---

## Source index

| Source | Cadence | Vault destination | Privacy tier | Playbook |
|---|---|---|---|---|
| Granola | Hourly | `04 Knowledge/Meetings/<date>-<slug>.md` | Medium | `sources/granola.md` |
| Calendar | Daily 6am | `01 Now/Signals/calendar-<date>.md` | Low | `sources/calendar.md` |
| Linear | Daily 6am | `01 Now/Signals/linear-<date>.md` | Low | `sources/linear.md` |
| ClickUp | Daily 6am | `01 Now/Signals/clickup-<date>.md` | Low | `sources/clickup.md` |
| Gmail | Daily 6am | `01 Now/Signals/gmail-<date>.md` | Medium-high | `sources/gmail.md` |
| Slack | Hourly | `01 Now/Signals/slack-<date>.md` | High | `sources/slack.md` |

---

## How to enable

Run `/thinkos-capture-setup` from Claude Code. The command:

1. Checks that the audit ledger (vault note "Capture Log" at `90 System/Capture Log.md`) exists.
2. Checks that Basic Memory is operational.
3. Offers each source in the safe→sensitive order above (Granola first, Slack last).
4. For each source: shows the filter, asks "Enable?" (chip picker: Enable / Skip / Show me the filter rules first).
5. On Enable: installs the launchd job via `bash scripts/install-launchd-job.sh <source>`.
6. At the end: summarizes what was enabled and shows the cron schedules.

See `adapters/claude-code/commands/thinkos-capture-setup.md` for the full command playbook.

---

## How to audit captures

- **View recent captures**: read the vault note "Capture Log" (at `90 System/Capture Log.md`) via `mcp__basic-memory__read_note`. Scan lines starting with `{` as JSON — one event per line, newest at the bottom.
- **View a day's Signals**: read `01 Now/Signals/<source>-<date>.md` via Basic Memory.
- **List installed capture jobs**: run `/thinkos-automate list` (shows all launchd jobs including capture ones).
- **Disable a source**: run `/thinkos-automate remove <source>`.

---

## Design principles

**Ground-truth links required**: every captured item must include a back-pointer to the source — Granola meeting URL, Slack permalink, Linear ticket URL. Summaries without provenance are not captures; they are hallucinations waiting to be discovered.

**Ledger is append-only**: the capture ledger does not get pruned by the capture system. The quarterly archive (`docs/phase-3-automations-playbook.md`) may rotate it, but individual entries are never deleted by capture agents.

**No LLM summarization at ingest**: external-source triggers write the source content verbatim (transcript body, email snippet, task title). The morning brief and other synthesis agents do the interpretation. Summarizing at ingest loses ground-truth detail and makes the vault a cache of a cache.

**Dedup by cursor, not by hash**: deduplication uses the last-captured timestamp from the ledger plus a one-hour overlap window. Content hashing was considered and rejected — Granola transcripts can be updated after initial processing, and a hash-based approach would miss corrections.

---

## Relationship to Phase 3 automations

Phase 3 (`docs/phase-3-automations-playbook.md`) covers maintenance automations: daily reindex, weekly review, quarterly archive, morning brief. Phase C (this layer) covers external ingestion. They are separate trigger sets with different purposes:

- Phase 3 triggers maintain the vault's internal health.
- Phase C triggers bring new external signal into the vault.

Both use local launchd jobs and are managed via `/thinkos-automate list` / `remove`. They coexist without conflict. The morning brief job (Phase 3) can read the calendar snapshot written by the calendar capture job (Phase C) — this is the intended integration.
