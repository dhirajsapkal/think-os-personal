---
description: Resume Think OS onboarding (Phase 2 — seed your context from connected tools)
permalink: think-os/adapters/claude-code/commands/thinkos-continue
---

Phase 2 is the **opt-in bulk-seed flow**. If the user invoked you, they want it — proceed with the playbook below. Otherwise, the default path is **emergent seeding** via natural conversation (see `templates/instructions/40-emergent-seeding.md` and `docs/emergent-seeding.md`): the agent drafts HOT files turn-by-turn as the user mentions facts, and saves with explicit per-fact approval. Phase 2 is for users who already have rich connector data (Slack, Notion, calendar, etc.) and want to front-load.

Resume Think OS setup. The user finished Phase 1 (install) and is ready for Phase 2 — drafting their HOT-tier files from connected tools.

If the playbook is not accessible (e.g., CWD is not the export repo), follow the inline summary below — it covers the essential steps.

## Follow the canonical playbook

The full Phase 2 flow lives in `docs/phase-2-seeding-playbook.md`. Read it once and follow it exactly. It tells you to:

1. **Do a silent state check.** Run `bash scripts/thinkos-state.sh show` but don't paste its output to the user. Branch on `phase`.
2. **Show ONE tight welcome message.** No Phase 1 recap, no status dump, no privacy-floor lecture.
3. **Check connector auth** via `claude mcp list`. If anything needs auth, use `AskUserQuestion` to ask the user whether to pause-and-auth or skip un-authed tools.
4. **Use `AskUserQuestion` for the file picker** (Project Index / Current Focus / Identity / People / All four / Pause).
5. **Per-file flow**: tell the user which sources you'd like to use, ask consent per source (one at a time, default N), pull and synthesize, show draft, iterate, commit via `mcp__basic-memory__edit_note`, `mark-seeded`.
6. **Three-layer capture offer (Section 3)**: after all files are seeded, run the three-block wrap-up in order — Block 1 (session capture, local), Block 2 (vault maintenance triggers, cloud), Block 3 (continuous capture sources, opt-in per source). Each block uses `AskUserQuestion`; after each block, show a one-line summary of what was set up before proceeding to the next.

## Critical UX rules

- **Use `AskUserQuestion` everywhere a choice fits.** Claude Code renders it as a chip-picker so the user clicks instead of types. Load via `ToolSearch select:AskUserQuestion` if needed.
- **Don't echo shell output to the user.** State checks, `mcp list`, and any other probing commands should run silently. Only surface results when something's broken.
- **Don't go exploring.** No `ls`, `find`, or `pwd` against unrelated folders. Especially don't try to auto-detect the user's old vault — they'll mention it if they want to import.
- **Don't lecture.** Skip preamble about Phase 1 being done, the privacy floor, the indexer-first principle. Those are agent-internal concerns; the user just wants to seed their files.
- **One question at a time.** Don't batch consent.
- **Write via `mcp__basic-memory__edit_note` / `write_note`** — never `cat > file`.
- **`mark-seeded`** after each file so resumes work.

## Connector tool name resolution

Bundle items install MCPs under names like `slack`, `gmail`, `notion`. Use `ToolSearch select:mcp__<name>__*` to load schemas before calling. If a tool isn't available, the connector isn't installed or isn't authed — tell the user, offer to skip that source.

## Failure recovery

- MCP call fails or times out → tell the user what failed in one sentence, offer to skip that source.
- All sources for a file return empty → ask whether to skip the file or fall back to manual conversation-based seeding.
- Don't auto-retry more than once.
