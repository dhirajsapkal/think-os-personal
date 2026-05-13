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
├── templates/                   ← the canonical OS files (you fill in placeholders)
│   ├── identity.md              ← HOT: who you are, working style, guardrails
│   ├── active-projects.md       ← HOT: index of every project
│   ├── current-focus.md         ← HOT: this week's priorities
│   ├── os-instructions.md       ← HOT: meta-rules for the agent on how to use this
│   ├── business-brain.md        ← WARM: strategy, voice, standing principles
│   ├── decisions.md             ← WARM: long-term standing decisions
│   ├── people.md                ← WARM: personal CRM
│   ├── connectors.md            ← WARM: inventory of MCPs / connectors
│   ├── learnings.md             ← WARM: cross-project reusable patterns
│   ├── voice-profile.md         ← WARM: how you actually write
│   ├── TASKS.md                 ← WARM: connector-synced inbox
│   ├── work-log.md              ← WARM: chronological session log (auto-captured)
│   └── active-projects/_TEMPLATE.md   ← stub for a new project deep file
├── docs/
│   ├── setup-basic-memory.md    ← install Basic Memory MCP + Obsidian
│   └── setup-global-integration.md  ← wire CLI agent + desktop agent + scheduled cadence
└── adapters/claude-code/commands/
    ├── README.md                ← install + usage
    └── *.md                     ← 13 slash commands (/whoami, /plate, /log, etc.)
```

## How to use it

1. **Pick a home for your live OS files.** Recommended local-only path: `~/ThinkOS/vault/` (or wherever you want). Throughout the docs this is called `{{OS_HOME}}`.
2. **Copy `templates/` into `{{OS_HOME}}`.** That's your starting OS.
3. **Fill in the HOT tier first.** `identity.md`, `active-projects.md`, `current-focus.md`. Skip placeholders you're not sure about — you can add later.
4. **Follow `docs/setup-basic-memory.md`** (15 min). Installs the MCP server that exposes your OS to MCP-aware tools.
5. **Follow `docs/setup-global-integration.md`** (20 min). Wires MCP-aware tools and scheduled maintenance.
6. **Install the slash commands.** `cp adapters/claude-code/commands/*.md ~/.claude/commands/`.
7. **Verify.** Open a new desktop agent or CLI agent session anywhere on your machine. Ask "who am I and what am I working on?" You should get a specific answer.

Total time to "it works": about an hour, most of which is filling in your identity / projects, not technical setup.

## The three rules (the architecture in one screen)

1. **Files are the source of truth.** Tool memory, Basic Memory's index, and tool-specific global instruction files are caches over the files.
2. **HOT tier stays small.** Identity, active projects, current focus, OS instructions — together ~280 lines. Pushed any further and the agent starts ignoring half of it. Detail lives in the WARM tier, loaded on demand.
3. **Default write targets are explicit.** Memory / notes → `{{OS_HOME}}`. Project work → that project's subfolder. Never write to your Documents root.

## What you'll get

- **Continuity.** Every new agent session loads who you are without you typing it.
- **Cross-project recall.** "What did I learn about X that applies to Y" actually works.
- **A capture habit.** When you make a decision or share a learning, the agent offers to log it. You confirm. Six months later, search finds it.
- **Self-maintenance.** A daily desktop agent task refreshes your inbox from connectors. Sundays roll over your current-focus. Quarterly archives the work-log. You don't remember to do this; it happens.

## What you won't get (out of scope for early alpha)

- **Mobile / web reach to your OS.** Basic Memory is local-stdio by default. To call it from mobile or web-only tools you need a remote MCP, HTTPS+OAuth, or a tool-native connector. Defer this unless mobile is a daily pain.
- **Cross-machine sync by default.** Files live on local disk. If you want multiple machines, choose an explicit sync strategy such as Git, Syncthing, Obsidian Sync, or managed company storage; each machine runs its own Basic Memory index.
- **Auto-detect every project.** The early alpha maintains `active-projects.md` by hand (with capture-on-mention assist). A `/index-projects` skill that auto-scans is a future iteration.
- **A magic AI assistant.** This is structure + cadence. The OS doesn't make the model smarter; it makes the agent *consistent*.

## Maintenance budget

- **Daily** (free): the Stop hook auto-logs your sessions to `work-log.md`. You do nothing.
- **Weekly** (~5 min): `/weekly-review` rolls over `current-focus.md`. Run it manually or schedule in desktop agent.
- **Quarterly** (~30 min): `/quarterly-review` archives the work-log, audits projects, prunes connectors. Hand-curate.
- **Annually** (~60 min): hand-review `identity.md` and `business-brain.md`. Slow-changing things benefit from deliberate review.

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
