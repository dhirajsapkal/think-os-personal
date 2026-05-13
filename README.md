# Think OS — early alpha

A markdown-first personal context OS that gives an agentic tool durable memory of who you are, what you're working on, and how you like to work — across projects and tools.

This is an early alpha — a testable starter kit. Please poke at it, break it, tell me what's confusing. We'll iterate.

---

## What problem this solves

You probably already have some version of this pain:

- Every new agent session, you re-explain who you are, what you do, who you work with
- Context lives scattered across Notion / Google Drive / Slack threads — none of it indexed for your agent
- You make the same architectural decision twice because there's no record of the first time
- "What did I work on last week?" is a question your tools can't answer
- Your AI drafts always sound like generic AI, never like you

This OS makes a small, deliberate bet: **plain markdown files on disk are the source of truth, and every agentic tool reads them through a context MCP server.** Tool memory becomes a derivative; the files are canonical.

## What's inside

```
export/think-os-alpha/
├── README.md                    ← you are here
├── AGENTS.md                    ← first file agents should read
├── CLAUDE.md                    ← Claude-specific pointer to AGENTS.md
├── scripts/
│   ├── thinkos-doctor.sh        ← compact setup/status checks
│   └── thinkos-setup.sh         ← safe first-run automation
├── templates/                   ← copy this folder into your live vault
│   ├── 00 Home.md              ← Obsidian dashboard + portal
│   ├── 01 Now/                 ← current week, inbox, work log
│   ├── 02 Projects/            ← Project Index + one note per project
│   ├── 03 People/              ← lightweight personal CRM
│   ├── 04 Knowledge/           ← decisions + reusable learnings
│   ├── 05 Profile/             ← identity, voice, business context
│   ├── 90 System/              ← agent instructions + connector inventory
│   └── 99 Archive/             ← rotated logs and dormant notes
├── docs/
│   ├── agent-setup-playbook.md  ← first-run behavior for agents
│   ├── setup-basic-memory.md    ← install Basic Memory MCP + Obsidian
│   ├── setup-global-integration.md  ← wire CLI agent + desktop agent + scheduled cadence
│   └── vault-architecture.md    ← why the Obsidian vault is organized this way
└── adapters/
    ├── README.md                ← product adapter index
    ├── claude-cowork/           ← Claude Cowork MCP + instructions
    ├── claude-code/             ← Claude Code MCP + instructions + slash commands
    └── codex/                   ← Codex MCP + AGENTS.md instructions
```

## How to use it

> **Platform**: The setup scripts are macOS-only for the early alpha. Linux/Windows users can follow [`docs/setup-basic-memory.md`](docs/setup-basic-memory.md) and the adapter README for their tool to set up manually.

1. **Pick a home for your live OS files.** Recommended local-only path: `~/ThinkOS/vault/` (or wherever you want). Throughout the docs this is called `{{OS_HOME}}`.
2. **Copy `templates/` into `{{OS_HOME}}`.** That's your starting OS.
3. **Fill in the HOT tier first.** `05 Profile/Identity.md`, `01 Now/Current Focus.md`, `02 Projects/Project Index.md`, and `90 System/OS Instructions.md`. Use `00 Home.md` as the Obsidian dashboard once the vault exists.
4. **Follow `docs/setup-basic-memory.md`** (15 min). Installs the MCP server that exposes your OS to MCP-aware tools.
5. **Choose your product adapter.** Start with one of:
   - `adapters/claude-cowork/` for Claude Cowork
   - `adapters/claude-code/` for Claude Code CLI
   - `adapters/codex/` for OpenAI Codex
6. **Optionally follow `docs/setup-global-integration.md`** for scheduled maintenance and broader integration patterns.
7. **Verify.** Open a new agent session anywhere on your machine. Ask "who am I and what am I working on?" You should get a specific answer.

Total time to "it works": about an hour by hand, or faster with an agent running the setup scripts. Most of the real work is filling in your identity / projects, not technical setup.

## Agent-Assisted Setup

If you open this repo with an agent, ask:

```text
Help me set up Think OS end to end.
```

Agents should read [`AGENTS.md`](AGENTS.md), then use the setup scripts instead of manually inspecting your machine:

```bash
scripts/thinkos-doctor.sh --json --products claude-code,codex
scripts/thinkos-setup.sh --products claude-code,codex --install-basic-memory --yes
scripts/thinkos-doctor.sh --deep --products claude-code,codex
```

The scripts copy missing templates, register the Basic Memory project, install product instructions, and verify MCP registration where the product CLI supports it. See [`docs/agent-setup-playbook.md`](docs/agent-setup-playbook.md).

## Vault structure

Think OS is now organized around the way someone naturally opens a knowledge vault:

- `00 Home.md` is the dashboard and portal into the vault.
- `01 Now/` is what they check most often.
- `02 Projects/Project Index.md` replaces the old active-projects file/folder split with one clear map plus project notes beside it.
- `90 System/` keeps agent rules out of the daily workspace.

See [`docs/vault-architecture.md`](docs/vault-architecture.md) for the rationale.

## Product support

Think OS core is one vault plus one MCP server. Product support lives in adapters so each tool can keep its own install steps, global instruction format, and verification path.

| Product | Status | Entry point |
|---|---|---|
| Claude Cowork | Early alpha adapter | [`adapters/claude-cowork/README.md`](adapters/claude-cowork/README.md) |
| Claude Code CLI | Early alpha adapter | [`adapters/claude-code/README.md`](adapters/claude-code/README.md) |
| Codex | Early alpha adapter | [`adapters/codex/README.md`](adapters/codex/README.md) |

## The three rules (the architecture in one screen)

1. **Files are the source of truth.** Tool memory, Basic Memory's index, and tool-specific global instruction files are caches over the files.
2. **HOT tier stays small.** Identity, Project Index, Current Focus, OS Instructions — together ~280 lines. Pushed any further and the agent starts ignoring half of it. Detail lives in the WARM tier, loaded on demand.
3. **Default write targets are explicit.** Memory / notes → `{{OS_HOME}}`. Project work → that project's subfolder. Never write to your Documents root.

## What you'll get

- **Continuity.** Every new agent session loads who you are without you typing it.
- **Cross-project recall.** "What did I learn about X that applies to Y" actually works.
- **A capture habit.** When you make a decision or share a learning, the agent offers to log it. You confirm. Six months later, search finds it.
- **Self-maintenance.** A daily desktop agent task refreshes your inbox from connectors. Sundays roll over Current Focus. Quarterly archives the Work Log. You don't remember to do this; it happens.

See [LIMITATIONS.md](LIMITATIONS.md) for what's deliberately out of scope.

Maintenance is light — see [MAINTENANCE.md](MAINTENANCE.md) for cadence and what's automated.

## Feedback I'm looking for

If you're testing the early alpha:

1. **Where did you get stuck?** Specific step in the setup that confused you.
2. **What's missing for your workflow?** A file type, a command, a cadence I didn't think of.
3. **What's noise?** A file or command you'd never use — let me cut it from a later release.
4. **What broke?** Stack trace, error message, or screenshot if you can.
5. **What surprised you?** Positively or negatively.

Drop notes wherever's easiest — Slack DM, a doc, an email. I'll consolidate before a later release.

---

*Early alpha — private preview. Iterate from here.*
