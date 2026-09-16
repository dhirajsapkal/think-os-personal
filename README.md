# Think OS

**Your personal context, available to every agent.**

Think OS gives your agentic tools durable memory of who you are, what you're working on, who you work with, and how you like to work. It's a markdown vault plus a context server (Basic Memory MCP) that any modern agent can query and update.

Alpha — **v0.9.11**. See [CHANGELOG.md](CHANGELOG.md).

---

## Install

Open a new Claude Code session in any folder and paste:

```
Install Think OS for me from https://github.com/dhirajsapkal/think-os-personal
```

The agent clones the repo, follows [`adapters/claude-code/INSTALL.md`](adapters/claude-code/INSTALL.md), asks four short questions (vault path, Basic Memory, plugin bundle, vault name), installs, and shows you what landed. **~5 minutes.**

Then **quit Claude Code (Cmd+Q) and reopen it** — MCPs and slash commands only load on startup. If you installed a plugin bundle, type `/mcp` and authorize each connector.

Prefer a terminal?

```bash
git clone https://github.com/dhirajsapkal/think-os-personal.git ~/code/think-os
cd ~/code/think-os
bash scripts/thinkos-setup.sh --os-home "$HOME/ThinkOS/vault" --install-basic-memory --yes
bash scripts/thinkos-doctor.sh --deep
```

### Filling in your context

**Default — emergent seeding.** Start using it immediately. The agent drafts your HOT files (Identity, Project Index, Current Focus, People) turn by turn from normal conversation, with per-fact approval. Context accumulates over the first few sessions. See [`docs/emergent-seeding.md`](docs/emergent-seeding.md).

**Optional — bulk seed.** If you already have rich connector data and want it front-loaded in one sitting, run `/thinkos-continue` (~15–30 min). It imports from an existing markdown vault if you have one, pulls from consented connectors, and drafts your core files for review. Pause and resume anytime.

---

## What problem this solves

- Every new agent session, you re-explain who you are and what you're working on
- Context is scattered across Notion, Drive and Slack threads — none of it indexed for your agent
- You make the same decision twice because there's no record of the first
- "What did I work on last week?" is a question your tools can't answer
- Your AI drafts sound like generic AI, never like you

The bet: **plain markdown files on disk are the source of truth, and every agent reads them through a context MCP server.** Tool memory becomes a derivative; the files are canonical.

---

## Commands

**Every day**

| Command | What it does |
|---|---|
| `/thinkos-refresh` | **The one refresh.** Sweeps every source, updates Tasks (closing what's done), reindexes, reconciles projects, proposes Current Focus, validates |
| `/thinkos-morning` | Daily brief — focus, plate, recent log, calendar |
| `/thinkos-plate` | What's on your plate today |
| `/thinkos-whoami` | Quick identity + role + current focus |
| `/thinkos-who <name>` | What you know about a specific person |
| `/thinkos-project <slug>` | Load deep context for a project |
| `/recent-log` | What you did over the last N days, from the work log |

**Capture and recall**

| Command | What it does |
|---|---|
| `/thinkos-capture <text>` | Canonical capture — infers decision / learning / log / session-recap |
| `/thinkos-decisions [topic]` | Search your standing decisions |
| `/thinkos-learnings [topic]` | Search reusable learnings |
| `/thinkos-voice <text>` | Log a before/after rewrite sample to sharpen your voice profile |
| `/thinkos-recent` | What was captured in the last 24h, and where it landed |
| `/thinkos-promote` | Review staged session checkpoints and file what's worth keeping |
| `/thinkos-undo-capture` | Remove a capture from the vault and ledger |

**Work**

| Command | What it does |
|---|---|
| `/thinkos-timesheet` | Pre-fill a Harvest week from your team's capacity plan. Never auto-submits |
| `/thinkos-loose-ends` | Commitments you made in meetings that never became a ticket |
| `/thinkos-figma-triage` | A file's Figma comments grouped by frame in reading order, not timestamp |
| `/draft-reply` | Draft a reply to an email, Slack message or comment. Always a draft — never sends |

**Review**

| Command | What it does |
|---|---|
| `/weekly-review` | Weekly digest — refresh Current Focus, surface drift |
| `/quarterly-review` | Quarterly maintenance — archive rotation, prune stale, audit HOT files |
| `/thinkos-vitals` | Vault health — staleness, budgets, broken links, ledger volume |

**Setup and maintenance**

| Command | What it does |
|---|---|
| `/thinkos-setup` · `/thinkos-continue` | First-time setup · resume onboarding after restart |
| `/thinkos-doctor` | Install health — including whether your scheduled jobs are actually running |
| `/thinkos-update` | Re-apply the latest instructions, commands and skills. Never touches your vault |
| `/thinkos-vault` · `/thinkos-sync` | Manage vaults · commit + rebase + push your vault |
| `/thinkos-autosave` · `/thinkos-capture-setup` · `/thinkos-automate` | Background session capture · per-source ingestion · scheduled jobs |
| `/thinkos-shared on\|off` | Shared-mode — hides `tier: sensitive` notes while screen-sharing |
| `/thinkos-help` · `/thinkos-mcp-help` | All commands · how to query the context MCP |

### Skills

Loaded automatically when relevant, not invoked by name.

| Skill | What it does |
|---|---|
| `thinkos-deck` | Builds or improves Google Slides decks from vault content, in your voice. Backs up before every write |
| `thinkos-bridge` | How claude.ai connectors surface as deferred tools — check before declaring a connector unavailable |
| `thinkos-emergent-seeding` | Save-flow for promoting drafted facts into stub HOT files |
| `thinkos-shared-mode` | Full shared-mode behaviour beyond the resident redaction core |

---

## How it's organized

**Three vault types**

- **Personal hub** — local, never shared. Identity, current focus, people, decisions, learnings.
- **Project vaults** — shared via git. Privacy is enforced *structurally*: a project schema has no slot for personal content, so it can't leak into a shared repo.
- **Reference vaults** — read-only markdown you read from but don't own.

Full design: [`docs/multi-vault-architecture.md`](docs/multi-vault-architecture.md).

**The vault**

```
00 Home · 01 Now · 02 Projects · 03 People
04 Knowledge · 05 Profile · 90 System · 99 Archive
```

**The repo**

```
think-os/
├── scripts/            setup, doctor, update, vault, cron runner, timesheet, session activity
│   ├── cron-prompts/   playbooks for each scheduled job
│   └── lib/            shared helpers, incl. the Composio bridge
├── templates/          vault skeleton + curated always-on agent instructions
├── adapters/
│   └── claude-code/    commands, skills, install playbook
├── docs/               architecture, playbooks, continuous-capture design
└── data/               plugin catalog per role bundle
```

---

## Continuous capture

Once set up, Think OS records what you work on without you remembering to log it.

- **Session capture** — a local job scans recent Claude Code sessions and appends what you worked on, with real durations, to your vault. No LLM call, no file contents leave your machine. `/thinkos-autosave`.
- **External ingestion, opt-in per source** — local jobs pull from Granola, Slack DMs and @-mentions, Gmail, Calendar and ClickUp. `/thinkos-capture-setup` offers the safest source first and the most sensitive last.
- **Privacy routing** — a two-tier keyword scan on word boundaries. Tier 1 terms (compensation, medical, transplant, performance review…) redact on a single mention; tier 2 terms (family, doctor, 1:1…) need to be substantive, so one aside in a work conversation doesn't redact the whole note. Terms are judged by *your* domain: `terminal` means a shell or a shipping terminal here, not a diagnosis.
- **Session checkpoints** — at session end, a checkpoint extracts what you *decided, learned and left unfinished* and stages it to `90 System/Session Checkpoints/`. Telemetry says when you worked; this says what happened. **Nothing is filed automatically** — `/thinkos-promote` reviews it, and declining marks an item reviewed rather than deleting it.
- **Audit and undo** — every capture writes one line to `90 System/Capture Log.md`. `/thinkos-recent` shows what landed; `/thinkos-undo-capture` removes it.

Full design: [`docs/continuous-capture/README.md`](docs/continuous-capture/README.md).

### Connectors

Gmail · Slack · Google Calendar · ClickUp · Granola are swept on a schedule. Atlassian is **Confluence-only** (the connector has no Jira read scopes). Notion is **interactive-only** — reachable via `/thinkos-refresh --source notion`, but there's no scheduled job for it.

Anything the first-party MCPs don't cover is reached through the **Composio CLI** rather than another MCP server — `composio search` discovers a tool on demand instead of pushing a whole catalogue into every session's context. Figma comments are the motivating case: the Figma MCP is design read/write only and exposes no comments tool at all. See [`scripts/lib/composio.sh`](scripts/lib/composio.sh).

---

## The three rules

1. **Files are the source of truth.** The index underneath — SQLite FTS5, local vectors, relation graph — is a derived, rebuildable cache. [Why not a database](docs/why-files-not-a-database.md).
2. **Always-loaded context stays small.** Detail lives in files and skills the agent loads on demand.
3. **Write targets are explicit.** Memory → personal hub. Project work → that project's vault. Never the `~/Documents/` root.

---

## Staying current

```
/thinkos-update
```

Re-applies the curated instructions, slash commands and skills from your local checkout, detects drift on anything you edited by hand, and asks before overwriting. **Your vault is never touched.** It does not pull by default — add `--pull` to fetch first:

```bash
cd ~/code/think-os && bash scripts/thinkos-update.sh --pull
```

`/thinkos-doctor` reports install health *and* whether your scheduled jobs are actually running — not just whether their scripts exist on disk. If a job is failing it names the cause.

For multi-machine sync, `/thinkos-sync` commits, rebases and pushes your vault. `bash scripts/install-sync-job.sh` schedules it for 18:00 on weekdays. Merge conflicts always pause to you. See [`docs/cross-machine-sync.md`](docs/cross-machine-sync.md).

**Other adapters.** Cowork and Codex scaffolding lives on the `roadmap/cowork-codex` branch.

---

## Feedback

1. **Where did you get stuck?** Name the step.
2. **What's missing?** A file type, a command, a cadence.
3. **What's noise?** Something you'd never use.
4. **What broke?** Error text or a screenshot.

Open an issue at [github.com/dhirajsapkal/think-os-personal/issues](https://github.com/dhirajsapkal/think-os-personal/issues), or just tell me.

---

*Alpha. Iterate from here.*
