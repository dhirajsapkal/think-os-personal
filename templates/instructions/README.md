# Curated Always-On Instructions

The markdown files in this directory are the **always-on guidance** that gets injected into every agent session. The canonical list of wired files and the concatenation logic live in `scripts/lib/render-instructions.sh` (source of truth, created in WP-28). The files are concatenated into the `<!-- BEGIN THINK OS -->` / `<!-- END THINK OS -->` block of the user's global Claude Code instructions:

- `~/.claude/CLAUDE.md` (Claude Code)

## Concatenation order (the wired list)

The order below matches the `curated_instruction_files()` function in `scripts/lib/render-instructions.sh`. Line counts are approximate and reflect the current state of each file; run `wc -l templates/instructions/*.md` to check live sizes.

1. `00-think-os-priority.md` (~50 lines) — "this user has Think OS, MUST query Basic Memory first", retrieval doctrine, core rules
2. `05-global-rules.md` (~47 lines) — non-negotiable NEVER / ALWAYS rules (destructive ops, scope, secrets, drafts-never-send, plan-before-edit, etc.). **Do not slim this file** — it is load-bearing safety.
3. `10-token-efficiency.md` (~21 lines) — tool-use defaults + Think OS large-file read rules (Work Log / Capture Log / Tasks extraction, build_context discipline)
4. `20-skill-routing.md` (~25 lines) — topic → skill mapping (design → `frontend-design:frontend-design`, decisions → `/thinkos-decisions`, etc.)
5. `30-think-os-write-targets.md` (~22 lines) — where new content goes by content type + multi-vault routing
6. `40-emergent-seeding.md` (~10 lines) — resident core only (stub marker, four target files, offer cadence); save-flow mechanics live in `adapters/claude-code/skills/thinkos-emergent-seeding/SKILL.md`
7. `50-drift-detection.md` (~14 lines) — flag contradictions (expired Current Focus, unknown people, missing project entries) mid-flow as a single end-of-turn line
8. `60-shared-mode.md` (~7 lines) — resident redaction core (detection signals + search/read redaction, which must always fire); full spec lives in `adapters/claude-code/skills/thinkos-shared-mode/SKILL.md`
9. `70-claude-ai-bridge.md` (~3 lines) — pointer stub; full bridge guide lives in `adapters/claude-code/skills/thinkos-bridge/SKILL.md`

When the wired list changes, also update the "Where to look next" section in `00-think-os-priority.md` so the preamble's promise matches what actually gets concatenated.

Since v0.9.3 the assembled block (curated files + `adapters/claude-code/instructions.md`) is budgeted at **~240 lines / ~18,000 chars (~4.5k tokens)** — measure with:

```bash
REPO_ROOT=$PWD DRY_RUN=0 OS_HOME=~/ThinkOS/vault bash -c \
  'source scripts/lib/render-instructions.sh; render_think_os_block adapters/claude-code/instructions.md' | wc -l -c
```

Skill-ified blocks (bridge, shared-mode full spec, emergent-seeding save flow) are installed to `~/.claude/skills/` by `thinkos-setup.sh` / `thinkos-update.sh` and load on demand instead of every session. Keep the resident stubs pointing at them. The assembled block must stay byte-stable across sessions (no dynamic content) so prompt caching holds; dynamic state arrives via the SessionStart hook (`scripts/thinkos-session-start.sh`).

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

Keep each file within its budget above. If a block outgrows it, the right move is to factor the detail into a skill under `adapters/claude-code/skills/` (loaded on demand) or a docs/ note, leaving a resident pointer stub — not to append forever. Passive conversation-triggered behaviors (drift nudges, seeding offers, redaction) must keep their trigger logic resident: a skill the model never loads is a behavior that never fires.
