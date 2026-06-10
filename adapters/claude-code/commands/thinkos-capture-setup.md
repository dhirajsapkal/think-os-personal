---
description: Enable Think OS continuous-capture sources one at a time (Phase C)
permalink: think-os/adapters/claude-code/commands/thinkos-capture-setup
---

Set up external ingestion sources for Think OS continuous capture. Each source runs as a local launchd job. This command walks through them in the safe→sensitive order, offers each one, and installs the job on confirmation.

If the user passes a specific source name (e.g., `/thinkos-capture-setup granola`), skip directly to that source's offer step. Otherwise, walk through all sources in order.

---

## Before starting

### Step 0 — Preflight checks

Run these silently. Don't paste output to the user. Branch on results.

```bash
# Resolve the Think OS repo path. Every `install-launchd-job.sh` invocation
# below depends on it. The repo lives OUTSIDE the vault — never look inside
# the vault for install scripts.
REPO_ROOT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.thinkos/install-manifest.json')))['repo_path'])" 2>/dev/null)"

# Resolve the vault-backed ledger path and check it exists
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
LEDGER="$VAULT/90 System/Capture Log.md"
test -f "$LEDGER" && echo "ledger_ok" || echo "ledger_missing"

# Check Basic Memory is operational
# (attempt a read; if it fails, surface the error)
```

If `$REPO_ROOT` is empty, the install manifest is missing or stale. Ask the user where they cloned the Think OS export repo before proceeding — every install step below depends on it.

If the ledger is missing:
> The Phase B audit ledger (`90 System/Capture Log.md` in your vault) doesn't exist yet. This file is required before enabling any capture source — it's the deduplication cursor every trigger reads.
>
> I can create it now (it starts empty with a small markdown header). Want me to do that, or stop here?

Use `AskUserQuestion` (load via `ToolSearch select:AskUserQuestion`):
- chips: `["Create it now", "Stop — I'll set up Phase B first"]`

If user picks Stop, exit and direct them to Phase B setup.
If user picks Create: call `mcp__basic-memory__write_note` with `title: "Capture Log"`, `directory: "90 System"`, and a short body explaining "append-only audit ledger; do not edit by hand" followed by an empty events section. The path resolves to `90 System/Capture Log.md` in the active vault.

Show a single framing message to the user (no chip, just text):

> Phase C — continuous capture adds local launchd jobs that pull from your external tools and write to your vault. Each source is opt-in. I'll offer them safest-first. You can enable any, all, or none.
>
> Jobs run when your Mac is awake. If your Mac sleeps through a scheduled time, the job fires on next wake (the lookback windows in each filter prevent data loss from a single missed run).
>
> A note on cost: each job fire that uses `claude -p` consumes Anthropic API tokens. Hourly jobs (Granola, Slack) fire ~168 times per week when the Mac is on; daily jobs fire up to 7 times per week. Token usage per fire is low (mostly MCP calls and one vault write), but it's real spend. Check your Claude plan.

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

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" granola
   ```

3. Confirm to the user:
   > Granola capture enabled. Job `com.thinkos.granola` fires every hour when your Mac is awake.

Move to Source 2.

---

## Source 2 — Calendar

### Offer step

Use `AskUserQuestion`:
- prompt: "Calendar: captures today's events as a daily snapshot at 6am local time. Filter: accepted/tentative events; skips declined events and all-day events with no attendees or description.\n\nEnable Calendar capture? Writes to `01 Now/Signals/calendar-<date>.md`."
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show section "Filter (what's worth capturing)" from `docs/continuous-capture/sources/calendar.md`, re-ask.

**On "Skip"**: move to Source 3.

**On "Enable"**:

1. Verify Google Calendar MCP: `ToolSearch select:mcp__claude_ai_Google_Calendar__list_events`.
   If unavailable: > Google Calendar MCP isn't connected. Skipping Calendar for now.

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" calendar
   ```
   The plist uses local system time — no UTC conversion needed.

3. Confirm: > Calendar capture enabled. Job `com.thinkos.calendar` fires daily at 6am local time when your Mac is awake.

Move to Source 3.

---

## Source 3 — Linear

Only proceed with this path if the direct Linear MCP is available. Check with `ToolSearch` query `"linear issues"`.

### Offer step

Use `AskUserQuestion`:
- prompt: "Linear: captures tickets assigned to you that changed status in the past 24 hours. Filter: assignee = me, status changed, last 25 hours. Vault: `01 Now/Signals/linear-<date>.md`.\n\nEnable Linear capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" section from `docs/continuous-capture/sources/linear.md`, re-ask.

**On "Skip"**: move to Source 4.

**On "Enable"**:

1. Verify the direct Linear MCP is available via `ToolSearch` query `"linear issues"`.
   If unavailable: > Linear MCP isn't connected. Install the Linear plugin and retry. Moving to the Jira path.
   Move to Source 4.

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" linear
   ```

3. Confirm: > Linear capture enabled. Job `com.thinkos.linear` fires daily at 6am local time when your Mac is awake.

Move to Source 4.

---

## Source 4 — Jira / Atlassian

Only proceed with this path if `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` exists. Check with `ToolSearch select:mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql`.

If Source 3 (Linear) was enabled, this source is independent — offer it separately for teams that use Jira alongside or instead of Linear.

### Offer step

Use `AskUserQuestion`:
- prompt: "Jira: captures Jira issues assigned to you that changed status in the past 24 hours. Filter: assignee = currentUser(), status changed, last 25 hours. Vault: `01 Now/Signals/jira-<date>.md`.\n\nEnable Jira capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" section from `docs/continuous-capture/sources/jira.md` if it exists, otherwise summarize: assignee = currentUser(), updatedDate >= -25h, status changed. Re-ask.

**On "Skip"**: move to Source 5.

**On "Enable"**:

1. Verify the Atlassian MCP: `ToolSearch select:mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql`.
   If unavailable: > Atlassian MCP isn't connected. Install the Atlassian plugin and retry. Skipping Jira.
   Move to Source 5.

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" jira
   ```

3. Confirm: > Jira capture enabled. Job `com.thinkos.jira` fires daily at 6am local time when your Mac is awake.

Move to Source 5.

---

## Source 5 — ClickUp

### Offer step

Use `AskUserQuestion`:
- prompt: "ClickUp: captures tasks assigned to you that changed status in the past 24 hours. Filter: assignee = me, status changed, last 25 hours. Vault: `01 Now/Signals/clickup-<date>.md`.\n\nEnable ClickUp capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" section from `docs/continuous-capture/sources/clickup.md`, re-ask.

**On "Skip"**: move to Source 6.

**On "Enable"**:

1. Verify ClickUp MCP: `ToolSearch select:mcp__claude_ai_ClickUp__clickup_filter_tasks`.
   If unavailable: > ClickUp MCP isn't connected. Skipping ClickUp for now.

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" clickup
   ```

3. Confirm: > ClickUp capture enabled. Job `com.thinkos.clickup` fires daily at 6am local time when your Mac is awake.

Move to Source 6.

---

## Source 6 — Gmail

### Offer step

Use `AskUserQuestion`:
- prompt: "Gmail: captures starred threads and threads where you sent the last reply, updated in the past 24 hours. Only subject + sender go in the ledger; thread body goes in the vault file. Excludes newsletters, notifications, and automated senders.\n\nEnable Gmail capture?"
- chips: `["Enable", "Skip", "Show me the filter rules first"]`

**On "Show me the filter rules first"**: show "Filter" and "Privacy routing" sections from `docs/continuous-capture/sources/gmail.md`, re-ask.

**On "Skip"**: move to Source 7.

**On "Enable"**:

1. Verify Gmail MCP: `ToolSearch select:mcp__claude_ai_Gmail__search_threads`.
   If unavailable: > Gmail MCP isn't connected. Skipping Gmail for now.

2. Install the launchd job:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" gmail
   ```

3. Confirm: > Gmail capture enabled. Job `com.thinkos.gmail` fires daily at 6am local time when your Mac is awake.

Move to Source 7.

---

## Source 7 — Slack

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
   - prompt: "What is your Slack @-handle? (e.g., @sam or sam.taylor — without the @ if you prefer) This is used in the @-mention search query."
   - chips: `[]` (free text — no chips)

   Store the handle as SLACK_HANDLE.

2. Verify Slack MCP: `ToolSearch select:mcp__claude_ai_Slack__slack_search_public_and_private`.
   If unavailable: > Slack MCP isn't connected or lacks `search:read` scope. Skipping Slack.

3. Install the launchd job, passing SLACK_HANDLE so the install script can substitute it into the trigger prompt:
   ```bash
   bash "$REPO_ROOT/scripts/install-launchd-job.sh" slack --slack-handle SLACK_HANDLE
   ```

4. Confirm: > Slack capture enabled. Job `com.thinkos.slack` fires every hour when your Mac is awake.

---

## Summary step

After going through all seven sources, show a summary.

Run `launchctl list | grep thinkos` to confirm which jobs are loaded. Show the user:

> **Continuous capture setup complete.**
>
> Installed sources:
> [list each installed source with its job name and schedule in plain English]
>
> Sources skipped: [list]
>
> Jobs run when your Mac is awake. You can re-run `/thinkos-capture-setup <source>` at any time to enable a source you skipped.
> To view installed jobs: `/thinkos-automate list`
> To disable a source: `/thinkos-automate remove <source>`
>
> Your vault will start receiving external signals as jobs fire. Check `01 Now/Signals/` in your vault, or read `90 System/Capture Log.md` to verify captures are landing.

---

## Direct-source invocation (e.g., `/thinkos-capture-setup granola`)

If the user passes a single source name as an argument:
1. Jump directly to that source's offer step (skip all others).
2. Run the preflight check first (ledger exists, Basic Memory operational).
3. After enabling or skipping, exit — do not walk through the remaining sources.

Valid source names: `granola`, `calendar`, `linear`, `jira`, `clickup`, `gmail`, `slack`.

If an unrecognized name is passed, list the valid names and exit.

---

## Error handling

- MCP tool unavailable → tell the user what's missing, offer to skip the source. Never silently fail.
- `install-launchd-job.sh` fails → show the error, offer to retry once, then skip.
- Ledger write fails during a later capture run (this is a runtime error in the job, not here) → the job's own error handling covers it; this command can't pre-validate runtime behavior.
- Don't auto-retry more than once for any single step.
