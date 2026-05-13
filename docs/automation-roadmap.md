---
type: design
status: proposed
tags:
- automation
- onboarding
- phase-2
- indexing
permalink: think-os/automation-roadmap
---

# Automation Roadmap

How Think OS pulls real signal from the user's existing world so the HOT-tier files are pre-filled (and confirmed) instead of typed from scratch.

The principle: **scripts handle the deterministic, repetitive, large-corpus stuff. Agents handle the synthesis, judgment, and final draft.** This split keeps token costs low and synthesis quality high.

---

## Source matrix

| Source | Type | Cost | Drives |
|---|---|---|---|
| **Filesystem (project folders)** | Local, deterministic | ~0 tokens | Project Index, Work Log seed |
| **Git logs per project** | Local, deterministic | ~0 tokens | Project Index, People (collaborators) |
| **Package manifests** (package.json, pyproject.toml, Cargo.toml) | Local, deterministic | ~0 tokens | Project Index (tech stack) |
| **READMEs** | Local, deterministic | ~0 tokens | Project Index (descriptions) |
| **Granola** (meeting titles, summaries) | MCP, one call | Low | Project Index, People, Current Focus |
| **Calendar** (recurring events, attendees) | MCP, one call | Low | People, Current Focus |
| **Slack** (channel list, NOT message contents) | MCP, one call | Low | People, Project Index |
| **Gmail** (signature from last sent) | MCP, one call | Very low | Identity |
| **Linear / Jira / ClickUp** (assigned tickets) | MCP, one call | Low | Current Focus |
| **Notion** (top-level page list) | MCP, one call | Low | Project Index |
| **GitHub `gh` CLI** (public repos, recent activity) | Local CLI, deterministic | ~0 tokens | Project Index (code projects) |
| **macOS `mdfind`** (Spotlight: recent docs by author) | Local CLI, deterministic | ~0 tokens | Project Index (recent files) |
| **Business Brain shared template** | Static ship | 0 tokens | Business Brain.md |

**Cost model**: "~0 tokens" means the script writes to disk and the agent reads small text files. "Low" means a single MCP call returns a paginated list that fits in a few KB. "High" means iterating with the LLM per item.

---

## The indexing pattern

For each session of Phase 2:

1. **User picks sources** (folder picker + per-connector consent).
2. **Indexer scripts run** (`scripts/thinkos-index.sh`) and dump deterministic data to `<vault>/.index/`:
   - `projects.json` — folder list with metadata (git presence, manifest type, last commit, README first paragraph)
   - `git-collaborators.json` — co-authors from `git log` per project, last 6 months
   - `recent-files.json` — `mdfind` results: files you've touched recently, grouped by parent folder
3. **Agent makes ONE MCP call per consented connector** and dumps to `.index/`:
   - `granola-meetings.json` — last 90 days of titles + summaries
   - `calendar-events.json` — next 14 days of recurring events
   - `slack-channels.json` — channels the user is in
   - `gmail-signature.txt` — signature from last sent
   - `linear-tickets.json` — open tickets assigned to user
4. **Agent reads the indexed data from disk** (cheap) and synthesizes drafts.
5. **User reviews each draft**, edits in chat, approves.
6. **Agent writes via `mcp__basic-memory__edit_note`** to the canonical files.

Why this works:
- Scripts do what they're good at (file scans, git, regex, JSON).
- MCPs are called exactly once per source — no re-fetching during iteration.
- Agent only does the LLM-needed work: synthesis, framing, voice.
- All indexed data is cached on disk; if the user wants to redo a draft, no re-fetching needed.

---

## What the indexer extracts per source

### Filesystem (`scripts/thinkos-index.sh <folder> [<folder> ...]`)

For each folder passed (default suggestions: `~/Documents/Think/`, `~/code/`, `~/Projects/`), recursively (depth=2) finds candidate projects:

A subfolder is a "project candidate" if any of:
- It contains a `.git/` directory
- It contains a `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or `requirements.txt`
- It contains a `README.md` or `README.mdx`
- It has 5+ markdown files (could be a notes/docs project)

For each candidate, extract:
- Folder path
- Folder name → slug
- Tech stack guess (from manifest filename)
- README first paragraph (if README exists)
- Last `git log` entry: date + message (if .git exists)
- Collaborator list: top 5 `git log --since=180d --pretty=format:'%an'` unique authors
- Mtime of most recently modified non-hidden file

Output: `<vault>/.index/projects.json`

### Granola (via agent + MCP call)

Last 90 days of meetings:
- Title
- Date
- Attendees (count + top 3 names)
- Summary (if available, truncated to 200 chars)

Dedupe by title to identify recurring meetings → these are candidate projects/relationships.

Output: `<vault>/.index/granola-meetings.json`

### Calendar (via agent + MCP call)

Next 14 days of events:
- Title
- Recurring flag
- Attendees
- Description first 200 chars

Recurring events → candidate Current Focus items + People to track.

Output: `<vault>/.index/calendar-events.json`

### Slack (via agent + MCP call, channel list only)

The user's channel memberships, NOT message contents:
- Channel name
- Member count
- Is DM / group DM / public / private

Channels named after clients, projects, or teams → candidate context.

Output: `<vault>/.index/slack-channels.json`

### Gmail (via agent + MCP call)

The signature block from the most recent sent message:
- Plaintext signature
- Linked URLs (LinkedIn, website)

Output: `<vault>/.index/gmail-signature.txt`

### Linear / Jira / ClickUp (via agent + MCP call)

Open tickets assigned to the user:
- Ticket title
- Status
- Project / cycle
- Updated date

Output: `<vault>/.index/tickets.json`

---

## Folder selection UX

In Phase 2, the agent asks the user to pick project folders. Two paths:

**Auto-suggestion path:**
```
I found these candidate project roots on your machine:
  1. ~/Documents/Think/  (12 subfolders)
  2. ~/code/             (8 subfolders)
  3. ~/Projects/         (0 subfolders)

Index all of them? [Y/n/pick]
```

**Manual path** (if user picks "pick" or auto-suggestion finds nothing):
```
Which folders should I scan for projects? Enter one path per line, blank line to finish:
  > ~/Documents/Think/
  > ~/work/clients/
  > [blank]
```

The agent then runs `scripts/thinkos-index.sh <folder1> <folder2> ...` which writes `<vault>/.index/projects.json`.

---

## Ongoing updates (not v0.3)

Once a folder is registered as a Think OS source, ongoing updates happen via:

1. **Periodic re-index**: `scripts/thinkos-index.sh --refresh` (manual, cheap, deterministic).
2. **Capture-on-mention** (already exists): when the user mentions a project name during chat, the agent offers to add it to `Project Index.md`.
3. **Stop-hook auto-log** (deferred): a Claude Code Stop hook writes session summaries to `Work Log.md` with project tags inferred from cwd.

Ongoing connector sync (Granola new meetings, etc.) is handled by `/thinkos-reindex` against Basic Memory plus the existing connector polling cadence.

---

## Source priorities by HOT-tier file

| File | Primary sources | Secondary |
|---|---|---|
| `Identity.md` | Gmail signature, Slack profile, Business Brain default | Calendar invite patterns |
| `Project Index.md` | Filesystem scan, Git logs, Granola recurring titles | Linear/Jira/ClickUp projects, Notion top-level |
| `Current Focus.md` | Linear/Jira/ClickUp tickets, Granola last 14d, Calendar next 14d | Recent file activity (`mdfind`) |
| `People.md` | Granola attendees, Calendar recurring attendees, Slack DM partners, Git co-authors | HubSpot/ZoomInfo if connected |
| `Business Brain.md` | Sanitized Think Co template (shipped) | User edits |
| `Voice Profile.md` | Gmail signature, sent email tone analysis | Slack message style if user opts in |

---

## What's deliberately NOT automated

Some things are intentionally manual because they require human judgment:

- **Decisions.md** — adding to this is a deliberate act. The agent offers to log, the user confirms.
- **Learnings.md** — same.
- **People.md depth notes** — the agent can list candidates, but adding "this person is risk-averse, prefers terse comms" requires the user.
- **Voice Profile.md** — auto-analysis from emails is possible but the resulting voice file is so personal the user should write/edit it themselves. Scripts can surface raw signal; the user phrases the result.
- **Current Focus.md prioritization** — the agent can list tickets / meetings; the user decides what's primary vs deferred.

---

## Implementation status

### Shipped in v0.3
- `templates/05 Profile/Business Brain.md` — sanitized Think Co shared template
- `data/plugin-catalog.yaml` — full connector catalog with OAuth flags
- The MCP-driven Phase 2 playbook (`docs/phase-2-seeding-playbook.md`)

### Shipping next slice (v0.3.1 candidate)
- `scripts/thinkos-index.sh` — filesystem + git + manifest indexer
- Updated Phase 2 playbook: indexer runs first, agent reads `.index/*.json`
- Folder selector UX in `/thinkos-continue`

### Future (v0.4+)
- Periodic re-index command (`/thinkos-reindex --sources`)
- Stop-hook auto-log
- Connector polling for ongoing context refresh
- Cross-vault search hub
- Cowork + Codex install integration

---

## Why the indexer pattern matters

Two structural wins, no benchmark numbers attached (we don't have any yet):

- **MCP calls per source happen exactly once.** With an indexer, each connector is queried, the result cached to disk, and re-read locally during iteration. Without it, every draft refresh tends to re-fetch.
- **Synthesis reads structured JSON, not paginated tool output.** Easier for the LLM to attend to deduped, sorted, schematized input than to a raw tool response.

We can add real measurements once Phase 2 has run on actual installs.
