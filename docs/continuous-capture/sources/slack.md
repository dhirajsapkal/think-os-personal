---
type: capture-source
source: slack
schedule: hourly
status: sensitive
privacy-tier: high
tags:
- continuous-capture
- slack
- messages
- phase-c
permalink: think-os/continuous-capture/sources/slack
---

# Continuous capture — Slack

## What this captures

Two categories of high-signal Slack activity:

1. **Direct messages (DMs)** — 1:1 and group DMs where the user is an active participant. Only new messages since the last capture run.
2. **@-mentions** — messages in any channel where the user is explicitly @-mentioned.

**This is the most privacy-sensitive source in Think OS.** DMs are not public communications. The filter below is strict: this is not a channel firehose. No public channel messages are captured unless the user is mentioned. Even within DMs, the full body goes only to the vault file — the ledger contains only the thread permalink and sender, never the message content.

What does NOT count: messages the user sent themselves (outbound), channel messages where the user is not mentioned, Slackbot automated messages, reminder notifications, thread replies in public channels where the user is not in the reply chain.

---

**PRIVACY FILTER — READ THIS BEFORE ENABLING:**

The Slack capture filter captures only:
- DMs sent TO you (not your outbound DMs)
- Messages that @-mention you specifically (not @here, not @channel)

It does NOT capture:
- Any public or private channel messages unless you are directly mentioned
- Messages from bots or Slackbot
- Thread replies unless you are @-mentioned in the reply
- Outbound messages you sent

If this filter is too broad, disable this source. There is no version of this capture that reads channel firehose without your explicit involvement.

---

## Filter (what's worth capturing)

1. **DMs**: Search for `is:dm` messages in the last hour + 5 minutes (capture window overlap). Fetch only messages in conversations where the user is an active member. Exclude Slackbot (`from:Slackbot`) and automated app messages (`subtype: bot_message`).

2. **@-mentions**: Search for `@me` (or the user's actual @handle) in the last hour + 5 minutes. Exclude `@here` and `@channel` broadcasts — only direct user mentions.

3. **Deduplication**: Check `~/.thinkos/capture-log.jsonl` for existing entries with `source: slack` and matching `detail.permalink`. Skip already-captured messages.

4. Cap at 50 items per run. If the user has more than 50 mentions or DMs in an hour, that volume itself is a signal worth noting — the cap prevents runaway token use but the snapshot records that the cap was hit.

Available Slack MCP tools in this environment: `mcp__claude_ai_Slack__slack_search_public_and_private`, `mcp__claude_ai_Slack__slack_read_thread`. Note: `slack_search_public_and_private` returns results from both public and private channels — after fetch, filter to keep only `is:dm` results and explicit `@<username>` mentions.

## Schedule

- Cron (UTC): `0 * * * *`
- Translated: "every hour, on the hour"
- Why this cadence: DMs and @-mentions are time-sensitive. A 24-hour delay means missing context in a fast-moving conversation. Hourly keeps the vault within 60 minutes of reality without flooding it.

## Vault destination

`01 Now/Signals/slack-<YYYY-MM-DD>.md`

Append-per-day: each hourly run appends a new section to the day's file (unlike sources that overwrite). Messages are grouped under an `## HH:MM` time header. If the file does not exist, create it with a date-header frontmatter block first.

## Privacy routing

Slack DMs have the highest privacy sensitivity of any source. Apply the keyword check to the message sender context AND the message body:

`comp`, `salary`, `compensation`, `bonus`, `raise`, `offer letter`, `HR`, `performance review`, `PIP`, `health`, `medical`, `family`, `personal`, `confidential`, `private`, `off the record`

When matched for a specific message:
- That message's body in the vault file is replaced with `[message redacted — personal]`. The section header (time + sender) is kept so the user knows a redacted message exists.
- Ledger entry omits message body; retains only `permalink` and `sender_id`.
- Ledger event gets `"redacted": true`.

**Additional privacy rule**: Group DMs with 3+ participants where the user is the only Think OS user — these are treated as private conversations. The full body is still written to the vault (it is the user's personal vault), but the ledger contains only the permalink.

## Trigger prompt

Register this verbatim via `CronCreate`:

```
You are the Think OS Slack capture agent. Run hourly.

PRIVACY NOTICE: This agent captures only DMs sent to you and messages that @-mention you. It does not capture channel firehose. If you did not intend to enable this, delete the trigger via CronDelete.

Step 1 — Determine the capture window.
Read ~/.thinkos/capture-log.jsonl. Find the most recent entry where source == "slack". Record its ts as LAST_CAPTURE. If no entry exists, use now minus 65 minutes.

Step 2 — Determine today's date (YYYY-MM-DD).

Step 3 — Fetch DMs.
Call mcp__claude_ai_Slack__slack_search_public_and_private with query: "is:dm" and any available time filter for messages after LAST_CAPTURE.
From results, keep only messages where:
  - conversation type is im (1:1 DM) or mpim (group DM)
  - sender is not Slackbot and subtype is not bot_message
  - message was received (not sent by the user)

Step 4 — Fetch @-mentions.
Call mcp__claude_ai_Slack__slack_search_public_and_private with query: "@<your Slack username>" and time filter after LAST_CAPTURE.
From results, keep only messages where:
  - The mention is of the user's specific @handle (not @here or @channel)
  - This is not a DM already captured in Step 3

Step 5 — Deduplicate.
Merge the two lists. Remove any item whose permalink already appears in ~/.thinkos/capture-log.jsonl with source == "slack".
Cap at 50 total items. If the raw list exceeded 50, note this in the output.

Step 6 — Privacy check.
For each message, scan the message text for (case-insensitive):
  comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, personal, confidential, private, off the record
Set REDACT = true if any keyword matches.

Step 7 — Build or append to the daily file.
Path: 01 Now/Signals/slack-<YYYY-MM-DD>.md

If the file does not exist, create it with:
  ---
  source: slack
  date: <YYYY-MM-DD>
  ---
  # Slack — <YYYY-MM-DD>

Append a time-stamped section for this run:
  ## <HH:MM UTC> run — <N> item(s)

  For each message (REDACT == false):
  ### <DM | @mention> from <sender display name>
  **Time:** <message timestamp>
  **Context:** <channel name or "DM" or "Group DM">
  **Permalink:** <slack permalink>

  <message text, truncated to 400 characters>

  For each message (REDACT == true):
  ### [message redacted — personal] from <sender display name>
  **Time:** <message timestamp>
  **Permalink:** <slack permalink>

Step 8 — Write via mcp__basic-memory__write_note or mcp__basic-memory__edit_note (append operation) to 01 Now/Signals/slack-<YYYY-MM-DD>.md.
Use edit_note with operation: append if the file already exists.
Use write_note if the file does not exist.

Step 9 — Append one ledger event per message to ~/.thinkos/capture-log.jsonl:
  {
    "ts": "<ISO now>",
    "source": "slack",
    "detail": {
      "permalink": "<slack permalink>",
      "sender_id": "<Slack user id of sender>",
      "type": "dm" or "mention",
      "channel": "<channel name or DM>"
    },
    "output": "01 Now/Signals/slack-<YYYY-MM-DD>.md",
    "mode": "append",
    "bytes": <byte length of this message's section>
  }
  For redacted messages: omit "channel" from detail if it's a private DM, add "redacted": true.

Step 10 — Output one line: "Slack snapshot: <N> item(s) captured for <HH:MM> run (<M> redacted)."
If the item cap was hit: "Slack snapshot: 50+ items in window — capped at 50. Consider checking Slack directly for <YYYY-MM-DD>."
```

## Ledger event shape

```json
{"ts":"2026-05-14T15:00:00Z","source":"slack","detail":{"permalink":"https://think.slack.com/archives/D0123456/p1715698412000400","sender_id":"U0A1B2C3D","type":"mention","channel":"#product-team"},"output":"01 Now/Signals/slack-2026-05-14.md","mode":"append","bytes":389}
```

Privacy-routed variant:

```json
{"ts":"2026-05-14T15:00:00Z","source":"slack","detail":{"permalink":"https://think.slack.com/archives/D0123456/p1715698500000200","sender_id":"U0A1B2C3D","type":"dm"},"output":"01 Now/Signals/slack-2026-05-14.md","mode":"append","bytes":54,"redacted":true}
```

## How to enable

Run `/thinkos-capture-setup slack` — or run `/thinkos-capture-setup` and select Slack when prompted.

The setup command will show you the exact filter that will be applied and ask for explicit confirmation before registering the trigger. You will also be asked for your Slack @-handle (used in the @-mention search query).

**Slack capture is offered last** in the setup sequence (after Granola, Calendar, Linear, ClickUp, and Gmail) because it is the most sensitive source. If you are not confident the filter matches your mental model of what is acceptable to capture, skip it.

Prerequisites:
- Slack MCP (`mcp__claude_ai_Slack__*`) connected and authenticated.
- `slack_search_public_and_private` requires a Slack app token with `search:read` scope. Verify via `claude mcp list`.
- You will need to provide your Slack @-handle during setup so the @-mention query can be precise.

## How to disable

1. Run `/thinkos-automate list` to find `think-os-capture-slack`.
2. Run `/thinkos-automate remove think-os-capture-slack`.
3. Past vault files remain. No further Slack content is captured.

Disabling removes only the scheduled trigger. It does not delete previously written vault files or ledger entries. If you want to purge past Slack captures, delete the relevant `01 Now/Signals/slack-*.md` files manually via Basic Memory.
