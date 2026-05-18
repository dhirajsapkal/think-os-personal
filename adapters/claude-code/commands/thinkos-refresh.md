---
description: Refresh Tasks.md from connectors (Gmail, Slack, Calendar, ClickUp, Atlassian, Notion, Granola)
permalink: think-os/adapters/claude-code/commands/thinkos-refresh
---

You are running `/thinkos-refresh`. This is the **connector-sweep** command — it pulls fresh state from the user's connected tools (Gmail, Slack, Calendar, ClickUp, Atlassian, Notion, Granola), reconciles against the current `01 Now/Tasks.md`, and rewrites the file with a fresh `last_synced` timestamp.

This is the canonical refresh path. The previous `productivity:update` skill is retired — its behavior lives here, but in the `/thinkos-*` namespace and portable across surfaces (Claude Code, Cowork, desktop agent — anywhere a connector MCP is reachable).

---

## Step 0 — Parse arguments

`$ARGUMENTS` may include any of:

| Flag | Effect |
|---|---|
| `--quick` | High-signal sources only: Gmail, Slack, Calendar, ClickUp (~15s). Skips Atlassian / Notion / Granola. |
| `--comprehensive` | All seven sources. Default behavior — only flag if user wants to be explicit. |
| `--source <name>` | Refresh only one source. Valid: `gmail`, `slack`, `calendar`, `clickup`, `atlassian`, `notion`, `granola`. |
| `--dry-run` | Show the diff but do NOT write Tasks.md. Useful for sanity-checking before commit. |
| `--days <N>` | Override default lookback window (default: 1d Gmail, 2d Slack, 7d Calendar). |

If `$ARGUMENTS` is empty → default to `--comprehensive`.

---

## Step 1 — Surface detection

Determine which connector path to use:

1. Run `claude mcp list 2>&1` (Bash).
2. For each source needed, check the output:
   - `claude.ai <Service>: ✓ Connected` → use the bridge tools `mcp__claude_ai_<Service>__*`.
   - Native MCP entry (e.g. `gmail-mcp`) → use those tool names instead.
   - Neither → mark source as `unavailable`, skip with a flag in the diff summary.

The bridge tool names follow this map (verify via `ToolSearch query="<service-name>" max_results=10` if uncertain):

| Source | Bridge tool prefix |
|---|---|
| Gmail | `mcp__claude_ai_Gmail__*` |
| Slack | `mcp__claude_ai_Slack__*` |
| Calendar | `mcp__claude_ai_Google_Calendar__*` |
| ClickUp | `mcp__claude_ai_ClickUp__*` |
| Atlassian | `mcp__claude_ai_Atlassian__*` |
| Notion | `mcp__claude_ai_Notion__*` |
| Granola | `mcp__claude_ai_Granola__*` |

If `ToolSearch` for a needed source returns nothing AND `claude mcp list` shows no native MCP, that source is genuinely unavailable. Don't fail the whole sweep — proceed with what's reachable and flag the gap in the final summary.

---

## Step 2 — Read current state

Read the current Tasks.md so the agent has the baseline for dedup + preservation:

```
mcp__basic-memory__read_note("Tasks")
```

Note the `last_synced` value in frontmatter — this becomes the lower bound of the lookback if larger than the default window.

Also read `90 System/Connectors.md` once if filter-rule context is unclear — it documents the per-source extraction rules (e.g. ClickUp 90d stale filter).

---

## Step 3 — Parallel connector pulls

Run all enabled connector pulls **in parallel** (single assistant turn, multiple tool calls). Apply the rules below per source.

### Gmail (lookback: 24h or `--days N`)

Query patterns (use `mcp__claude_ai_Gmail__search_threads`):

- **Unread + relevant**: `is:unread newer_than:1d -category:promotions -category:social`
- **Calendar invites** (new this window): `subject:(invitation OR invite OR meeting OR scheduled) newer_than:1d`
- **Cancellations**: `subject:(cancelled OR canceled OR rescheduled) newer_than:2d`

**Filter (skip as noise — already documented in current Tasks.md):** Coursera promo, ClickUp newsletter, Slack feedback ask, Deque newsletter, Basecamp digests, calendar auto-invite confirmations the user already accepted.

**Extract per thread:** sender, subject, 1-line context, suggested action (reply / FYI / cancellation), priority signal (urgent / today / week / informational).

### Slack (lookback: 48h or `--days N`)

Two pulls:

1. **DMs awaiting reply** — for each DM channel the user has been active in last 7d, call `mcp__claude_ai_Slack__slack_read_channel` with `limit=5`. If the last message is NOT from the user AND was sent within 48h, that's an awaiting-reply candidate.
2. **Watched channels** — extract channel names from existing Tasks.md `### 🔔 Slack tracker → **Watching**` section. For each, read the last 48h. Surface anything @-mentioning the user, anything in a thread the user participated in, anything from a manager/exec (cross-ref `03 People/People.md` for the Quick map).

**Skip:** Personal channels (`#beerswap`, book group DMs with Caleb/Chris N), spam (per People.md flagged contacts).

**Extract per thread:** counterparty, channel, 1-line gist, suggested action, freshness (today / N hours ago).

### Calendar (lookback: today + next 7d)

`mcp__claude_ai_Google_Calendar__list_events` for today + 7 days. Group by day. Highlight: 1:1s with manager / skip-level, client meetings, recurring planning blocks. Tag external attendees if any.

### ClickUp

`mcp__claude_ai_ClickUp__clickup_filter_tasks` (or search) — tasks assigned to the user.

**Apply `Connectors.md` filter rules:**

- Exclude `due_date` >90d past **AND** `status` NOT in (`in progress`, `up next`, `🛠️ in progress`).
- Exclude `cancelled` and `completed` by default.
- Also exclude tasks that closed since the last sync (these go to "Done (this week)" if user-completed, dropped if cancelled).

**Extract per task:** task name, status, due date (or "no due"), project link, ClickUp ID.

**Also surface:** recent activity on the user's tasks (last 24h) — new comments, status changes by others, new assignees.

### Atlassian (Confluence-only — no Jira)

Confluence pages the user authored or edited in the last 48h. Also: pages where someone @-mentioned the user.

Skip Jira queries entirely — connector lacks the scope (per `Connectors.md`).

### Notion

**Only pull if `--source notion` was explicitly passed** OR `--comprehensive` was explicit. Per `Connectors.md` default rule, Notion is not queried on the standard sweep.

When pulled: recent edits + comments mentioning the user in the AI Implementation Hub workspace.

### Granola (today's meetings)

`mcp__claude_ai_Granola__list_meetings` with `time_range=this_week` or custom. Filter to meetings that ended within the last 24h OR are scheduled for today. Don't pull full transcripts here — just surface meeting titles + attendees as "context for action items." If the user wants meeting notes captured to the vault, that's a separate `/thinkos-capture` flow.

---

## Step 4 — Triage + dedup against current Tasks.md

For each extracted candidate, decide one of four dispositions:

1. **NEW** — not in current Tasks.md. Add under the right source section.
2. **CHANGED** — already in Tasks.md but the source state has shifted (e.g. ClickUp task moved from `to do` → `completed`). Update inline or move to "Done."
3. **RESOLVED** — was in Tasks.md, now closed/cancelled in source. Move to "Done (this week)" section if user-completed; drop with a `⚪ <reason>` note if cancelled by someone else.
4. **NO-OP** — already in Tasks.md, unchanged. Keep.

**Preserve verbatim:**

- The `### Manually added` section — never auto-edit user-added items.
- The `## Done (this week)` section — append CHANGED/RESOLVED items, don't drop existing entries.
- Tasks.md frontmatter except `last_synced` (which you'll update in Step 6).
- The `## Conventions` section at the bottom.

---

## Step 5 — Diff summary

Before writing, compose a one-screen diff summary. Format:

```
Refresh summary (sources: gmail, slack, calendar, clickup [, ...]):

  +N new items
    • <source>: <verb> <object>  — <1-line context>
    • ...
  ~N changed items
    • <source>: <task name> — <old state> → <new state>
  -N resolved/dropped
    • <source>: <task name> — <reason>

  Sources unavailable: <list, if any> — flag-only, didn't block.
```

If `--dry-run`, print the diff summary + the proposed Tasks.md content (or a unified diff if size permits) and STOP here. Do not write.

---

## Step 6 — Write Tasks.md

Compose the new Tasks.md preserving the canonical section order:

```
---
permalink: think-os/01-now/tasks
title: Tasks
type: note
aliases: [tasks, TASKS, inbox, action-items]
tier: WARM
last_synced: '<ISO 8601 with timezone>'
tags: [tasks, inbox, warm-tier]
visibility: private
sources: [gmail, slack, clickup, atlassian, notion, calendar]
---

# TASKS

> **Last synced: <human-readable timestamp>** (N action items)

> WARM TIER. Connector-synced inbox of open items pulled from Gmail, Slack, ClickUp, Atlassian, Notion, and Calendar. Refreshed by `/thinkos-refresh`.
>
> **This is the inbox layer.** For *stated priorities* (what I decided matters this week), see [[Current Focus]].

## Last sync

**<human timestamp>** — `/thinkos-refresh` (sources: <list>). <One-line summary of what changed.>

## Open

### ⏰ Action items
<merged items from Gmail/Slack/manual, prioritized>

### 🛠️ Active project work
<ClickUp active tasks, kept linked, not duplicated as actions>

### 📅 Calendar — today + next 7d
<grouped by day>

### 🔔 Slack tracker

**Awaiting reply** — DMs/threads where someone is waiting on you.
<list>

**Watching** — channels/threads to keep tabs on.
<list>

**Slack reminders** — things you want to ping someone about, not yet sent.
<list>

---

### From Gmail — informational
<grouped: Resolved/changed since last sync, Other unread notable, Skip (noise)>

### From [[ClickUp]] — recent activity
<list>

### Filtered out (per `Connectors.md` ClickUp rule)
<count + 1-line summary>

### From Atlassian
<list or "No new query this run.">

### From Notion
<list or "Not queried this sync.">

### Manually added
*Anything Dhiraj asks Claude to track that doesn't come from a connector lands here.*
<PRESERVED VERBATIM from prior Tasks.md>

## Done (this week)
<NEW resolved items APPENDED to existing list — do not drop entries>

---

## Conventions
<PRESERVED VERBATIM>

*Last reviewed: <today>. Refreshed via /thinkos-refresh.*
```

Write via:

```
mcp__basic-memory__edit_note(
  identifier="Tasks",
  operation="replace",
  content="<full rendered Tasks.md body>"
)
```

If `edit_note` with `operation=replace` fails (some Basic Memory versions don't support full replace), fall back to `mcp__basic-memory__write_note` with `overwrite=true`.

---

## Step 7 — Append capture-log event

```
mcp__basic-memory__edit_note(
  identifier="Capture Log",
  operation="append",
  content='{"ts":"<ISO8601 UTC>","source":"connector-sync","detail":{"via":"thinkos-refresh","sources":["gmail","slack","calendar","clickup",...],"new":<N>,"changed":<N>,"resolved":<N>,"unavailable":[<list>]},"output":"01 Now/Tasks.md","mode":"replace","bytes":<bytes of new file>}\n'
)
```

---

## Step 8 — Confirm

One-line summary to the user:

> Tasks.md refreshed — <ISO timestamp>. Pulled from <N> sources. Diff: +<N> new, ~<N> changed, -<N> resolved. <Run `/thinkos-plate` to see what's on your plate.>

If any source was unavailable, append a second line:

> Note: <source(s)> unavailable this run. <reason if known — e.g., "Notion connector not registered". Run `/thinkos-mcp-help` for connector setup.>

---

## Error handling

- **Connector returns auth error**: skip that source, mark unavailable in the summary. Don't retry — the user needs to reauth.
- **Connector returns empty**: that's a valid result. Note "no new items from <source>" in the summary.
- **Basic Memory write fails**: surface the error verbatim, suggest `bash scripts/thinkos-doctor.sh`. Do NOT retry destructively.
- **Tasks.md doesn't exist**: create from the template in `templates/01 Now/Tasks.md` instead of replacing. Confirm with user before creating.
- **`--dry-run` always wins**: even if a connector fails, dry-run never writes.

---

## Hard rules

- **Parallel pulls only.** Sequential connector calls add 5-10x latency. Always batch in one assistant turn.
- **Never silently drop manual entries.** The `### Manually added` section is sacred.
- **Never overwrite `Done (this week)`** — only append.
- **Honest unavailability.** If Notion connector isn't registered, say "Notion unavailable" — don't pretend it returned empty.
- **No prompts on the happy path.** A clean refresh writes + reports in one shot. Confirmation prompts only on first-run (Tasks.md doesn't exist) or destructive recovery paths.
- **Bridge-first, native fallback.** Prefer the claude.ai bridge tools so this skill works in Claude Code, Cowork, and Desktop without code changes. Native MCPs are the fallback for desktop-agent users who haven't enabled the bridge.

---

## Example invocations

- `/thinkos-refresh` — full sweep, write, report. Most common.
- `/thinkos-refresh --quick` — fast 4-source pull (Gmail, Slack, Calendar, ClickUp) when you just want today's signal.
- `/thinkos-refresh --source slack` — just refresh Slack threads. Useful mid-session if a DM came in.
- `/thinkos-refresh --dry-run` — preview the diff without writing. Use before a high-stakes /thinkos-plate.
- `/thinkos-refresh --days 7` — wider lookback for a weekly review prep.

User message: $ARGUMENTS
