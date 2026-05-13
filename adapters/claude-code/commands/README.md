---
type: setup-guide
tags:
- setup
- claude-code
- slash-commands
permalink: think-os/adapters/claude-code/commands/readme
---

# CLI agent custom slash commands

Thirteen slash commands for using your personal context OS from any CLI agent session, regardless of cwd. They wrap Basic Memory MCP calls plus a few file ops so common workflows are one keystroke instead of a sentence.

## Install (one time, ~5 sec)

```bash
mkdir -p ~/.claude/commands
cp /path/to/this/export/think-os-alpha/adapters/claude-code/commands/*.md ~/.claude/commands/
```

After that, every new CLI agent session will autocomplete these as you type `/`.

To verify: `cd ~ && claude`, then type `/` — you should see the list.

## Commands

| Slash | What it does |
|---|---|
| `/whoami` | Quick identity + current-focus dump |
| `/plate` | What's on my plate today (TASKS + priorities) |
| `/morning` | Full morning brief (identity + focus + plate + Slack tracker) |
| `/who <name>` | Search `people.md` for a name |
| `/project <slug>` | Load deep context for a project |
| `/decisions [topic]` | Search standing decisions |
| `/learnings [topic]` | Search cross-project learnings |
| `/log <message>` | Append a manual entry to `work-log.md` |
| `/capture <learning>` | Append a structured learning to `learnings.md` |
| `/decide <decision>` | Append a structured standing decision to `decisions.md` |
| `/stale` | Walk frontmatter dates, report stale files |
| `/update` | Refresh Basic Memory's index from disk |
| `/voice-rewrite <before \| after>` | Capture an AI draft vs my rewrite into `voice-profile.md` |

## What's NOT here (and why)

The connector-sync workflow (`/productivity:update` in desktop agent — pulls from Gmail / Slack / project tracker / etc.) is **deliberately not** in CLI agent. The connector MCPs are registered in desktop agent, not CLI agent. Run that in desktop agent; use these commands here for read / write against the OS files themselves.

The two surfaces are complementary, not parallel:
- **desktop agent** = where `TASKS.md` gets refreshed FROM connectors
- **CLI agent** = where you READ `TASKS.md` and WRITE to the OS while doing project work

## Maintenance

If you want to update a command's behavior, edit the file in this folder, then re-copy. Or edit `~/.claude/commands/<name>.md` directly — that's the live version.

If you want new commands, add a markdown file here following the same pattern, then copy. The frontmatter `description` line shows up in autocomplete.

---

*The slash commands assume Basic Memory MCP is wired in (see `docs/setup-global-integration.md`). They use `mcp__basic-memory__*` tools. If MCP is unavailable, they degrade to direct file reads.*
