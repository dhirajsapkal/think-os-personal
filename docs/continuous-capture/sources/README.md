---
type: index
tags:
- continuous-capture
- sources
- phase-c
permalink: think-os/continuous-capture/sources/README
---

# Continuous capture — Sources

External sources that Think OS can ingest on a schedule. Each source writes to a daily or per-event vault file and appends a ledger event to the vault note "Capture Log" at `90 System/Capture Log.md`.

---

## Source table

| Source | File | Schedule | Default vault destination | Privacy tier |
|---|---|---|---|---|
| `granola` | `granola.md` | Hourly | `04 Knowledge/Meetings/<date>-<slug>.md` | Medium — meeting transcripts |
| `calendar` | `calendar.md` | Daily 6am | `01 Now/Signals/calendar-<date>.md` | Low — event titles + attendees |
| `linear` | `linear.md` | Daily 6am | `01 Now/Signals/linear-<date>.md` | Low — ticket titles + status |
| `clickup` | `clickup.md` | Daily 6am | `01 Now/Signals/clickup-<date>.md` | Low — task titles + status |
| `gmail` | `gmail.md` | Daily 6am | `01 Now/Signals/gmail-<date>.md` | Medium-high — subject + body snippet |
| `slack` | `slack.md` | Hourly | `01 Now/Signals/slack-<date>.md` | High — DMs + direct mentions |

---

## Recommended enabling order

Enable in this order: **safest sources first, most sensitive last.** The rationale is that you want to test the capture pipeline (ledger writes, vault file format, dedup logic) with low-sensitivity data before enabling sources that capture private communications.

1. **Granola** — structured meeting transcripts. You already own this data; Granola recorded it. Low risk of unintended capture.
2. **Calendar** — event titles and attendees only. No message content. Easy to audit.
3. **Linear** — ticket titles and status changes. Professional context, rarely sensitive.
4. **ClickUp** — same as Linear. Two task trackers may overlap; that's fine.
5. **Gmail** — filtered to starred threads and threads where you replied. Subject + sender in ledger; body in vault. Sensitive if you star personal email; review the filter before enabling.
6. **Slack** — DMs and @-mentions only. Most sensitive. Read the privacy filter carefully before enabling.

The `/thinkos-capture-setup` command enforces this order — it will not offer Slack before offering the others.

---

## Privacy notes

All sources share this baseline rule (from `templates/instructions/30-think-os-write-targets.md`):

> If detail contains any of `{comp, salary, HR, health, family, performance, 1:1, performance review}` keywords → vault destination becomes personal hub only, never project vault. Ledger entry gets `redacted: true` and `detail` omits the matching content.

Source-specific extensions to the keyword list are documented in each source file. The Slack source has the longest keyword list; the Calendar source has the shortest.

**Ledger vs vault content boundary:**
- The capture ledger (vault note "Capture Log" at `90 System/Capture Log.md`) is a lightweight audit trail. It records identifiers (meeting id, thread id, task id), titles, and timestamps — never full content. The ledger lives as a markdown note in the vault so both shell-based writers (Claude Code launchd) and MCP-based writers (Cowork `/schedule`) can append to it.
- The vault files contain full content. They are subject to vault privacy routing (personal hub vs project vault).
- If you delete a vault file, the ledger entry remains. The ledger is append-only and not cleaned by the capture system.

---

## Shared contracts

All sources conform to Phase B's ledger schema:

```json
{
  "ts": "<ISO 8601>",
  "source": "<source name>",
  "detail": { ... },
  "output": "<vault relative path>",
  "mode": "create" | "append" | "overwrite",
  "bytes": 1234
}
```

Optional fields appended when relevant: `"redacted": true`, `"redacted_events": N`, `"redacted_tickets": N`.

---

## Prerequisites before enabling any source

1. Phase B's audit ledger must be initialized: the vault note "Capture Log" at `90 System/Capture Log.md` must exist. Create it if missing via `mcp__basic-memory__write_note(path="90 System/Capture Log.md", content="# Capture Log\n")`.
2. The relevant MCP must be connected and authenticated. Check via `claude mcp list`.
3. Basic Memory (`mcp__basic-memory__write_note`, `mcp__basic-memory__edit_note`) must be operational.

Run `/thinkos-capture-setup` to enable sources interactively. Run `/thinkos-automate list` to see active capture triggers.
