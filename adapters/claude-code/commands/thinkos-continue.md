---
description: Resume Think OS onboarding (Phase 2 — seed your context from connected tools)
permalink: think-os/adapters/claude-code/commands/thinkos-continue
---

Resume Think OS setup. The user has finished Phase 1 (infrastructure) and is ready (or close to ready) for Phase 2 — drafting their HOT-tier files from connected tools.

## Step 1 — Check state

Run:

```bash
bash scripts/thinkos-state.sh show
bash scripts/thinkos-state.sh where-am-i
```

If the state file does not exist: tell the user Phase 1 hasn't run yet and point them at `bash scripts/thinkos-wizard.sh`. Stop.

Branch on the `phase` field:

- **`awaiting_oauth_and_restart`** — Run `scripts/thinkos-doctor.sh --deep --os-home <vault> --products <products>` to verify Phase 1 manual steps are actually done. Specifically check:
  - All expected MCPs appear in `claude mcp list`
  - basic-memory project exists and indexes
  - Bundle items (if any) appear via `--check-bundle`

  If the doctor still shows warnings about MCP registration or missing OAuth, surface them to the user as a concrete punch list: "Before Phase 2 can start, finish these N steps." Then stop. Do NOT advance the phase until the doctor is clean.

  If the doctor is clean: advance to `ready_for_seeding`:

  ```bash
  bash scripts/thinkos-state.sh set-phase ready_for_seeding
  ```

- **`ready_for_seeding`** — Proceed to Step 2.

- **`seeding`** — Phase 2 was previously started. Read `files_seeded` and tell the user what's done. Ask: "Pick up where you left off, restart from a specific file, or skip to wrap-up?"

- **`complete`** — Tell the user setup is done. Offer to re-seed a specific file. If they want to: `set files_seeded.<file> false` then `set-phase seeding`.

## Step 2 — Follow the canonical playbook

The full Phase 2 flow lives in:

```
docs/phase-2-seeding-playbook.md
```

Read it once and follow it. It covers:
- Operating principles (privacy, drafts only, citations mandatory, skippable)
- Per-file recipes: Project Index → Current Focus → Identity → People
- Per-source consent flow
- Synthesis patterns and draft shapes (match the templates in `templates/`)
- Wrap-up (mark phase complete, run doctor, suggest first real command)

## Claude Code UX notes

- Use plain numbered choices in chat — Claude Code's terminal renders these well. Avoid `AskUserQuestion` (that tool is Cowork-only).
- For per-source consent, ask one source at a time on its own line. Y/N. Default to N (user must opt in).
- When showing draft content, render the markdown directly so the user sees it the way it'll land in their vault. Show the citations block in a fenced code block underneath, not in the file.
- Write files via `mcp__basic-memory__write_note` or `mcp__basic-memory__edit_note` — never via shell `cat > file`. The vault is indexed; bypassing Basic Memory breaks the index.
- After each file is written, run `bash scripts/thinkos-state.sh mark-seeded <key>` so progress is durable.

## Per-source connector tool name resolution

Bundle items install MCPs under different names depending on the path:
- Claude Code stdio/remote MCPs use the `mcp_name` from `data/plugin-catalog.yaml` (e.g. `slack`, `gmail`, `notion`).
- Cowork connectors use the `mcp__claude_ai_<Name>__*` naming.

When you need to use a connector, first use `ToolSearch` with `query: "select:mcp__<name>__*"` or a keyword to load the schema, then call the tool. If a tool isn't available, the user hasn't installed it — tell them and offer to skip that source.

## Privacy floor

Phase 2 reads real user data. Reinforce throughout the flow:

- Ask before each source. The user can say no to any of them.
- Read the minimum needed. For example, Granola: prefer meeting *titles* over transcripts when drafting Project Index; only pull transcripts for Current Focus, and only for meetings the user wants to surface.
- Never read connector data and just write to the vault. Always show the draft first.

## Failure recovery

If anything fails (MCP timeout, empty result, OAuth not actually complete):
- Tell the user what failed in one sentence.
- Offer to skip that source and continue, or to pause Phase 2 and fix the underlying issue.
- Don't auto-retry more than once.
