---
type: capture-source
source: gmail
schedule: daily-6am
status: stable
tags:
- continuous-capture
- gmail
- email
- phase-c
permalink: think-os/continuous-capture/sources/gmail
---

# Continuous capture — Gmail

## What this captures

Two categories of high-signal email:

1. **Starred threads** — anything the user has explicitly starred is a signal that it matters. Captures the most recent message in each starred thread that was received or updated in the past 24 hours.
2. **Threads where the user is the last replier** — if the user sent the last message in a thread, that thread is live and waiting for something. Captures threads matching this pattern that had activity in the past 24 hours.

This filter intentionally excludes: newsletters, mailing lists, Cc'd-but-not-engaged threads, automated notifications (Jira, GitHub, Slack digest emails), threads where the user has not replied and has not starred.

What does NOT count: bulk-list threads (more than 20 messages from non-human senders), threads where the user is only on the CC line of all messages, automated notification senders (noreply@*, *@notifications.*, digest emails).

## Filter (what's worth capturing)

**Starred + recent:**
```
is:starred newer_than:1d
```

**User is last sender in thread + recent:**
```
from:me newer_than:1d
```
After fetching, confirm the user's message is the most recent message in the thread (not just a thread they're in where someone else replied after). If another person replied after the user's last message, the thread is no longer "waiting on someone else" and is excluded.

**Exclusion rules applied post-fetch (on each thread):**
- `from:noreply` or `from:no-reply` — skip.
- Subject line matches any of: `Unsubscribe`, `newsletter`, `digest`, `notification`, `alert`, `automated`, `[JIRA]`, `[GitHub]`, `[Linear]` — skip.
- Thread has >20 messages and the majority are from addresses containing `notifications`, `alerts`, `noreply` — skip.
- Thread is in Spam or Trash — skip.

Total result cap: 30 threads per daily run. If more match, capture the 30 most recently active.

## Schedule

- Cron (UTC): `0 11 * * *`
- Translated: "daily at 6am US Eastern (11am UTC)"
- Why this cadence: email is asynchronous by nature; a 24-hour summary at day-start is the right rhythm. Hourly email capture would be noise. The morning brief can reference today's Gmail snapshot if it needs email context.

## Vault destination

`01 Now/Signals/gmail-<YYYY-MM-DD>.md`

Overwrite mode: one file per day, replaced on retry. The file contains all threads captured that day.

## Privacy routing

Gmail content is more likely to carry personal signals than task tools. Apply privacy routing if the **subject or sender** matches:

`comp`, `salary`, `compensation`, `bonus`, `raise`, `offer letter`, `HR`, `performance review`, `PIP`, `health`, `medical`, `family`, `personal`, `confidential`, `private`

When matched:
- Thread entry is replaced with `[thread redacted — personal]` in the vault file.
- The ledger entry omits subject and sender; retains only `thread_id`.
- Ledger event gets `"redacted": true`.
- The vault file itself remains in the active vault (it is a daily summary file, not a sensitive note). Only the specific thread entry is redacted within it.

**Note**: body content is never written to the ledger regardless of sensitivity. The ledger captures only subject and sender as identifiers. Full thread body goes only to the vault file.

## Trigger prompt

Register this verbatim via `CronCreate`:

```
You are the Think OS Gmail capture agent. Run daily.

Step 1 — Determine today's date (YYYY-MM-DD) and the cutoff: now minus 25 hours.

Step 2 — Fetch starred threads with recent activity.
Call mcp__claude_ai_Gmail__search_threads with query: "is:starred newer_than:1d"
Request up to 30 results.

Step 3 — Fetch threads where the user sent the last message.
Call mcp__claude_ai_Gmail__search_threads with query: "from:me newer_than:1d"
Request up to 30 results.

Step 4 — Merge and deduplicate thread lists by thread_id.

Step 5 — Apply exclusion rules. For each thread:
  a. Fetch full thread via mcp__claude_ai_Gmail__get_thread to get the message list.
  b. Exclude if the most recent message is from an address containing: noreply, no-reply, notifications, alerts, automated, digest.
  c. Exclude if the subject contains any of: "Unsubscribe", "newsletter", "digest", "[JIRA]", "[GitHub]", "[Linear]", "notification", "alert".
  d. For "from:me" threads: if the last message in the thread is NOT from the user, exclude this thread (someone already replied; it's no longer waiting).
  e. Exclude if the thread is in SPAM or TRASH label.
  Keep only threads that pass all exclusions.
  Cap at 30 total threads (prioritize most recently active).

Step 6 — Privacy check.
For each remaining thread, scan the subject and sender (From address) for (case-insensitive):
  comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, personal, confidential, private
Set REDACT = true if any keyword matches.

Step 7 — Build the snapshot file.
Path: 01 Now/Signals/gmail-<YYYY-MM-DD>.md

Content:
  ---
  source: gmail
  date: <YYYY-MM-DD>
  thread_count: <N>
  captured_at: <ISO timestamp>
  ---

  # Gmail — <YYYY-MM-DD>

  For each thread (REDACT == false):
  ## <subject>
  **From:** <sender display name> (<sender email>)
  **Last activity:** <date of most recent message>
  **Messages:** <message count in thread>
  **Starred:** <yes|no>
  **Status:** <"waiting on reply" if user sent last message, "starred — unread" or "starred — read" otherwise>
  **Permalink:** https://mail.google.com/mail/u/0/#inbox/<thread_id>

  <Most recent message body, truncated to 500 characters. Include only the most recent message, not the full thread history.>

  For each thread (REDACT == true):
  ## [thread redacted — personal]

  ---
  *<N> thread(s) captured. <M> redacted.*

Step 8 — Write via mcp__basic-memory__write_note to 01 Now/Signals/gmail-<YYYY-MM-DD>.md (overwrite).

Step 9 — Append one ledger event per thread to ~/.thinkos/capture-log.jsonl:
  {
    "ts": "<ISO now>",
    "source": "gmail",
    "detail": {
      "thread_id": "<thread id>",
      "subject": "<subject>",
      "sender": "<sender email>",
      "starred": <true|false>,
      "message_count": <N>
    },
    "output": "01 Now/Signals/gmail-<YYYY-MM-DD>.md",
    "mode": "append",
    "bytes": <byte length of this thread's section>
  }
  For redacted threads: omit "subject" and "sender" from detail, add "redacted": true.

Step 10 — Output one line: "Gmail snapshot written: <N> thread(s) for <YYYY-MM-DD> (<M> redacted)."
```

## Ledger event shape

```json
{"ts":"2026-05-14T11:00:00Z","source":"gmail","detail":{"thread_id":"18f3a2c9b1d","subject":"Re: Contract renewal — Q3","sender":"colleague@example.com","starred":true,"message_count":4},"output":"01 Now/Signals/gmail-2026-05-14.md","mode":"append","bytes":687}
```

Privacy-routed variant:

```json
{"ts":"2026-05-14T11:00:00Z","source":"gmail","detail":{"thread_id":"18f3a2c9b2e"},"output":"01 Now/Signals/gmail-2026-05-14.md","mode":"append","bytes":42,"redacted":true}
```

## How to enable

Run `/thinkos-capture-setup gmail` — or run `/thinkos-capture-setup` and select Gmail when prompted.

Prerequisites:
- Gmail MCP (`mcp__claude_ai_Gmail__*`) connected and authenticated. Run `claude mcp list` to confirm.
- Gmail MCP requires OAuth consent for read access. The `search_threads` and `get_thread` tools need at least `gmail.readonly` scope.

## How to disable

1. Run `/thinkos-automate list` to find `think-os-capture-gmail`.
2. Run `/thinkos-automate remove think-os-capture-gmail`.
3. Past snapshot files remain; future snapshots stop.
