# Curated Always-On Instructions

The four markdown files in this directory are the **always-on guidance** that gets injected into every agent session. They are concatenated by `scripts/thinkos-setup.sh` (and re-applied by `scripts/thinkos-update.sh`) into the `<!-- BEGIN THINK OS -->` / `<!-- END THINK OS -->` block of the user's global agent instructions:

- `~/.claude/CLAUDE.md` (Claude Code)
- `~/.codex/AGENTS.md` (Codex)
- `~/.thinkos/claude-cowork-instructions.md` (Cowork — user pastes into Cowork personalization manually)

## Concatenation order

1. `00-think-os-priority.md` — "this user has Think OS, query Basic Memory before substantive answers, core rules"
2. `10-token-efficiency.md` — tool-use defaults (Grep over Read+grep, Edit over Write, batch parallel calls, etc.)
3. `20-skill-routing.md` — topic → skill mapping (design → `frontend-design:frontend-design`, etc.)
4. `30-think-os-write-targets.md` — where new content goes by content type
5. The adapter-specific instructions for the selected product (`adapters/<product>/instructions.md` or `AGENTS.md`)

The resulting block is ~150–200 lines, self-contained, and readable as one coherent document.

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
- New core rule that applies before all others → `00-think-os-priority.md`

Keep each file under ~120 lines. If a file outgrows that, the right move is usually to factor a subsection into a docs/ note and link to it from the curated file rather than appending forever.
