---
description: Resume Think OS onboarding (Phase 2 — seed your context from connected tools)
permalink: think-os/adapters/claude-cowork/commands/thinkos-continue
---

Resume Think OS setup inside Cowork. The user has finished Phase 1 (infrastructure) and is ready (or close to ready) for Phase 2 — drafting their HOT-tier files from connected tools.

## Step 1 — Check state

The state file lives at `~/.thinkos/wizard-state.json`. You won't have direct bash access on every Cowork install, so prefer reading the file via a filesystem MCP (e.g. `mcp__basic-memory__read_content` pointed at the absolute path) or via the user's terminal if they have one open.

If you have bash:

```bash
bash <export-repo>/scripts/thinkos-state.sh show
bash <export-repo>/scripts/thinkos-state.sh where-am-i
```

If you cannot run bash inside Cowork: ask the user to run that command in their terminal and paste the output. The phase tells you where to start.

Branch on `phase`:

- **`awaiting_oauth_and_restart`** — Phase 1 manual steps may not be done. Tell the user what's left (Cowork MCP setup, OAuth per connector, app restart). When they confirm done, ask them to run from terminal:

  ```bash
  bash <export-repo>/scripts/thinkos-state.sh set-phase ready_for_seeding
  ```

- **`ready_for_seeding`** — Proceed to Step 2.

- **`seeding`** — Pick up where left off. Read `files_seeded` to see what's done.

- **`complete`** — Setup is done. Offer to re-seed a specific file.

## Step 2 — Follow the canonical playbook

The full Phase 2 flow lives in the export repo at:

```
docs/phase-2-seeding-playbook.md
```

Read it via `mcp__basic-memory__read_note "think-os/phase-2-seeding-playbook"` if the user has Think OS already indexed in Basic Memory, or via the filesystem.

It covers:
- Operating principles (privacy, drafts only, citations mandatory, skippable)
- Per-file recipes: Project Index → Current Focus → Identity → People
- Per-source consent flow
- Synthesis patterns and draft shapes (match the templates in `templates/`)
- Wrap-up (mark phase complete, run doctor, suggest first real command)

## Cowork UX notes

- **Use `AskUserQuestion` for choice prompts.** Cowork renders this as native chips/buttons — much better than plain text in this environment. Use it for:
  - The "all four / pick one / skip" question at the start of Phase 2
  - Per-source Y/N consent (use `multiSelect: true` to batch consent for several sources in one question)
  - Per-file approve / edit / regenerate choices
- **Use `ToolSearch` to load connector tool schemas** before calling them. The expected names follow `mcp__claude_ai_<Name>__*` (e.g. `mcp__claude_ai_Slack__slack_search_users`, `mcp__claude_ai_Google_Calendar__list_events`).
- **Show drafts in the chat directly.** Render the markdown. Cowork displays it well. Citations go in a fenced code block underneath.
- **Write files via `mcp__basic-memory__edit_note`** with operation `replace` (for files that still have only template content) or `append`. Never use a generic filesystem MCP to write — Basic Memory needs to index the change.
- **Mark progress after each file:** ask the user to run from terminal `bash scripts/thinkos-state.sh mark-seeded <key>`, or if you have bash through a tool, do it yourself.

## Connector-name quick reference (Cowork)

| Source | Tool prefix |
|---|---|
| Slack | `mcp__claude_ai_Slack__*` |
| Gmail | `mcp__claude_ai_Gmail__*` |
| Notion | `mcp__claude_ai_Notion__*` |
| Granola | `mcp__claude_ai_Granola__*` |
| Calendar | `mcp__claude_ai_Google_Calendar__*` |
| Drive | `mcp__claude_ai_Google_Drive__*` |
| Atlassian (Jira + Confluence) | `mcp__claude_ai_Atlassian__*` |
| HubSpot | `mcp__claude_ai_HubSpot__*` |
| ZoomInfo | `mcp__claude_ai_ZoomInfo__*` |
| ClickUp | `mcp__claude_ai_ClickUp__*` |
| QuickBooks | `mcp__claude_ai_Intuit_QuickBooks__*` |

If a connector is missing from the registry, the user hasn't installed it via the bundle wizard — tell them and offer to skip that source for Phase 2 or pause Phase 2 to go install it.

## Privacy floor

Phase 2 reads real user data. Reinforce throughout the flow:

- Ask before each source. The user can say no to any of them.
- Read the minimum needed. For example, Granola: prefer meeting *titles* over transcripts when drafting Project Index; only pull transcripts for Current Focus, and only for meetings the user wants to surface.
- Never read connector data and just write to the vault. Always show the draft first.

## Failure recovery

If anything fails (MCP timeout, empty result, OAuth not actually complete):
- Tell the user what failed in one sentence.
- Offer to skip that source and continue, or pause and fix.
- Don't auto-retry more than once.
