---
type: setup-guide
tags:
- setup
- claude-code
- slash-commands
permalink: think-os/adapters/claude-code/commands/readme
---

# CLI agent custom slash commands

Sixteen slash commands for using your personal context OS from any CLI agent session, regardless of cwd. They wrap Basic Memory MCP calls plus a few file ops so common workflows are one keystroke instead of a sentence. All commands use the `thinkos-` prefix so they're easy to find — type `/thinkos` and autocomplete shows the full list.

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
| `/thinkos-stale` | List notes past their freshness window |
| `/thinkos-reindex` | Refresh Basic Memory's index after external edits |
| `/thinkos-voice <before \| after>` | Rewrite a draft in your voice profile |
| `/thinkos-setup` | Run the first-time setup wizard from the export repo |
| `/thinkos-continue` | Resume Think OS setup after OAuth + restart (Phase 2) |
| `/thinkos-vault` | Manage vaults — list, switch, create-project, clone |
| `/thinkos-help` | Show all Think OS commands and what they do |
| `/thinkos-mcp-help` | How to query and update your personal context MCP |

## Connector sync

The connector-sync workflow (`/productivity:update` — pulls from Gmail / Slack / project tracker / etc.) runs in desktop agent, where the connector MCPs are registered. Use these commands for read/write against the OS files themselves.

- **desktop agent** — refreshes `01 Now/Tasks.md` from connectors
- **CLI agent** — reads `01 Now/Tasks.md` and writes to the OS during project work

## Maintenance

If you want to update a command's behavior, edit the file in this folder, then re-copy. Or edit `~/.claude/commands/<name>.md` directly — that's the live version.

If you want new commands, add a markdown file here following the same pattern, then copy. The frontmatter `description` line shows up in autocomplete.

---

Commands require Basic Memory MCP (installed by the setup wizard; manual path: see the adapter README). If MCP is unavailable, commands degrade to direct file reads.
