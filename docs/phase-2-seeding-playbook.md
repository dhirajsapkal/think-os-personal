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

### 1c. File picker

`AskUserQuestion`:
- Header: "Where to start?"
- Question: "Which file should I draft first?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Project Index" | "Recommended. Pulls candidate projects from your folders + tools." |
  | "Current Focus" | "This week's priorities from meetings + tickets." |
  | "Identity" | "Role, working style, tool stack." |
  | "People" | "Frequent collaborators." |
  | "All four in order" | "Draft them sequentially: Project Index → Current Focus → Identity → People." |
  | "Pause for now" | "I'll come back later. (Sets state to `complete`; you can re-run /thinkos-continue anytime.)" |

If "Pause for now": run `bash scripts/thinkos-state.sh set-phase complete`. Stop.

Otherwise proceed to Section 2 with the chosen file (or all four in order).

---

## Section 2 — Per-file seeding flow

The general pattern for every file in this section:

1. **Tell the user which sources you'd like to use**, with one short line per source explaining what you'll read and why.
2. **Per-source consent.** Ask Y/N for each. Default is no — the user has to opt in.
3. **Probe each consented source.** Make the minimum read necessary. Track what you read and the URL/identifier.
4. **Synthesize a draft.** Plain markdown matching the template structure already in the user's vault (read `templates/<file>` from this repo for the format).
5. **Show the draft + citations.** Citations are a separate section at the bottom of the message, mapping each claim to its source.
6. **Iterate.** Ask "good as-is, edit something, or scrap and try different sources?". Apply edits in chat until the user approves.
7. **Commit.** Use `mcp__basic-memory__edit_note` (operation: `replace` for files that have only template content, `append` otherwise — check the file first).
8. **Mark seeded.** `bash scripts/thinkos-state.sh mark-seeded <file-key>`.

The file-key values are: `project_index`, `current_focus`, `identity`, `people`, `decisions`.

If a section's consented sources all turn up empty (e.g. user said yes to Granola but has no recent meetings), tell the user and ask whether to skip this file or fall back to a simpler approach (manual prompt-based seeding from chat conversation).

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
| Argenx | Active | 2026-05-12 | Folder + Linear project + weekly Granola meeting |
| Walwil design system | Active | 2026-05-09 | Folder + Granola recurring (Mon/Wed) |
...

## Watching

| Project | Source | Why on the list |
|---|---|---|
| Skramble | ~/Documents/Think/Skramble | Folder exists but no recent activity |
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

### Argenx (60% of capacity)
- Patient communication redesign: review with Maya Wed (ARGX-142)
- Compliance review delayed → blocker, escalating Friday
- 3 active threads in #argenx-design

### Walwil design system (30%)
- Component library spec freeze targeted EOW (WAL-89)
- ...

## Next week
- ...

## On hold / cooling
- Skramble: paused pending Q3 priorities
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

- Design systems for regulated healthcare clients (Argenx, Walwil)
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

### Maya Chen — Product Designer, Argenx project
- Daily Slack, 1:1 every Tuesday
- Owns patient comms redesign with me
- Prefers Figma walkthroughs over written specs

### ...

## Clients

### Sarah Wells — Argenx, VP Design
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

## Section 3 — Wrap-up

When all consented files are seeded:

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
   > (Decisions.md and Learnings.md: skipped — these populate over time as you make decisions and capture learnings.)
   >
   > Try it out — open a fresh session in your agent and ask:
   > *"Who am I and what am I working on this week?"*
   >
   > You should now get a specific, cited answer.

3. Run the doctor one last time to confirm everything is healthy:
   ```bash
   bash scripts/thinkos-doctor.sh --deep --os-home "$(bash scripts/thinkos-state.sh get vault)"
   ```

4. Suggest the first real workflow command they might try (one of):
   - `/thinkos-morning` — daily brief
   - `/thinkos-plate` — what's on my plate today
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

**MCP call fails repeatedly:**
- Don't loop. Two attempts, then surface the error and ask the user how to proceed.

---

## Reference: state file shape

The state file lives at `~/.thinkos/wizard-state.json`. Read it with `scripts/thinkos-state.sh show`. Don't edit it by hand — use the subcommands (`set`, `set-phase`, `mark-seeded`) so updates stay atomic and timestamped.

