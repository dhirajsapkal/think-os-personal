---
description: Show all Think OS commands and what they do
permalink: think-os/adapters/claude-code/commands/thinkos-help
---

Show the full index of Think OS slash commands grouped by category, plus key script and doc pointers.

---

## Setup & lifecycle

| Command | What it does |
|---|---|
| `/thinkos-setup` | Run the first-time setup wizard from the export repo |
| `/thinkos-continue` | Resume setup after OAuth + app restart (Phase 2) |
| `/thinkos-vault` | Manage vaults — list, switch, create-project, clone |
| `bash scripts/thinkos-wizard.sh` | Interactive guided installer (one question per screen) |
| `bash scripts/thinkos-doctor.sh` | Health-check MCP, vault, and installed products |
| `bash scripts/thinkos-uninstall.sh` | Remove Think OS install artifacts (preserves vault by default) |

---

## Daily workflow

| Command | What it does |
|---|---|
| `/thinkos-morning` | Daily brief — focus, plate, recent log, calendar |
| `/thinkos-plate` | What's on your plate today (tasks + current focus) |
| `/thinkos-whoami` | Quick identity + role + current focus |
| `/thinkos-log <message>` | Capture a timestamped note to your work log |
| `/thinkos-decide <decision>` | Record a standing decision in your vault |
| `/thinkos-capture <learning>` | Capture a cross-project learning into your vault |

---

## Lookup

| Command | What it does |
|---|---|
| `/thinkos-who <name>` | Show what you know about a specific person |
| `/thinkos-decisions [topic]` | Search your standing decisions, optionally by topic |
| `/thinkos-learnings [topic]` | Search reusable learnings by topic or tag |
| `/thinkos-project <slug>` | Load deep context for a project by slug or name |

---

## Maintenance

| Command | What it does |
|---|---|
| `/thinkos-reindex` | Refresh Basic Memory's index after external edits |
| `/thinkos-stale` | List notes past their freshness window |
| `/thinkos-voice <before \| after>` | Rewrite a draft in your voice profile |

---

## Help

| Command | What it does |
|---|---|
| `/thinkos-help` | Show all Think OS commands and what they do |
| `/thinkos-mcp-help` | How to query and update your personal context MCP |

---

## Key paths

- **Vault location**: check `~/.thinkos/vaults.json` — the `path` field of the `"default": true` entry.
- **Think OS rules in your agent**: the `BEGIN THINK OS` / `END THINK OS` block in `~/.claude/CLAUDE.md`. Source lives in `templates/instructions/` in the export repo.
- **Curated instruction files** (edit these, not the installed block directly):
  - `templates/instructions/00-think-os-priority.md`
  - `templates/instructions/10-token-efficiency.md`
  - `templates/instructions/20-skill-routing.md`
  - `templates/instructions/30-think-os-write-targets.md`
- **Docs**:
  - `docs/multi-vault-architecture.md` — personal + project + reference vault design
  - `docs/phase-2-seeding-playbook.md` — seeding HOT-tier files from connected tools
  - `docs/agent-setup-playbook.md` — first-run agent behavior

To pull the latest curated guidance and re-apply it without re-running the wizard:

```bash
cd <export-repo>
bash scripts/thinkos-update.sh --pull
```

For MCP query patterns and write workflows, run `/thinkos-mcp-help`.
