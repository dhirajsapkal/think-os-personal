---
description: Enable Think OS continuous-capture sources one at a time (Phase C)
permalink: think-os/adapters/claude-code/commands/thinkos-capture-setup
---

Set up external ingestion sources for Think OS continuous capture. Each source runs as a scheduled remote trigger. This command walks through them in the safe→sensitive order, offers each one, and registers the trigger on confirmation.

If the user passes a specific source name (e.g., `/thinkos-capture-setup granola`), skip directly to that source's offer step. Otherwise, walk through all sources in order.

---

## Before starting

### Step 0 — Preflight checks

Run these silently. Don't paste output to the user. Branch on results.

```bash
# Check audit ledger exists
test -f ~/.thinkos/capture-log.jsonl && echo "ledger_ok" || echo "ledger_missing"

# Check Basic Memory is operational
# (attempt a read; if it fails, surface the error)
```

If the ledger is missing:
> The Phase B audit ledger (`~/.thinkos/capture-log.jsonl`) doesn't exist yet. This file is required before enabling any capture source — it's the deduplication cursor every trigger reads.
>
> I can create it now (it starts empty). Want me to do that, or stop here?

Use `AskUserQuestion` (load via `ToolSearch select:AskUserQuestion`):
- chips: `["Create it now", "Stop — I'll set up Phase B first"]`

If user picks Stop, exit and direct them to Phase B setup.
If user picks Create: run `touch ~/.thinkos/capture-log.jsonl` via Bash.

Show a single framing message to the user (no chip, just text):

> Phase C — continuous capture adds scheduled triggers that pull from your external tools and write to your vault. Each source is opt-in. I'll offer them safest-first. You can enable any, all, or none.
>
> A note on cost: each trigger fire uses Anthropic API tokens (same as Phase 3 automations). Hourly triggers (Granola, Slack) fire ~168 times per week; daily triggers fire 7 times per week. Token usage per fire is low (mostly MCP calls and one vault write), but it's real spend. Check your Claude plan's scheduled-trigger policy.

---

## Source 1 — Granola

### Offer step

Use `AskUserQuestion`:
- prompt: "Granola: captures new meeting transcripts hourly as they're processed. Filter: any transcript with a non-empty body, deduplicated against prior captures. Vault destination: `04 Knowledge/Meetings/<date>-<slug>.md`.\n\nEnable Granola capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**:
Read `docs/continuous-capture/sources/granola.md` section "Filter (what's worth capturing)" and show it verbatim. Then re-ask with the same chip picker.

**On "Skip"**: move to Source 2.

**On "Enable"**:

1. Verify the Granola MCP is available:
   Use `ToolSearch select:mcp__claude_ai_Granola__list_meetings` to check. If unavailable, tell the user:
   > The Granola MCP isn't connected. Install it via the Granola plugin in Claude.ai settings and re-auth. Skipping Granola for now.
   Move to Source 2.

2. Register the trigger. Load `CronCreate` via `ToolSearch select:CronCreate`. Call it with:
   - `name`: `think-os-capture-granola`
   - `schedule`: `0 * * * *`
   - `prompt`: the full "Trigger prompt" block from `docs/continuous-capture/sources/granola.md` (read that file now and extract it verbatim)

3. Confirm to the user:
   > Granola capture enabled. Trigger `think-os-capture-granola` fires every hour. First fire: within the next 60 minutes.

Move to Source 2.

---

## Source 2 — Calendar

### Timezone prompt (required before schedule registration)

Use `AskUserQuestion`:
- prompt: "Calendar: captures today's events as a daily snapshot at 6am local time. Filter: accepted/tentative events; skips declined events and all-day events with no attendees or description.\n\nWhat timezone are you in? I need this to set the correct UTC cron expression for your 6am."
- chips: `["US Eastern (UTC-5/4)", "US Pacific (UTC-8/7)", "US Central (UTC-6/5)", "US Mountain (UTC-7/6)", "Enter my UTC offset manually"]`

Map chip answers to UTC expressions for `0 6 * * *` local:
- US Eastern: `0 11 * * *` (EDT) / `0 12 * * *` (EST) — use `0 11 * * *` as default (daylight time most of the year)
- US Pacific: `0 14 * * *`
- US Central: `0 12 * * *`
- US Mountain: `0 13 * * *`
- "Enter manually": ask a follow-up text question for their UTC offset (e.g., "-5", "+5:30"), compute accordingly.

### Offer step

Use `AskUserQuestion`:
- prompt: "Enable Calendar capture? Fires daily at 6am your time. Writes to `01 Now/Signals/calendar-<date>.md`."
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show section "Filter (what's worth capturing)" from `docs/continuous-capture/sources/calendar.md`, re-ask.

**On "Skip"**: move to Source 3.

**On "Enable"**:

1. Verify Google Calendar MCP: `ToolSearch select:mcp__claude_ai_Google_Calendar__list_events`.
   If unavailable: > Google Calendar MCP isn't connected. Skipping Calendar for now.

2. Register trigger with:
   - `name`: `think-os-capture-calendar`
   - `schedule`: the UTC cron computed above
   - `prompt`: full "Trigger prompt" block from `docs/continuous-capture/sources/calendar.md`

3. Confirm: > Calendar capture enabled. Trigger `think-os-capture-calendar` fires daily at 6am your time.

Move to Source 3.

---

## Source 3 — Linear

### Offer step

Use `AskUserQuestion`:
- prompt: "Linear: captures tickets assigned to you that changed status in the past 24 hours. Filter: assignee = me, status changed, last 25 hours. Vault: `01 Now/Signals/linear-<date>.md`.\n\nEnable Linear capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" section from `docs/continuous-capture/sources/linear.md`, re-ask.

**On "Skip"**: move to Source 4.

**On "Enable"**:

1. Detect which Linear MCP path is available:
   - Try `ToolSearch select:mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` — if found, Atlassian path is available.
   - Also try any direct Linear MCP (search for "linear" in `ToolSearch` query: "linear issues").
   - Tell the user which path will be used: > Using the Atlassian MCP (JQL path) for Linear. OR > Using the direct Linear MCP.
   - If neither is available: > No Linear MCP found. Install the Atlassian or Linear plugin and retry.

2. Register trigger:
   - `name`: `think-os-capture-linear`
   - `schedule`: same UTC cron as Calendar (if timezone already captured) or `0 11 * * *` as default
   - `prompt`: full trigger prompt from `docs/continuous-capture/sources/linear.md`

3. Confirm: > Linear capture enabled. Trigger `think-os-capture-linear` fires daily at 6am.

Move to Source 4.

---

## Source 4 — ClickUp

### Offer step

Use `AskUserQuestion`:
- prompt: "ClickUp: captures tasks assigned to you that changed status in the past 24 hours. Filter: assignee = me, status changed, last 25 hours. Vault: `01 Now/Signals/clickup-<date>.md`.\n\nEnable ClickUp capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" section from `docs/continuous-capture/sources/clickup.md`, re-ask.

**On "Skip"**: move to Source 5.

**On "Enable"**:

1. Verify ClickUp MCP: `ToolSearch select:mcp__claude_ai_ClickUp__clickup_filter_tasks`.
   If unavailable: > ClickUp MCP isn't connected. Skipping ClickUp for now.

2. Register trigger:
   - `name`: `think-os-capture-clickup`
   - `schedule`: same 6am UTC cron
   - `prompt`: full trigger prompt from `docs/continuous-capture/sources/clickup.md`

3. Confirm: > ClickUp capture enabled. Trigger `think-os-capture-clickup` fires daily at 6am.

Move to Source 5.

---

## Source 5 — Gmail

### Offer step

Use `AskUserQuestion`:
- prompt: "Gmail: captures starred threads and threads where you sent the last reply, updated in the past 24 hours. Only subject + sender go in the ledger; thread body goes in the vault file. Excludes newsletters, notifications, and automated senders.\n\nEnable Gmail capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" and "Privacy routing" sections from `docs/continuous-capture/sources/gmail.md`, re-ask.

**On "Skip"**: move to Source 6.

**On "Enable"**:

1. Verify Gmail MCP: `ToolSearch select:mcp__claude_ai_Gmail__search_threads`.
   If unavailable: > Gmail MCP isn't connected. Skipping Gmail for now.

2. Register trigger:
   - `name`: `think-os-capture-gmail`
   - `schedule`: same 6am UTC cron
   - `prompt`: full trigger prompt from `docs/continuous-capture/sources/gmail.md`

3. Confirm: > Gmail capture enabled. Trigger `think-os-capture-gmail` fires daily at 6am.

Move to Source 6.

---

## Source 6 — Slack

### Privacy framing (mandatory — do not skip)

Before offering the chip, show this text to the user (not via AskUserQuestion — plain text, no chips):

> **Slack capture — privacy review required before enabling.**
>
> This source captures: (1) DMs sent to you, and (2) messages that @-mention you by name. It does NOT capture public channel messages unless you are directly mentioned. It does NOT capture messages you sent.
>
> The filter excludes @here, @channel, bots, and Slackbot. Only your specific @handle triggers a mention capture.
>
> Full message body goes to your personal vault file (`01 Now/Signals/slack-<date>.md`). The audit ledger stores only the Slack permalink and sender ID — never the message content.
>
> If a DM or mention contains sensitive keywords (comp, salary, HR, health, family, personal, confidential, off the record), that specific message is redacted in the vault file — you see `[message redacted — personal]` with the timestamp and sender, but not the body.

Then use `AskUserQuestion`:
- prompt: "Enable Slack capture? This is the most privacy-sensitive source. Review the filter above before deciding."
- chips: `["Enable — the filter looks right", "Skip for now", "Show me the full filter rules"]`

**On "Show me the full filter rules"**: show the complete "Filter", "Privacy routing", and "PRIVACY FILTER — READ THIS BEFORE ENABLING" sections from `docs/continuous-capture/sources/slack.md`, re-ask.

**On "Skip for now"**: move to Summary step.

**On "Enable — the filter looks right"**:

1. Ask for Slack @-handle:
   Use `AskUserQuestion`:
   - prompt: "What is your Slack @-handle? (e.g., @dhiraj or dhiraj.sapkal — without the @ if you prefer) This is used in the @-mention search query."
   - chips: `[]` (free text — no chips)

   Store the handle as SLACK_HANDLE.

2. Verify Slack MCP: `ToolSearch select:mcp__claude_ai_Slack__slack_search_public_and_private`.
   If unavailable: > Slack MCP isn't connected or lacks `search:read` scope. Skipping Slack.

3. Register trigger — substitute SLACK_HANDLE into the trigger prompt's Step 4 query:
   - `name`: `think-os-capture-slack`
   - `schedule`: `0 * * * *`
   - `prompt`: full trigger prompt from `docs/continuous-capture/sources/slack.md`, with `<your Slack username>` replaced by SLACK_HANDLE

4. Confirm: > Slack capture enabled. Trigger `think-os-capture-slack` fires every hour. First fire: within 60 minutes.

---

## Summary step

After going through all six sources, show a summary.

Load `CronList` via `ToolSearch select:CronList` and list the active `think-os-capture-*` triggers to confirm what was registered.

Show the user:

> **Continuous capture setup complete.**
>
> Enabled sources:
> [list each enabled source with its trigger name and schedule in plain English]
>
> Sources skipped: [list]
>
> You can re-run `/thinkos-capture-setup <source>` at any time to enable a source you skipped.
> To view active triggers: `/thinkos-automate list`
> To disable a source: `/thinkos-automate remove think-os-capture-<source>`
>
> Your vault will start receiving external signals as triggers fire. Check `01 Now/Signals/` in your vault, or read `~/.thinkos/capture-log.jsonl` to verify captures are landing.

---

## Direct-source invocation (e.g., `/thinkos-capture-setup granola`)

If the user passes a single source name as an argument:
1. Jump directly to that source's offer step (skip all others).
2. Run the preflight check first (ledger exists, Basic Memory operational).
3. After enabling or skipping, exit — do not walk through the remaining sources.

Valid source names: `granola`, `calendar`, `linear`, `clickup`, `gmail`, `slack`.

If an unrecognized name is passed, list the valid names and exit.

---

## Error handling

- MCP tool unavailable → tell the user what's missing, offer to skip the source. Never silently fail.
- CronCreate fails → show the error, offer to retry once, then skip.
- Ledger write fails during a later capture run (this is a runtime error in the trigger, not here) → the trigger's own error handling covers it; this command can't pre-validate runtime behavior.
- Don't auto-retry more than once for any single step.
