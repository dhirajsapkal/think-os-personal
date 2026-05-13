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
├── templates/                   ← copy this folder into your live vault
│   ├── 00 Home.md              ← Obsidian front door
│   ├── 01 Now/                 ← current week, inbox, work log
│   ├── 02 Projects/            ← Project Index + one note per project
│   ├── 03 People/              ← lightweight personal CRM
│   ├── 04 Knowledge/           ← decisions + reusable learnings
│   ├── 05 Profile/             ← identity, voice, business context
│   ├── 90 System/              ← agent instructions + connector inventory
│   └── 99 Archive/             ← rotated logs and dormant notes
├── docs/
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

1. **Pick a home for your live OS files.** Recommended local-only path: `~/ThinkOS/vault/` (or wherever you want). Throughout the docs this is called `{{OS_HOME}}`.
2. **Copy `templates/` into `{{OS_HOME}}`.** That's your starting OS.
3. **Open `00 Home.md` in Obsidian and fill in the HOT tier first.** `05 Profile/Identity.md`, `01 Now/Current Focus.md`, `02 Projects/Project Index.md`, and `90 System/OS Instructions.md`. Skip placeholders you're not sure about — you can add later.
4. **Follow `docs/setup-basic-memory.md`** (15 min). Installs the MCP server that exposes your OS to MCP-aware tools.
5. **Choose your product adapter.** Start with one of:
   - `adapters/claude-cowork/` for Claude Cowork
   - `adapters/claude-code/` for Claude Code CLI
   - `adapters/codex/` for OpenAI Codex
6. **Optionally follow `docs/setup-global-integration.md`** for scheduled maintenance and broader integration patterns.
7. **Verify.** Open a new agent session anywhere on your machine. Ask "who am I and what am I working on?" You should get a specific answer.

Total time to "it works": about an hour, most of which is filling in your identity / projects, not technical setup.

## Vault structure

Think OS is now organized around the way someone naturally opens a knowledge vault:

- `00 Home.md` is the front door.
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

## What you won't get (out of scope for early alpha)

- **Mobile / web reach to your OS.** Basic Memory is local-stdio by default. To call it from mobile or web-only tools you need a remote MCP, HTTPS+OAuth, or a tool-native connector. Defer this unless mobile is a daily pain.
- **Cross-machine sync by default.** Files live on local disk. If you want multiple machines, choose an explicit sync strategy such as Git, Syncthing, Obsidian Sync, or managed company storage; each machine runs its own Basic Memory index.
- **Auto-detect every project.** The early alpha maintains `02 Projects/Project Index.md` by hand, with capture-on-mention assist. A future `/index-projects` command can auto-scan local project folders.
- **A magic AI assistant.** This is structure + cadence. The OS doesn't make the model smarter; it makes the agent *consistent*.

## Maintenance budget

- **Daily** (free): the Stop hook auto-logs your sessions to `01 Now/Work Log.md`. You do nothing.
- **Weekly** (~5 min): `/weekly-review` rolls over `01 Now/Current Focus.md`. Run it manually or schedule in desktop agent.
- **Quarterly** (~30 min): `/quarterly-review` archives the Work Log, audits projects, prunes connectors. Hand-curate.
- **Annually** (~60 min): hand-review `05 Profile/Identity.md` and `05 Profile/Business Brain.md`. Slow-changing things benefit from deliberate review.

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
