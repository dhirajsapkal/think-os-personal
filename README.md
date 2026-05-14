# Think OS

**Your personal context, available to every agent.**

Think OS gives your agentic tools durable memory of who you are, what you're working on, who you work with, and how you like to work. It's a markdown vault plus a context server (Basic Memory MCP) that any modern agent can query and update.

Early alpha — v0.3.0. Poke at it, break it, [tell me what's confusing](https://github.com/dhirajsapkal/think-os/issues).

> **Tool support roadmap.** v0.3 focuses on **Claude Code**. Cowork and Codex adapters are preserved in this repo (`adapters/claude-cowork/`, `adapters/codex/`) and will light up in future versions. The install flow today only wires up Claude Code; the architecture is designed to extend.

---

## Setup is two steps. Plan ~25 minutes total.

### Step 1 — Install (5 min)

Open a new Claude Code session in any folder. Paste this one line:

```
Install Think OS for me from https://github.com/dhirajsapkal/think-os
```

The agent clones the repo, finds [`adapters/claude-code/INSTALL.md`](adapters/claude-code/INSTALL.md), and follows it: asks you 4 short questions (vault path, Basic Memory, plugin bundle, vault name), runs the install, shows you what landed.

Then **quit Claude Code (Cmd+Q) and reopen it** — MCPs and new slash commands only load on startup. If you installed a plugin bundle, also `/mcp` → authorize each connector.

### Step 2 — Continue setup (~15-30 min) — DO NOT SKIP THIS

After the restart, in a fresh Claude Code session, type:

```
/thinkos-continue
```

This is Phase 2 — **the step that makes Think OS actually useful.** Without it, your vault is empty markdown templates and the agent has nothing personalized to read.

The agent will:
- Offer to import from an existing markdown vault (Obsidian, old Think OS, etc.) if you have one
- Pull and cache data from your consented connectors (Granola, Calendar, Slack, Gmail, Linear/Jira/ClickUp)
- Synthesize drafts of your Identity, Project Index, Current Focus, and People files for review
- Offer to set up scheduled triggers at the end (daily reindex, weekly review, quarterly archive, optional morning brief) — runs on Anthropic's cloud, your machine doesn't need to stay on

You can pause and resume anytime — state is saved.

Standalone: if you skipped automations during Phase 2, you can set them up anytime with `/thinkos-automate`.

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
│   ├── claude-code/            ← v0.3 active — MCP, instructions, slash commands
│   ├── claude-cowork/          ← scaffolding for future version
│   └── codex/                  ← scaffolding for future version
├── docs/
│   ├── multi-vault-architecture.md   ← personal + project + reference vault design
│   ├── phase-2-seeding-playbook.md   ← how Phase 2 drafts HOT-tier from connectors
│   └── agent-setup-playbook.md       ← first-run behavior for agents
└── data/plugin-catalog.yaml    ← plugins/connectors per role bundle
```

## How it's organized

**Three vault types:**

- **Personal hub** (always local, never shared) — your identity, daily work log, current focus, people notes, decisions, learnings.
- **Project vaults** (shared via git) — team activity log, project decisions, specs, learnings. Privacy enforced *structurally*: project vault schemas have no slot for personal content, so personal observations can't accidentally leak into a shared repo.
- **Reference vaults** (read-only imports) — folders of markdown you read from but don't own.

See [`docs/multi-vault-architecture.md`](docs/multi-vault-architecture.md) for the full design.

**Slash commands** (Claude Code, all `thinkos-` prefixed):

| Command | What it does |
|---|---|
| `/thinkos-whoami` | Quick identity + role + current focus |
| `/thinkos-morning` | Daily brief — focus, plate, recent log |
| `/thinkos-plate` | What's on your plate today |
| `/thinkos-log <message>` | Capture a timestamped note to your work log |
| `/thinkos-who <name>` | What you know about a specific person |
| `/thinkos-project <slug>` | Load deep context for a project |
| `/thinkos-decisions [topic]` | Search your standing decisions |
| `/thinkos-learnings [topic]` | Search reusable learnings |
| `/thinkos-decide / -capture` | Record a decision / cross-project learning |
| `/thinkos-vault` | Manage vaults — list, switch, create-project, clone |
| `/thinkos-continue` | Resume setup after restart (Phase 2 context seeding) |
| `/thinkos-automate` | Set up scheduled triggers (Phase 3 automations) |
| `/thinkos-help` | Show all commands |
| `/thinkos-mcp-help` | How to query your context MCP |

## The three rules (the architecture in one screen)

1. **Files are the source of truth.** Tool memory and indexes are caches.
2. **HOT tier stays small** (~280 lines of always-loaded context). Detail lives in WARM tier, loaded on demand.
3. **Default write targets are explicit.** Memory → personal hub. Project work → that project's vault. Never write to your `~/Documents/` root.

## Staying current

Think OS evolves. To pull the latest curated rules and skill-routing hints:

```bash
cd ~/code/think-os
bash scripts/thinkos-update.sh --pull
```

This refreshes the BEGIN/END THINK OS block in `~/.claude/CLAUDE.md` without touching your vault, your bundles, or your registered MCPs. Safe to run anytime.

## Product support

| Product | v0.3 status | Notes |
|---|---|---|
| Claude Code CLI | ✓ Active | Full install flow; primary supported target |
| Claude Cowork | Scaffolding | Adapter files preserved; install integration coming in v0.4 |
| Codex | Scaffolding | Adapter files preserved; install integration coming in v0.5 |

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
