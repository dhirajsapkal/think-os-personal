---
type: agent-playbook
tags:
- setup
- agents
- onboarding
- phase-2
- seeding
permalink: think-os/phase-2-seeding-playbook
---

# Phase 2 Seeding Playbook

This is the canonical agent playbook for Phase 2 of Think OS onboarding — populating the user's HOT-tier markdown files from their connected tools.

Phase 1 installs the infrastructure: vault folder, templates, Basic Memory MCP, Claude Code adapter, the chosen plugin/connector bundle. Phase 1 leaves the markdown files as blank skeletons. Phase 2 is where the user becomes a *user*: their actual identity, projects, focus, and people are drafted from real sources — with citations — and committed to the vault only after explicit approval.

This playbook is invoked from `adapters/claude-code/commands/thinkos-continue.md` (the `/thinkos-continue` slash command).

---

## Operating principles

**1. Privacy first.** Phase 1 explicitly does not read connector data. Phase 2 does — but only with per-source consent. Ask before each new source.

**2. Drafts only.** Never write to the vault without explicit user approval. Show the draft, show the citations, let the user edit, then commit.

**3. Citations are mandatory.** Every fact in a draft must trace back to a specific source (URL, file path, message link, calendar event). The user should be able to ask "where did you get X?" and see the answer.

**4. Skippable at every layer.** The user can skip any source, any file, or the whole phase. The state file tracks what's done and what's not.

**5. State updates are committed.** Use `scripts/thinkos-state.sh` to advance phase and mark files seeded. State is the resumption mechanism.

---

## Section 0a — Indexer-first principle

Phase 2 should **dump deterministic data to disk first, then synthesize**. Scripts handle the cheap stuff (filesystem scans, git logs, README extraction). MCPs are called exactly once per consented source. The agent reads cached JSON during synthesis, not paginated tool responses.

See `docs/automation-roadmap.md` for the full source matrix. Concretely:

1. **Filesystem first.** Ask the user which project root folders to scan (default suggestions: `~/Documents/Think/`, `~/code/`, `~/Projects/` — only suggest paths that exist). Then run:
   ```bash
   bash scripts/thinkos-index.sh <folder1> <folder2> ...
   ```
   This writes `<vault>/.index/projects.json` with per-project metadata (path, slug, tech stack, README first paragraph, last commit date + subject, top 5 git collaborators last 180 days, last modified). Cheap, no MCP, no LLM.

2. **Connectors next.** For each consented MCP source, make ONE call and dump the result to `<vault>/.index/<source>.json`:
   - Granola → `granola-meetings.json` (titles + summaries, last 90 days)
   - Calendar → `calendar-events.json` (recurring next 14 days)
   - Slack → `slack-channels.json` (channel list only, not contents)
   - Gmail → `gmail-signature.txt` (signature from last sent)
   - Linear/Jira/ClickUp → `tickets.json` (assigned + open)

3. **Synthesize from disk.** When drafting each HOT-tier file, read the relevant `.index/*.json` files. Don't re-fetch from MCPs during iteration.

4. **Iterate cheaply.** If the user edits the draft, the agent re-reads cached data — no new MCP calls.

Skip this principle only when a connector is unavailable or the user explicitly asks for live data.

---

## Section 0 — Silent state check

Run `bash scripts/thinkos-state.sh show` **silently** (do NOT paste output to the user). Branch on `phase`:

- `awaiting_oauth_and_restart` → Phase 1 manual steps aren't done. Tell the user briefly: "Looks like you haven't restarted Claude Code yet, or some MCPs aren't authed. Try `/mcp` first, then come back." Stop.
- `ready_for_seeding` → Proceed to Section 1.
- `seeding` → Phase 2 was in progress. Read `files_seeded` silently; in Section 1 mention which files are still pending.
- `complete` → Tell the user "Setup is fully complete. Want to re-seed a specific file?" If yes: `scripts/thinkos-state.sh set files_seeded.<file> false` then `set-phase seeding`.

**Don't run other exploratory shell commands at this stage.** No `ls`, no `pwd`, no `find` against unrelated folders (especially don't try to auto-detect the user's old vault — they'll mention it if they want to import). The user should NOT see shell output before the welcome message.

---

## Section 1 — Welcome (one short message, then connector check, then file picker)

### 1a. Welcome message

Show this single message — nothing else, no status dumps, no Phase 1 recap:

> ## Phase 2 — Context Seeding
>
> I'll draft 4 files from your connected tools: **Project Index**, **Current Focus**, **Identity**, **People**. You see each draft before anything writes to your vault.

### 1b. Check connector auth

Run `claude mcp list` silently. Parse the output for any MCP showing "Needs authentication" (or similar). If ANY are flagged:

`AskUserQuestion`:
- Header: "Some connectors need auth"
- Question: "These tools need authorization before I can read from them: <comma-separated list>. What do you want to do?"
- Options:
  | label | description |
  |---|---|
  | "I'll auth them now" | "I'll pause. Open `/mcp` in this session, authorize each, then come back and tell me to continue." |
  | "Skip un-authed tools" | "Proceed with whatever's already connected. We can't use the un-authed sources." |

If everything is authed, skip this step entirely.

### 1c. Import from existing markdown vault (optional)

Before auto-populating, give the user the chance to import from a pre-existing markdown vault (Obsidian, an older Think OS install, hand-written notes). Anything they import counts as already-seeded — auto-populate only fills the rest.

`AskUserQuestion`:
- Header: "Existing vault?"
- Question: "Do you have an existing markdown vault you'd like to import from first?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Yes, I have one" | "I'll point you to it; you map filenames to slots and copy content over." |
  | "Start fresh" | "Skip import. Auto-populate everything from my tools." |

If "Start fresh": skip to 1d.

If "Yes, I have one":

**1c.i — Source path (free text):** Ask "Path to the existing vault?" Verify it exists with `Read` or `Glob`. Re-ask if not.

**1c.ii — Build mapping:** Walk the source folder with `Glob` for `**/*.md`. For each file (case-insensitive), apply this mapping table:

| Source filename pattern | Destination in new vault | State key (if HOT-tier) |
|---|---|---|
| `identity.md` | `05 Profile/Identity.md` | `identity` |
| `current-focus.md`, `current focus.md` | `01 Now/Current Focus.md` | `current_focus` |
| `active-projects.md`, `project index.md`, `projects.md` | `02 Projects/Project Index.md` | `project_index` |
| `decisions.md` | `04 Knowledge/Decisions.md` | — |
| `learnings.md` | `04 Knowledge/Learnings.md` | — |
| `people.md` | `03 People/People.md` | `people` |
| `work-log.md`, `work log.md` | `01 Now/Work Log.md` | — |
| `business-brain.md`, `business brain.md` | `05 Profile/Business Brain.md` | — |
| `voice-profile.md`, `voice profile.md`, `Voice Profile.md` | `05 Profile/Voice Profile.md` | — |
| `os-instructions.md` | `90 System/OS Instructions.md` | — |
| `tasks.md`, `TASKS.md` | `01 Now/Tasks.md` | — |
| `connectors.md` | `90 System/Connectors.md` | — |
| `active-projects/<slug>.md` | `02 Projects/<slug>.md` | — |
| `archive/<anything>` | `99 Archive/<anything>` (preserve structure) | — |
| Anything else | Flag as unknown — show separately, skip by default |

**1c.iii — Show proposed mapping:** Present the proposed copies in a tight markdown table (source → destination, ~one line each). Group unknowns at the bottom labeled "Skipped (no mapping)."

**1c.iv — Approve:** `AskUserQuestion`:
- Header: "Import plan"
- Question: "Import these files?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Looks good, import" | "Copy them in. I'll skip the unknowns." |
  | "Skip import" | "Don't import; just auto-populate from connectors." |

**1c.v — Copy + mark seeded:** For each mapped file:
- Read the source content.
- Check destination: if it has only template content (matches the file in `templates/`), REPLACE via `mcp__basic-memory__write_note`. If it has user-added content, ASK once whether to overwrite or skip just that file.
- For HOT-tier state keys in the table above, run `bash scripts/thinkos-state.sh mark-seeded <key>` after the file lands.

After import, tell the user in one line: "Imported N files. <list of seeded keys> are seeded."

### 1d. File picker

Read which files are already seeded:

```bash
bash scripts/thinkos-state.sh get files_seeded
```

`AskUserQuestion`:
- Header: "Where to start?"
- Question: "Which file should I draft first?"
- multiSelect: false
- Options (build dynamically — only include un-seeded files as primary options):
  | label | description | when to include |
  |---|---|---|
  | "Project Index" | "Recommended. Pulls candidate projects from your folders + tools." | if `project_index` not seeded |
  | "Current Focus" | "This week's priorities from meetings + tickets." | if `current_focus` not seeded |
  | "Identity" | "Role, working style, tool stack." | if `identity` not seeded |
  | "People" | "Frequent collaborators." | if `people` not seeded |
  | "All remaining, in order" | "Draft un-seeded files sequentially." | if 2+ un-seeded |
  | "Re-seed a completed file" | "Pick one that's already seeded and start over." | if any are seeded |
  | "Pause for now" | "Come back later. Progress is saved." | always |

If everything is already seeded (e.g., after a full import): the picker just offers "Re-seed a completed file" or "Pause." Tell the user up front: "All four HOT-tier files are seeded from the import. Run me anytime to re-seed."

If "Pause for now": `bash scripts/thinkos-state.sh set-phase complete`. Stop.

If "Re-seed a completed file": `AskUserQuestion` again with only the seeded files as options, then mark that one un-seeded and proceed to Section 2.

Otherwise proceed to Section 2 with the chosen file.

---

## Section 2 — Per-file seeding flow (use AskUserQuestion throughout)

For every file in this section, follow this pattern. **All user choices use `AskUserQuestion`** — never free-text "Y/N for each" or "reply with the numbers."

### Step 1 — Source picker (multi-select chips)

For the target file, pick the relevant sources from its per-file recipe (sections 2.1–2.4 below). Filter to only those the user actually has authed and connected. Show a one-line description per source.

`AskUserQuestion`:
- Header: "Which sources?"
- Question: "Which tools should I read from for <File Name>? Check any you want me to use — I'll only touch what you check."
- **multiSelect: true**
- Options: one chip per available source, each with:
  - `label`: source name (e.g., "Granola", "Google Calendar", "Filesystem")
  - `description`: one-line what-and-why (e.g., "Meeting titles only from the last ~60 days. Best signal for active projects.")

Always include a "None — just ask me directly" option as the last chip — lets the user seed the file from conversation if they don't want any connector reads.

If the user picks zero sources AND skips "None": ask once more, then skip the file.

### Step 2 — Pull and cache

For each consented source, make ONE call (MCP or script) and dump to `<vault>/.index/<source>.json`. Show the user a one-line per-source status:

> Pulled 47 meetings from Granola, 12 ClickUp lists, 18 calendar events. Done.

If a source returns empty: say so, move on.

### Step 3 — Synthesize draft

Read the cached `.index/*.json` files. Synthesize a draft matching the template at `templates/<vault file path>`. Show the draft directly in the chat — render the markdown so the user sees what'll land in the vault.

Below the draft, in a fenced code block, show a short citations list: which source backed which claim. Two columns max — don't sprawl.

### Step 4 — Review choice (chip picker)

`AskUserQuestion`:
- Header: "<File Name> draft"
- Question: "How does this look?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Looks good — write it" | "Commit to the vault as-is." |
  | "Edit something" | "Tell me what to change; I'll revise without re-fetching." |
  | "Redo with different sources" | "Back to source picker." |
  | "Skip this file for now" | "Move on; you can re-seed later." |

If "Edit something": free-text follow-up. Revise the draft locally (no re-fetching). Loop back to Step 4 with the revised draft.

If "Redo with different sources": loop to Step 1.

If "Skip this file for now": don't mark seeded; move to Step 6.

### Step 5 — Commit

`mcp__basic-memory__edit_note` (operation: `replace` if the file still has template content, `append` otherwise — check first). Then:

```bash
bash scripts/thinkos-state.sh mark-seeded <file-key>
```

File-key values: `project_index`, `current_focus`, `identity`, `people`.

### Step 6 — Move on or pause (chip picker)

If there are more files to do (e.g. user picked "All four"), `AskUserQuestion`:
- Header: "Next?"
- Question: "<File> is done. What's next?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Continue to <next-file>" | "Draft <next-file> now." |
  | "Pick a different next file" | "I'll let you choose." |
  | "Pause for now" | "I'll come back later. Progress is saved." |

If only one file was picked (not "All four"), just say "Done with <file>. Run `/thinkos-continue` anytime to do another."

When all 4 are seeded: `bash scripts/thinkos-state.sh set-phase complete`. Show a one-line completion message.

### Common edge cases

- **All consented sources return empty** for a file → tell the user, offer to seed from conversation instead (Step 4 with empty draft → user describes; you draft from their description).
- **MCP call fails mid-pull** → surface the error in one line, skip that source, proceed with the rest. Don't retry more than once.
- **User wants to edit a draft heavily** → keep iterating in Step 4 with text-only revisions. Don't re-fetch unless they pick "Redo with different sources."

---

### 2.1 — Project Index

**Target file:** `<vault>/02 Projects/Project Index.md`
**State key:** `project_index`

**Sources, in preferred order:**

| Source | What to read | How |
|---|---|---|
| Filesystem | Subfolders of `~/Documents/Think/`, `~/code/`, `~/Projects/` (whichever exist) | `ls -1 ~/Documents/Think/` etc. |
| Linear | Project list | `mcp__linear__*` list tools, or `mcp__claude_ai_*` equivalents |
| Atlassian Rovo | Jira projects, Confluence spaces | `mcp__claude_ai_Atlassian__getVisibleJiraProjects`, `getConfluenceSpaces` |
| Notion | Top-level pages / databases | `mcp__claude_ai_Notion__notion-search` with empty query |
| Drive | Recently edited folder names | `mcp__claude_ai_Google_Drive__list_recent_files` then dedupe by folder |
| Granola | Recurring meeting *titles* (do NOT read transcripts here) | `mcp__claude_ai_Granola__list_meetings` last 30 days, dedupe by title |

**Synthesis pattern:**

For each candidate project, score on signals (folder exists + Linear + recurring meeting = high confidence active; only folder = candidate, ask user). Classify into Active / Watching / Dormant.

**Draft shape** (match `templates/02 Projects/Project Index.md`):

```markdown
## Active

| Project | Status | Last touched | Notes |
|---|---|---|---|
| Acme Health | Active | 2026-05-12 | Folder + Linear project + weekly Granola meeting |
| Northstar Bio design system | Active | 2026-05-09 | Folder + Granola recurring (Mon/Wed) |
...

## Watching

| Project | Source | Why on the list |
|---|---|---|
| Skunkworks | ~/Documents/Think/Skunkworks | Folder exists but no recent activity |
```

**Citations block at the end of the message (not in the file):**

```
Sources used:
  · Filesystem: ls ~/Documents/Think/ → 12 folders found
  · Granola: list_meetings(30d) → 8 unique recurring titles
  · Notion: search() → 4 project-shaped pages
```

After approval: write file, `mark-seeded project_index`.

---

### 2.2 — Current Focus

**Target file:** `<vault>/01 Now/Current Focus.md`
**State key:** `current_focus`

**Sources, in preferred order:**

| Source | What to read | How |
|---|---|---|
| Granola | Last 14 days of meeting transcripts (titles + summaries, NOT full bodies unless needed) | `mcp__claude_ai_Granola__list_meetings`, then `get_meeting_transcript` selectively |
| Linear | Tickets assigned to the user with status In Progress / Todo | `mcp__linear__*` |
| Jira | Open tickets assigned to user | `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` with `assignee = currentUser() AND statusCategory != Done` |
| Slack | Top active threads in last 7 days (the user's most-replied channels) | `mcp__claude_ai_Slack__slack_read_channel` — but only with explicit consent and only for channels the user names |
| Calendar | Recurring meetings + their attendees in next 7 days | `mcp__claude_ai_Google_Calendar__list_events` |

**Synthesis pattern:**

Cluster meetings + tickets + threads by project (use the Project Index from 2.1 if seeded). For each project with activity, pull out:
- What's actively in flight (concrete artifacts: tickets, threads, meeting decisions)
- Open questions / blockers
- Upcoming deadlines

**Draft shape** (match `templates/01 Now/Current Focus.md`):

```markdown
---
last_reviewed: 2026-05-13
covers_week: 2026-05-12 → 2026-05-18
---

# Current Focus

## This week

### Acme Health (60% of capacity)
- Patient communication redesign: review with Alex Wed (ACME-142)
- Compliance review delayed → blocker, escalating Friday
- 3 active threads in #acme-design

### Northstar Bio design system (30%)
- Component library spec freeze targeted EOW (NBI-89)
- ...

## Next week
- ...

## On hold / cooling
- Skunkworks: paused pending Q3 priorities
```

**Citations block:**

```
Sources used:
  · Granola: 14 meetings in 14d, summarized
  · Linear: 9 open tickets, top 3 surfaced
  · Slack: skipped (user declined)
  · Calendar: 18 events scanned, 5 recurring identified
```

After approval: write file, `mark-seeded current_focus`.

---

### 2.3 — Identity

**Target file:** `<vault>/05 Profile/Identity.md`
**State key:** `identity`

**Sources, in preferred order:**

| Source | What to read | How |
|---|---|---|
| Gmail | Most recent sent email's signature block | `mcp__claude_ai_Gmail__search_threads` with `in:sent` then read the last message's signature |
| Slack | User profile (display name, title, "about", pronouns) | `mcp__claude_ai_Slack__slack_read_user_profile` for the current user |
| Calendar | Event title patterns to infer role focus (e.g. lots of "design review" → designer) | aggregate from `list_events` last 60 days |
| Existing vault | If `Voice Profile.md` or `Business Brain.md` already have content, *read but never duplicate* — Identity is the cross-cutting summary |

**Synthesis pattern:**

Identity is short and dense. Pull out:
- Full name
- Current role + company
- Domains of work (e.g. "product design, design systems, AI tooling")
- Communication style cues (do they prefer terse or expansive replies?)
- Time zone / working hours hints from Calendar

**Draft shape** (match `templates/05 Profile/Identity.md`):

```markdown
# Identity

## Who I am

Dhiraj Sapkal — Principal Designer at Think Company.

## What I work on

- Design systems for regulated healthcare clients (Acme Health, Northstar Bio)
- AI-assisted design tooling and workflows (Cursor experiments, Think OS)
- ...

## How I work

- Terse async; deep work mornings, meetings afternoons
- Markdown-first knowledge management
- Prefers concrete examples over abstract framing
- ...

## How to talk to me

- Lead with the answer, not the preamble
- Show me the tradeoffs explicitly
- ...
```

**Citations block:**

```
Sources used:
  · Gmail signature (last sent 2026-05-12): "Dhiraj Sapkal · Principal Designer · Think Co"
  · Slack profile: title "Principal Designer", pronouns "he/him"
  · Calendar: 60d analysis — 47% design review, 22% client, 18% internal
```

After approval: write file, `mark-seeded identity`.

---

### 2.4 — People

**Target file:** `<vault>/03 People/People.md`
**State key:** `people`

**Sources, in preferred order:**

| Source | What to read | How |
|---|---|---|
| Slack | Top 20 DM partners by message count, last 90 days | `mcp__claude_ai_Slack__slack_search_users` + activity heuristics |
| Calendar | Recurring meeting attendees, last 60 days | aggregate attendees from `list_events`, dedupe, rank by frequency |
| Gmail | Top 20 most-emailed contacts | `mcp__claude_ai_Gmail__search_threads` with various queries to aggregate |
| HubSpot / ZoomInfo | Relationship metadata (role, company) for the above | `mcp__claude_ai_HubSpot__*`, `mcp__claude_ai_ZoomInfo__*` (only with consent) |

**Synthesis pattern:**

Merge the three contact lists, dedupe by email/identity. For each person, pull:
- Name + role + company (from Slack profile, signatures, calendar invites)
- Relationship type (colleague, client, vendor, friend)
- Recent context (latest meeting / thread topic)
- Frequency tag (daily / weekly / occasional)

**Important sizing rule:** keep this list under ~25 people. People.md is HOT tier; large lists rot. If the data has 100 candidates, surface the top 15-20 and explicitly tell the user "I left these 80 out — say which ones you want added."

**Draft shape** (match `templates/03 People/People.md`):

```markdown
# People

## Team (Think Co)

### Alex Park — Product Designer, Acme Health project
- Daily Slack, 1:1 every Tuesday
- Owns patient comms redesign with me
- Prefers Figma walkthroughs over written specs

### ...

## Clients

### Jordan Wells — Acme Health, VP Design
- Weekly review meeting Wed 10am
- ...

## Vendors / external

### ...
```

**Citations block:**

```
Sources used:
  · Slack DMs: top 20 by message count (90d)
  · Calendar: 12 recurring attendees identified
  · Gmail: top 20 contacts cross-checked (overlap with Slack = 14)
  · HubSpot: 4 client roles resolved
```

After approval: write file, `mark-seeded people`.

---

## Section 3 — Offer scheduled triggers (optional)

After all chosen files are seeded but BEFORE marking phase complete, offer to set up scheduled triggers. The user is already in flow — easier to opt in here than to remember to run `/thinkos-automate` later.

`AskUserQuestion`:
- Header: "Scheduled triggers"
- Question: "Want me to set up automations that keep your OS fresh on its own? They run on a cron schedule (no local app needed)."
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Yes, set them up now" | "I'll offer four pre-built triggers (daily reindex, weekly review, quarterly archive, optional morning brief)." |
  | "Skip — I'll do it later" | "You can run `/thinkos-automate` anytime." |

If "Yes, set them up now": follow `docs/phase-3-automations-playbook.md` Steps 2 and 3 (offer each trigger via `AskUserQuestion`, register the chosen ones via `CronCreate`). When done, return here for the final wrap-up below.

If "Skip — I'll do it later": move directly to Section 4.

---

## Section 4 — Final wrap-up

1. Set phase to `complete`:
   ```bash
   bash scripts/thinkos-state.sh set-phase complete
   ```

2. Show a completion summary:

   > Phase 2 complete. Your HOT-tier files are now seeded:
   > - Identity.md ✓
   > - Project Index.md ✓
   > - Current Focus.md ✓
   > - People.md ✓
   > (Decisions.md and Learnings.md populate over time as you capture them.)
   >
   > Try it out — open a fresh session and ask:
   > *"Who am I and what am I working on this week?"*

3. Run the doctor:
   ```bash
   bash scripts/thinkos-doctor.sh --deep --os-home "$(bash scripts/thinkos-state.sh get vault)"
   ```

4. Suggest a first command to try:
   - `/thinkos-morning` — daily brief
   - `/thinkos-plate` — what's on your plate today
   - `/thinkos-whoami` — quick identity dump

---

## Failure modes

**Source not available** (MCP not registered, OAuth not done):
- Tell the user which source is missing and how to fix (e.g. "Slack MCP isn't registered — open `claude`, run `/mcp`, authorize").
- Offer to skip that source and proceed with the others.

**Source returns no data** (empty inbox, no recurring meetings):
- Surface this honestly: "Granola has no meetings in the last 14 days — skipping for Current Focus."
- If all sources for a file return empty, ask the user to manually describe the content in chat. Use that as the draft.

**User wants to back out mid-flow:**
- "OK — I'll save where we are. Run `/thinkos-continue` anytime to come back."
- Make sure state reflects what's actually been seeded (don't mark `seeded` if the file wasn't written).

---

## What comes next

Phase 2 is **Step 3** of the 3-step setup flow. After it completes:

- **Phase 3 automations** (`/thinkos-automate`) — scheduled triggers (daily reindex, weekly review, quarterly archive). Playbook: `docs/phase-3-automations-playbook.md`. Also offered inline at the end of the automations offer above.
- **Continuous capture** (`/thinkos-autosave`, `/thinkos-capture-setup`) — passive session logging and opt-in external ingestion from Granola/Slack/Gmail/etc. Design: `docs/continuous-capture/README.md`.

**MCP call fails repeatedly:**
- Don't loop. Two attempts, then surface the error and ask the user how to proceed.

---

## Reference: state file shape

The state file lives at `~/.thinkos/wizard-state.json`. Read it with `scripts/thinkos-state.sh show`. Don't edit it by hand — use the subcommands (`set`, `set-phase`, `mark-seeded`) so updates stay atomic and timestamped.

