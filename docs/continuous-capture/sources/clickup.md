---
type: capture-source
source: clickup
schedule: daily-6am
status: stable
tags:
- continuous-capture
- clickup
- tasks
- phase-c
permalink: think-os/continuous-capture/sources/clickup
---

# Continuous capture — ClickUp

## What this captures

ClickUp tasks assigned to the user that changed status in the past 24 hours. This is the ClickUp equivalent of the Linear source: a daily pulse on what moved in your task board — what completed, what entered review, what got assigned overnight.

What does NOT count: tasks assigned to others even if you're a watcher, tasks that had only description edits or comment additions with no status change, tasks in closed lists that haven't been touched in 30+ days.

## Filter (what's worth capturing)

1. Tasks where the current user is an assignee (`mcp__claude_ai_ClickUp__clickup_get_workspace_members` to resolve user ID, then `mcp__claude_ai_ClickUp__clickup_filter_tasks` with `assignees` filter).
2. `date_updated` within the past 25 hours (one-hour overlap).
3. A status change must have occurred — compare current status against the last-captured status from `~/.thinkos/capture-log.jsonl`. Tasks not previously seen are always included (new assignment counts as a status change from "none").
4. Skip tasks in `closed` status where `date_done` is more than 7 days ago — captured on the day they closed; no need to re-surface.

The `mcp__clickup__get_tasks` tool (the MCP server-side ClickUp integration) and `mcp__claude_ai_ClickUp__clickup_filter_tasks` (the claude.ai plugin) are both available. The trigger uses `mcp__claude_ai_ClickUp__clickup_filter_tasks` as the primary path because it supports the `date_updated_gt` filter parameter. The `mcp__clickup__*` tools are used for fallback reads (`mcp__clickup__get_task`) if specific task details are needed.

## Schedule

- Cron (UTC): `0 11 * * *`
- Translated: "daily at 6am US Eastern (11am UTC)"
- Why this cadence: same reasoning as Linear — daily task-movement summary is the right granularity. ClickUp can be high-volume; hourly capture would generate noise.

## Vault destination

`01 Now/Signals/clickup-<YYYY-MM-DD>.md`

Overwrite mode: if the file exists from a retry, replace it. One file per calendar day.

## Privacy routing

Same keyword set as Linear. ClickUp tasks occasionally carry sensitive titles in HR or ops workspaces:

`comp`, `salary`, `compensation`, `HR`, `performance review`, `PIP`, `health`, `personal`, `offer`

When matched:
- Ticket entry replaced with `[task redacted — personal]` in vault file.
- Title omitted from ledger; only `task_id` retained.
- Ledger entry gets `"redacted": true`.

## Trigger prompt

Register this verbatim via `CronCreate`:

```
You are the Think OS ClickUp capture agent. Run daily.

Step 1 — Determine today's date (YYYY-MM-DD) and the cutoff timestamp: now minus 25 hours (Unix milliseconds, since ClickUp uses ms timestamps).

Step 2 — Resolve your ClickUp user identity.
Call mcp__claude_ai_ClickUp__clickup_get_workspace_members to get the workspace member list.
Identify your user by matching against the Think OS identity (name or email in 05 Profile/Identity.md via mcp__basic-memory__read_note).
Extract your ClickUp user_id.

Step 3 — Fetch tasks assigned to me updated in the past 25 hours.
Call mcp__claude_ai_ClickUp__clickup_filter_tasks with:
  - assignees: [<your user_id>]
  - date_updated_gt: <cutoff in Unix ms>
  - include_closed: true (so completed tasks are visible)
  - order_by: date_updated
  - reverse: true (newest first)
  - page: 0

If the result has 100 items (the max page size), fetch page 1 as well. Stop at page 1 — more than 200 updated tasks in 24 hours indicates noise.

Step 4 — Filter for actual status changes.
For each task:
  a. Check ~/.thinkos/capture-log.jsonl for the most recent entry with source == "clickup" and detail.task_id == this task's id. Extract previous_status.
  b. If current status != previous_status (or no prior entry), include this task.
  c. Otherwise skip.

Step 5 — For tasks that pass the filter, fetch full detail if needed.
If the filter_tasks response did not include the task URL, call mcp__claude_ai_ClickUp__clickup_get_task with the task id to get the full object.

Step 6 — Privacy check.
For each remaining task, scan name and description for (case-insensitive):
  comp, salary, compensation, HR, performance review, PIP, health, personal, offer
Set REDACT = true if any keyword matches.

Step 7 — Build the snapshot file.
Path: 01 Now/Signals/clickup-<YYYY-MM-DD>.md

Content:
  ---
  source: clickup
  date: <YYYY-MM-DD>
  task_count: <N>
  captured_at: <ISO timestamp>
  ---

  # ClickUp — <YYYY-MM-DD>

  For each task (REDACT == false):
  ## <status> — <task name>
  **ID:** <task id>
  **List:** <list name> / <space name>
  **Status:** <previous_status or "new"> -> <current status>
  **Priority:** <priority or "none">
  **Updated:** <date_updated as ISO>
  **Link:** <task URL>

  For each task (REDACT == true):
  ## [task redacted — personal]

  ---
  *<N> task(s) with status changes in the past 24 hours.*

Step 8 — Write via mcp__basic-memory__write_note to 01 Now/Signals/clickup-<YYYY-MM-DD>.md (overwrite).

Step 9 — Append one ledger event per captured task to ~/.thinkos/capture-log.jsonl:
  {
    "ts": "<ISO now>",
    "source": "clickup",
    "detail": {
      "task_id": "<id>",
      "title": "<name>",
      "status": "<current status>",
      "previous_status": "<prior status or null>",
      "list": "<list name>"
    },
    "output": "01 Now/Signals/clickup-<YYYY-MM-DD>.md",
    "mode": "append",
    "bytes": <byte length of this task's section>
  }
  For redacted tasks, omit "title" from detail and add "redacted": true.

Step 10 — Output one line: "ClickUp snapshot written: <N> task(s) with status changes for <YYYY-MM-DD>."
```

## Ledger event shape

```json
{"ts":"2026-05-14T11:00:00Z","source":"clickup","detail":{"task_id":"86a1234xz","title":"Update onboarding flow copy","status":"Complete","previous_status":"In Review","list":"Design"},"output":"01 Now/Signals/clickup-2026-05-14.md","mode":"append","bytes":298}
```

## How to enable

Run `/thinkos-capture-setup clickup` — or run `/thinkos-capture-setup` and select ClickUp when prompted.

Prerequisites:
- ClickUp MCP connected. Both `mcp__claude_ai_ClickUp__*` and `mcp__clickup__*` are available in this environment. The trigger uses `mcp__claude_ai_ClickUp__clickup_filter_tasks` as the primary fetch tool.
- Run `claude mcp list` to confirm authentication.

## How to disable

1. Run `/thinkos-automate list` to find `think-os-capture-clickup`.
2. Run `/thinkos-automate remove think-os-capture-clickup`.
3. Past snapshot files remain; future snapshots stop.
