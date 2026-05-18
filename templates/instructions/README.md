# Curated Always-On Instructions

The markdown files in this directory are the **always-on guidance** that gets injected into every agent session. The files explicitly listed in `curated_instruction_files()` inside `scripts/thinkos-setup.sh` (and re-applied by `scripts/thinkos-update.sh`) are concatenated into the `<!-- BEGIN THINK OS -->` / `<!-- END THINK OS -->` block of the user's global Claude Code instructions:

- `~/.claude/CLAUDE.md` (Claude Code)

## Concatenation order (the wired list)

1. `00-think-os-priority.md` — "this user has Think OS, MUST query Basic Memory first, core rules"
2. `05-global-rules.md` — non-negotiable NEVER / ALWAYS rules (destructive ops, scope, secrets, drafts-never-send, plan-before-edit, etc.)
3. `10-token-efficiency.md` — tool-use defaults (Grep over Read+grep, Edit over Write, batch parallel calls, etc.)
4. `20-skill-routing.md` — topic → skill mapping (design → `frontend-design:frontend-design`, etc.)
5. `30-think-os-write-targets.md` — where new content goes by content type
6. `70-claude-ai-bridge.md` — how the `mcp__claude_ai_*` deferred-tool surface works; read before declaring a connector unavailable
7. The adapter-specific instructions for the selected product (`adapters/<product>/instructions.md` or `AGENTS.md`)

### Files present but not currently wired

`40-emergent-seeding.md`, `50-drift-detection.md`, and `60-shared-mode.md` exist as drafts in this directory but are not in the `curated_instruction_files()` list. The behaviors they describe ship via the corresponding skills/commands instead. If you add them to the wired list, also update `00-think-os-priority.md`'s "Where to look next" section so the preamble's promise matches what actually gets concatenated.

The resulting block is ~200–280 lines, self-contained, and readable as one coherent document.

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
