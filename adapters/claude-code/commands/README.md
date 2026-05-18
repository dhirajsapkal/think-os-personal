---
type: setup-guide
tags:
- setup
- claude-code
- slash-commands
permalink: think-os/adapters/claude-code/commands/readme
---

# CLI agent custom slash commands

The slash commands listed in /thinkos-help for using your personal context OS from any CLI agent session, regardless of cwd. They wrap Basic Memory MCP calls plus a few file ops so common workflows are one keystroke instead of a sentence. All commands use the `thinkos-` prefix so they're easy to find — type `/thinkos` and autocomplete shows the full list.

## Install (one time, ~5 sec)

```bash
mkdir -p ~/.claude/commands
find /path/to/this/export/think-os-alpha/adapters/claude-code/commands -maxdepth 1 -name "*.md" ! -name "README.md" -exec cp {} ~/.claude/commands/ \;
```

After that, every new CLI agent session will autocomplete these as you type `/`.

To verify: `cd ~ && claude`, then type `/` — you should see the list.

## Commands

| Slash | What it does |
|---|---|
| `/thinkos-whoami` | Quick identity + role + current focus |
| `/thinkos-plate` | What's on your plate today (tasks + current focus) |
| `/thinkos-morning` | Daily brief — focus, plate, recent log, calendar |
| `/thinkos-who <name>` | Show what you know about a specific person |
| `/thinkos-project <slug>` | Load deep context for a project |
| `/thinkos-decisions [topic]` | Search your standing decisions, optionally by topic |
| `/thinkos-learnings [topic]` | Search reusable learnings by topic or tag |
| `/thinkos-log <message>` | Capture a timestamped note to your work log |
| `/thinkos-capture <learning>` | Capture a cross-project learning into your vault |
| `/thinkos-decide <decision>` | Record a standing decision in your vault |
| `/thinkos-refresh` | Refresh Tasks.md from connectors (Gmail, Slack, Calendar, ClickUp, Atlassian, Notion, Granola) |
| `/thinkos-stale` | List notes past their freshness window |
| `/thinkos-reindex` | Refresh Basic Memory's index after external edits |
| `/thinkos-voice <before \| after>` | Rewrite a draft in your voice profile |
| `/thinkos-setup` | Run the first-time setup wizard from the export repo |
| `/thinkos-continue` | Resume Think OS setup after OAuth + restart (Phase 2) |
| `/thinkos-vault` | Manage vaults — list, switch, create-project, clone |
| `/thinkos-help` | Show all Think OS commands and what they do |
| `/thinkos-mcp-help` | How to query and update your personal context MCP |
| `/thinkos-save` | Save substantive items from the current session to your vault |
| `/thinkos-autosave` | Manage periodic background capture of Claude Code session activity |
| `/thinkos-sync` | Commit + pull --rebase + push your personal-hub vault state |
| `/thinkos-shared` | Toggle shared-mode (hide tier:sensitive notes from agent reads) |
| `/thinkos-undo-capture` | Undo a recent capture — remove it from the vault and record the reversal |
| `/thinkos-automate` | Set up Think OS scheduled triggers (Phase 3 — automations) |
| `/thinkos-capture-setup` | Enable Think OS continuous-capture sources one at a time (Phase C) |
| `/thinkos-recent` | Show recent captures from the ledger — what was captured and where it landed |
| `/thinkos-vitals` | Snapshot of vault health — staleness, budgets, broken links, ledger volume |
| `/thinkos-update` | Update Think OS in place — pull latest curated instructions, commands, and skills without touching your vault |

## Connector sync

The connector-sweep workflow is `/thinkos-refresh` — pulls from Gmail / Slack / Calendar / ClickUp / Atlassian / Notion / Granola and rewrites `01 Now/Tasks.md` with a fresh `last_synced` timestamp. Works in any surface that can reach a connector path:

- **Claude Code (CLI)** — uses the claude.ai bridge tools (`mcp__claude_ai_<Service>__*`). Confirm via `claude mcp list`.
- **Cowork (web)** — same bridge tools.
- **Desktop agent** — uses native connector MCPs if registered locally, otherwise falls through to the bridge.

The legacy `/productivity:update` skill (desktop-only) is retired — its behavior lives in `/thinkos-refresh`.

## Maintenance

If you want to update a command's behavior, edit the file in this folder, then re-copy. Or edit `~/.claude/commands/<name>.md` directly — that's the live version.

If you want new commands, add a markdown file here following the same pattern, then copy. The frontmatter `description` line shows up in autocomplete.

---

Commands require Basic Memory MCP (installed by the setup wizard; manual path: see the adapter README). If MCP is unavailable, commands degrade to direct file reads.
