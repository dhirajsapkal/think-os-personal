# Curated Always-On Instructions

The markdown files in this directory are the **always-on guidance** that gets injected into every agent session. The canonical list of wired files and the concatenation logic live in `scripts/lib/render-instructions.sh` (source of truth, created in WP-28). The files are concatenated into the `<!-- BEGIN THINK OS -->` / `<!-- END THINK OS -->` block of the user's global Claude Code instructions:

- `~/.claude/CLAUDE.md` (Claude Code)

## Concatenation order (the wired list)

The order below matches the `curated_instruction_files()` function in `scripts/lib/render-instructions.sh`. Line counts are approximate and reflect the current state of each file; run `wc -l templates/instructions/*.md` to check live sizes.

1. `00-think-os-priority.md` (~59 lines) — "this user has Think OS, MUST query Basic Memory first, core rules"
2. `05-global-rules.md` (~47 lines) — non-negotiable NEVER / ALWAYS rules (destructive ops, scope, secrets, drafts-never-send, plan-before-edit, etc.)
3. `10-token-efficiency.md` (~19 lines) — tool-use defaults (Grep over Read+grep, Edit over Write, batch parallel calls, etc.)
4. `20-skill-routing.md` (~41 lines) — topic → skill mapping (design → `frontend-design:frontend-design`, decisions → `/thinkos-decisions`, etc.)
5. `30-think-os-write-targets.md` (~42 lines) — where new content goes by content type
6. `40-emergent-seeding.md` (~80 lines) — detect HOT-file stubs and progressively fill them from conversation; offer-then-confirm, one per turn
7. `50-drift-detection.md` (~38 lines) — flag contradictions (expired Current Focus, unknown people, missing project entries) mid-flow as a single end-of-turn line
8. `60-shared-mode.md` (~60 lines) — when shared-mode is on, redact `tier: sensitive` notes at read time; the toggle skill only sets the flag, this block does the enforcement
9. `70-claude-ai-bridge.md` (~47 lines) — how the `mcp__claude_ai_*` deferred-tool surface works; read before declaring a connector unavailable

When the wired list changes, also update the "Where to look next" section in `00-think-os-priority.md` so the preamble's promise matches what actually gets concatenated.

The resulting block is ~390–530 lines depending on installed blocks; run `wc -l templates/instructions/*.md adapters/claude-code/instructions.md` to check current size.

## Editing

These files are plain markdown. Edit them directly; no templating beyond the `{{OS_HOME}}` token (replaced at install time). After editing, run:

```bash
bash scripts/thinkos-update.sh
```

…to re-render the BEGIN/END block in every installed product's instruction file.

## Adding new content

- New routing entry → `20-skill-routing.md`
- New token-efficiency default → `10-token-efficiency.md`
- New content-type → write target → `30-think-os-write-targets.md`
- New non-negotiable behavioral rule (NEVER / ALWAYS) → `05-global-rules.md`
- New core rule that applies before all others / changes the priority protocol → `00-think-os-priority.md`

Keep each file under ~120 lines. If a file outgrows that, the right move is usually to factor a subsection into a docs/ note and link to it from the curated file rather than appending forever.
