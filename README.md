# Think OS

**Your personal context, available to every agent.**

Think OS gives your agentic tools durable memory of who you are, what you're working on, who you work with, and how you like to work. It's a markdown vault plus a context server (Basic Memory MCP) that any modern agent can query and update.

Early alpha — v0.9.1. Poke at it, break it, [tell me what's confusing](https://github.com/dhirajsapkal/think-os/issues).

---

## Setup is three steps. Plan ~25 minutes total.

### Step 1 — Install (5 min)

Open a new Claude Code session in any folder. Paste this one line:

```
Install Think OS for me from https://github.com/dhirajsapkal/think-os
```

The agent clones the repo, finds [`adapters/claude-code/INSTALL.md`](adapters/claude-code/INSTALL.md), and follows it: asks you 4 short questions (vault path, Basic Memory, plugin bundle, vault name), optionally offers Phase 1.5 capability add-ons (browser capture via Playwright, GitHub CLI auth), runs the install, and shows you what landed.

### Step 2 — Restart + authenticate (2 min)

Quit Claude Code (Cmd+Q) and reopen it. MCPs and new slash commands only load on startup.

If you installed a plugin bundle, type `/mcp` and authorize each connector listed. Without this, the connectors are installed but can't read data.

You can stay in the same fresh session for Step 3.

### Step 3 — Continue setup (opt-in, ~15–30 min)

The default path after install is **emergent seeding** — the agent drafts HOT-tier files (Identity, Project Index, Current Focus, People) turn-by-turn from natural conversation, with explicit per-fact approval. Start using Think OS immediately; context fills in over the first few sessions. See `docs/emergent-seeding.md` for how that works.

If you have rich connector data already (Slack, Notion, Granola, calendar) and prefer to front-load your HOT files in one session, run `/thinkos-continue` — that's Phase 2, the opt-in bulk-seed path:

```
/thinkos-continue
```

The agent will:
- Offer to import from an existing markdown vault (Obsidian, old Think OS, etc.) if you have one
- Pull and cache data from your consented connectors (Granola, Calendar, Slack, Gmail, Linear/Jira/ClickUp)
- Synthesize drafts of your Identity, Project Index, Current Focus, and People files for review
- Walk you through all three capture layers at the end:
  - **Session capture** (Block 1) — local launchd job, every 2h during work hours, no API cost, just metadata
  - **Vault maintenance** (Block 2) — local launchd jobs: daily reindex (no API tokens), weekly review draft, quarterly archive, optional morning brief
  - **Continuous capture sources** (Block 3) — opt-in per source: Calendar (default on), Granola, Linear, ClickUp, Gmail starred, Slack DMs + @-mentions

You can pause and resume anytime — state is saved.

Standalone: each layer is also available after onboarding. Session capture: `/thinkos-autosave on`. Maintenance triggers: `/thinkos-automate`. Capture sources: `/thinkos-capture-setup`.

---

## Alternative: install from a terminal

If you'd rather drive from a terminal instead of pasting a prompt:

```bash
mkdir -p ~/code && cd ~/code
git clone https://github.com/dhirajsapkal/think-os.git
cd think-os
bash scripts/thinkos-setup.sh --install-basic-memory --yes
```

Then continue with Step 2 above from a Claude Code session.

## Uninstall cleanly

```bash
cd ~/code/think-os
bash scripts/thinkos-uninstall.sh --dry-run    # see what would be removed
bash scripts/thinkos-uninstall.sh              # actually undo
```

By default, your vault folder (your actual data) is preserved. Add `--remove-vault` to delete it too. See `bash scripts/thinkos-uninstall.sh --help` for all flags.

---

## What problem this solves

You probably already have some version of this pain:

- Every new agent session, you re-explain who you are, what you do, who you work with
- Context lives scattered across Notion / Drive / Slack threads — none of it indexed for your agent
- You make the same architectural decision twice because there's no record of the first time
- "What did I work on last week?" is a question your tools can't answer
- Your AI drafts always sound like generic AI, never like you

Think OS makes a small, deliberate bet: **plain markdown files on disk are the source of truth, and every agent reads them through a context MCP server.** Tool memory becomes a derivative; the files are canonical.

## What you'll get

- **Continuity** — every new agent session loads who you are without you typing it
- **Cross-project recall** — "what did I learn about X that applies to Y" actually works
- **A capture habit** — when you make a decision or share a learning, the agent offers to log it; six months later, search finds it
- **Self-maintenance** — daily/weekly/quarterly cadences keep the OS fresh without you remembering to

---

## What's inside (the repo)

```
think-os/
├── scripts/                    ← setup, vault, git, doctor, uninstall, update
├── templates/
│   ├── (personal vault)        ← 00 Home, 01 Now, 02 Projects, 03 People, 04 Knowledge,
│   │                              05 Profile, 90 System, 99 Archive
│   ├── instructions/           ← curated always-on agent guidance (loaded into CLAUDE.md)
│   └── team/                   ← project vault skeleton (one-file-per-entry, git-friendly)
├── adapters/
│   └── claude-code/            ← active — MCP, instructions, slash commands
├── docs/
│   ├── multi-vault-architecture.md   ← personal + project + reference vault design
│   ├── phase-2-seeding-playbook.md   ← how Phase 2 drafts your core context files from connectors
│   └── agent-setup-playbook.md       ← first-run behavior for agents
└── data/plugin-catalog.yaml    ← plugins/connectors per role bundle
```

## How it's organized

**Three vault types:**

- **Personal hub** (always local, never shared) — your identity, current focus, people, decisions, learnings, private notes.
- **Project vaults** (shared via git) — team activity log, project decisions, specs, learnings. Privacy enforced *structurally*: project vault schemas have no slot for personal content, so personal observations can't accidentally leak into a shared repo.
- **Reference vaults** (read-only imports) — folders of markdown you read from but don't own.

See [`docs/multi-vault-architecture.md`](docs/multi-vault-architecture.md) for the full design.

**Slash commands** (Claude Code, all `thinkos-` prefixed):

| Command | What it does |
|---|---|
| `/thinkos-whoami` | Quick identity + role + current focus |
| `/thinkos-morning` | Daily brief — focus, plate, recent log |
| `/thinkos-plate` | What's on your plate today |
| `/thinkos-capture <text>` | Canonical capture — type-infers decision / learning / log / session-recap |
| `/thinkos-save` | Soft alias → `/thinkos-capture --mode session-recap` |
| `/thinkos-log <message>` | Soft alias → `/thinkos-capture --mode log` |
| `/thinkos-who <name>` | What you know about a specific person |
| `/thinkos-project <slug>` | Load deep context for a project |
| `/thinkos-decisions [topic]` | Search your standing decisions |
| `/thinkos-learnings [topic]` | Search reusable learnings |
| `/thinkos-decide <decision>` | Soft alias → `/thinkos-capture --mode decision` |
| `/thinkos-stale` | List notes past their freshness window |
| `/thinkos-voice <text>` | Rewrite a draft in your voice profile |
| `/thinkos-recent` | See what was captured in the last 24h (the audit view) |
| `/thinkos-undo-capture` | Remove a recent capture from the vault + ledger |
| `/thinkos-autosave on\|off\|status` | Manage periodic background session capture |
| `/thinkos-capture-setup` | Enable continuous-capture sources (Granola, Slack, Gmail, etc.) |
| `/thinkos-reindex` | Refresh Basic Memory's index after external vault edits |
| `/thinkos-vitals` | Vault-health snapshot — staleness, budgets, broken links, ledger volume |
| `/thinkos-sync` | Commit + pull --rebase + push your personal-hub vault state |
| `/thinkos-shared on\|off` | Toggle shared-mode — hides `tier: sensitive` notes from agent reads |
| `/thinkos-vault` | Manage vaults — list, switch, create-project, clone |
| `/thinkos-setup` | Run the Think OS first-time setup |
| `/thinkos-continue` | Resume setup after restart (Phase 2 — now opt-in bulk-seed) |
| `/thinkos-automate` | Set up scheduled triggers (Phase 3 automations) |
| `/thinkos-update` | Pull latest curated instructions + commands, with drift detection |
| `/thinkos-help` | Show all commands |
| `/thinkos-mcp-help` | How to query your context MCP |

## Continuous capture

Once setup is done, Think OS captures what you work on without you remembering to log it:

- **Session capture** — every 2 hours during work hours, a launchd job scans recent Claude Code sessions and appends a one-line entry of what you worked on (cwd, file count, commit) to your private vault. No LLM call. No file contents leave your machine. Toggle with `/thinkos-autosave`.
- **External ingestion (opt-in per source)** — local launchd jobs pull from Granola meetings, Slack DMs + @-mentions, starred Gmail threads, Calendar, Linear, ClickUp. Jobs run when your Mac is awake. Configure via `/thinkos-capture-setup` — safest source (Granola) offered first, most sensitive (Slack DMs) last. Privacy-routed by keyword (anything matching `comp`, `salary`, `HR`, `health`, `family`, `performance`, `1:1` lands in your personal hub only).
- **Audit & undo** — every capture writes one line to the vault note `90 System/Capture Log.md`. `/thinkos-recent` shows what landed; `/thinkos-undo-capture` removes any entry that shouldn't have been kept.

Full design: [`docs/continuous-capture/README.md`](docs/continuous-capture/README.md).

## The three rules (the architecture in one screen)

1. **Files are the source of truth.** Tool memory and indexes are caches.
2. **Always-loaded context stays small** (~280 lines). Detail lives in files the agent loads on demand.
3. **Default write targets are explicit.** Memory → personal hub. Project work → that project's vault. Never write to your `~/Documents/` root.

## Staying current

Think OS evolves. From any Claude Code session:

```
/thinkos-update
```

This fetches the latest commits, summarizes what changed, detects drift on any managed file you edited locally, asks before overwriting, and atomically re-applies the curated instructions + slash commands. Your vault is never touched.

For multi-machine sync, `/thinkos-sync` commits + pull --rebases + pushes your personal-hub vault on demand. The opt-in `bash scripts/install-sync-job.sh` schedules an automatic 18:00 weekday sync via launchd. Merge conflicts pause to you — never auto-resolved. See [`docs/cross-machine-sync.md`](docs/cross-machine-sync.md).

The flow is fully documented in [`docs/update-protocol.md`](docs/update-protocol.md) — file categories (managed vs state vs your content), drift detection via sha256, backup-and-restore on any update.

For a quick non-interactive refresh from the terminal:

```bash
cd ~/code/think-os
bash scripts/thinkos-update.sh --pull
```

**Other adapters.** Cowork and Codex scaffolding lives on the `roadmap/cowork-codex` branch — cherry-pick when their plugin formats stabilize.

## Feedback I'm looking for

If you're testing the early alpha:

1. **Where did you get stuck?** Specific step.
2. **What's missing for your workflow?** A file type, a command, a cadence I didn't think of.
3. **What's noise?** A file or command you'd never use.
4. **What broke?** Stack trace, error message, or screenshot.
5. **What surprised you?** Positively or negatively.

Open an issue at https://github.com/dhirajsapkal/think-os/issues or DM me wherever's easiest.

---

*Early alpha. Iterate from here.*
