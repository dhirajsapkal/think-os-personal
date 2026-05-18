---
title: Capture Log Schema — Canonical Reference
permalink: think-os/docs/continuous-capture/capture-log-schema
---

# Capture Log Schema

Canonical contract for the vault note "Capture Log" at `90 System/Capture Log.md`. Every writer and reader (Phase A session-capture, Phase C external-ingest playbooks, `thinkos-recent.sh`, `thinkos-doctor.sh`) must conform to this schema. The ledger lives as a markdown note in the vault so any MCP-based writer (via `mcp__basic-memory__edit_note`) or shell-based writer (Claude Code launchd) can append to it. Lines starting with `{` are parseable as JSON.

---

## File format

- **JSONL**: one JSON object per line, newline-terminated (`\n`).
- **Append-only**: never delete or modify existing lines; only append.
- **UTF-8**: all string values must be valid UTF-8.
- **No trailing commas, no comments**: strict JSON per line.
- Blank lines are allowed and must be skipped by readers.

---

## Line schema

```json
{
  "ts":       "<ISO8601 UTC>",
  "source":   "<source-enum>",
  "detail":   {},
  "output":   "<vault-relative-path> | null",
  "mode":     "<mode-enum>",
  "bytes":    0,
  "redacted": true
}
```

### Field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | string | yes | Timestamp of the capture event. ISO 8601 UTC, format `YYYY-MM-DDTHH:MM:SSZ`. Set at time of write, not at time of source data. |
| `source` | string | yes | Which integration produced this event. Must be one of the source enum values below. |
| `detail` | object | yes | Source-specific metadata. Schema varies by source (see per-source examples below). Never contains vault content — only metadata that identifies the source record. Empty object `{}` is valid when no metadata is available. |
| `output` | string or null | yes | Vault-relative path of the file written to. Relative to `OS_HOME` (e.g., `01 Now/Work Log.md`). `null` for `noop`, `skipped`, and `undone` modes. |
| `mode` | string | yes | How the output was written. Must be one of the mode enum values below. |
| `bytes` | integer | yes | Number of bytes written to the output file. `0` for `noop`, `skipped`, and `undone`. Must be a non-negative integer. |
| `redacted` | boolean | no | Present and `true` only when privacy routing intercepted the entry. When present, the `detail` field will be an empty object `{}`. Omit entirely when not redacted (do not write `"redacted": false`). |

---

## Source enum

| Value | Description |
|-------|-------------|
| `session` | Automatic session summary written every ~2 hours by the session-capture automation. |
| `granola` | Meeting notes ingested from Granola. |
| `slack` | Signals or summaries ingested from Slack channels or threads. |
| `gmail` | Thread summaries or action items ingested from Gmail. |
| `calendar` | Calendar event metadata ingested from Google Calendar. |
| `linear` | Issue updates or project state ingested from Linear. |
| `clickup` | Task or project state ingested from ClickUp. |
| `manual` | Explicitly user-initiated capture (e.g., `/thinkos-capture` or `/thinkos-log`). |

New sources introduced in future phases must be added to this enum before shipping.

---

## Mode enum

| Value | Description |
|-------|-------------|
| `append` | Content was appended to an existing vault file. |
| `create` | A new vault file was created. |
| `update` | An existing vault file was overwritten or a specific section replaced. |
| `noop` | No change was needed (content was already up to date). |
| `skipped` | Capture was skipped intentionally (e.g., duplicate, rate-limited, user opted out of this source). |
| `undone` | A previous capture was reversed by `/thinkos-undo-capture`. `output` is `null`; `detail` records the original event's `ts` and `output`. |

---

## Per-source detail schemas

Each `detail` object contains only metadata — identifiers, labels, and timestamps from the source system. No content from the source system belongs here.

### `session`

```json
{
  "ts": "2026-05-14T14:30:00Z",
  "source": "session",
  "detail": {
    "session_id": "claude-code-20260514-143000",
    "projects": ["think-os-alpha"],
    "duration_min": 120
  },
  "output": "01 Now/Work Log.md",
  "mode": "append",
  "bytes": 312
}
```

`detail` fields: `session_id` (string, opaque identifier), `projects` (array of strings, project slugs touched), `duration_min` (integer, approximate session length).

### `granola`

```json
{
  "ts": "2026-05-14T13:15:00Z",
  "source": "granola",
  "detail": {
    "meeting_id": "granola-abc123",
    "title": "Product Sync",
    "meeting_ts": "2026-05-14T12:00:00Z",
    "attendee_count": 5
  },
  "output": "04 Knowledge/Meetings/2026-05-14-product-sync.md",
  "mode": "create",
  "bytes": 1840
}
```

`detail` fields: `meeting_id` (string), `title` (string), `meeting_ts` (ISO8601), `attendee_count` (integer).

### `slack`

```json
{
  "ts": "2026-05-14T14:00:00Z",
  "source": "slack",
  "detail": {
    "channel": "C012AB3CD",
    "channel_name": "design-team",
    "thread_ts": "1715692800.000100",
    "message_count": 18
  },
  "output": "01 Now/Signals/slack-2026-05-14.md",
  "mode": "append",
  "bytes": 420
}
```

`detail` fields: `channel` (string, Slack channel ID), `channel_name` (string), `thread_ts` (string, Slack thread timestamp, omit for channel-level captures), `message_count` (integer).

### `gmail`

```json
{
  "ts": "2026-05-14T11:45:00Z",
  "source": "gmail",
  "detail": {
    "thread_id": "18f2a3b4c5d6",
    "subject": "Q2 roadmap review",
    "message_count": 4,
    "labels": ["INBOX", "IMPORTANT"]
  },
  "output": "01 Now/Signals/gmail-2026-05-14.md",
  "mode": "append",
  "bytes": 280
}
```

`detail` fields: `thread_id` (string), `subject` (string), `message_count` (integer), `labels` (array of strings).

### `calendar`

```json
{
  "ts": "2026-05-14T08:00:00Z",
  "source": "calendar",
  "detail": {
    "event_id": "gcal_event_xyz789",
    "summary": "1:1 with Alex",
    "start": "2026-05-14T10:00:00Z",
    "end": "2026-05-14T10:30:00Z",
    "attendee_count": 2
  },
  "output": "01 Now/Current Focus.md",
  "mode": "append",
  "bytes": 95
}
```

`detail` fields: `event_id` (string), `summary` (string), `start` (ISO8601), `end` (ISO8601), `attendee_count` (integer).

### `linear`

```json
{
  "ts": "2026-05-14T16:30:00Z",
  "source": "linear",
  "detail": {
    "issue_id": "ENG-1234",
    "title": "Implement capture ledger schema",
    "state": "In Progress",
    "project": "Think OS Alpha"
  },
  "output": "02 Projects/think-os-alpha.md",
  "mode": "update",
  "bytes": 156
}
```

`detail` fields: `issue_id` (string), `title` (string), `state` (string), `project` (string).

### `clickup`

```json
{
  "ts": "2026-05-14T17:00:00Z",
  "source": "clickup",
  "detail": {
    "task_id": "cu_task_abc",
    "name": "Ship Phase B trust layer",
    "status": "in progress",
    "list_name": "Think OS"
  },
  "output": "01 Now/Tasks.md",
  "mode": "append",
  "bytes": 88
}
```

`detail` fields: `task_id` (string), `name` (string), `status` (string), `list_name` (string).

### `manual`

```json
{
  "ts": "2026-05-14T15:00:00Z",
  "source": "manual",
  "detail": {
    "command": "/thinkos-log",
    "context": "think-os-alpha"
  },
  "output": "01 Now/Work Log.md",
  "mode": "append",
  "bytes": 180
}
```

`detail` fields: `command` (string, the slash command or script that triggered the capture), `context` (string, project slug or session label).

### `undone` events

An `undone` event records that a previous capture was reversed:

```json
{
  "ts": "2026-05-14T18:00:00Z",
  "source": "session",
  "detail": {
    "undone_ts": "2026-05-14T14:30:00Z",
    "undone_output": "01 Now/Work Log.md"
  },
  "output": null,
  "mode": "undone",
  "bytes": 0
}
```

The `source` field echoes the source of the original capture. `detail` contains `undone_ts` (ISO8601, the `ts` of the original event) and `undone_output` (vault-relative path of the original output).

### Redacted events

When privacy routing intercepts a capture:

```json
{
  "ts": "2026-05-14T16:00:00Z",
  "source": "gmail",
  "detail": {},
  "output": "05 Profile/Private.md",
  "mode": "append",
  "bytes": 220,
  "redacted": true
}
```

`detail` is always an empty object. The `output` records where the content was routed. `redacted: true` is the only sentinel; absence of the field means not redacted.

---

## Validation rules

Readers and writers must enforce:

1. `ts` parses as ISO8601 UTC (trailing `Z` required).
2. `source` is one of the eight enum values.
3. `mode` is one of the six enum values.
4. `bytes` is a non-negative integer.
5. `output` is either a string (non-empty, vault-relative, no leading `/`) or JSON `null`.
6. When `redacted: true`, `detail` must be `{}`.
7. When `mode` is `undone`, `output` must be `null` and `detail` must contain `undone_ts` and `undone_output`.

`thinkos-doctor.sh`'s `capture:ledger` check validates rule 1 (parseable JSON per line). Full field validation is the writer's responsibility.

---

## CWD field sensitivity

The `cwd` field in session-capture entries records the full filesystem path of each Claude Code working directory. For consultancies and other contexts where directory names encode client/project names, set `THINKOS_MASK_CWD=1` (in your shell or LaunchAgent EnvironmentVariables) to mask CWD to its basename only.

If your vault has a git remote, ensure it is private before enabling session capture.

---

## Rotation

Rotation: TBD. With the ledger now living in the vault as a markdown note (`90 System/Capture Log.md`), rotation will eventually split the note by quarter (e.g., `90 System/Capture Log 2026-Q2.md`). For now the single note grows append-only; size budget is the same as any other Basic Memory note. `thinkos-capture-rotate.sh` is a no-op until a quarterly-split strategy is implemented.
