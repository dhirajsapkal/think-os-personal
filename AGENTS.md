# Think OS Agent Guide

Use this file when you are an agent helping someone install, inspect, or improve Think OS.

## If you're installing Think OS for a user

**Read `adapters/claude-code/INSTALL.md` and follow it exactly.** That single file is the canonical install playbook — it has every step, every question to ask, and every command to run. Don't read the rest of this repo's docs for the install; INSTALL.md is self-contained.

## If you're maintaining or extending Think OS

Read in this order (skip what you don't need):

1. `README.md` for the product overview.
2. `docs/agent-setup-playbook.md` for first-run setup behavior (Phase 1).
3. `docs/phase-2-seeding-playbook.md` for Phase 2 (opt-in bulk-seed from connected tools; default path is emergent seeding — see `docs/emergent-seeding.md`).
4. `docs/multi-vault-architecture.md` for the multi-vault design (privacy tiers, schema enforcement, git integration).
5. `docs/automation-roadmap.md` for the source-matrix + indexer-first pattern that Phase 2 uses.
6. `adapters/claude-code/README.md` for the Claude Code adapter.

Cowork and Codex adapters live on the `roadmap/cowork-codex` branch — cherry-pick when their plugin formats stabilize.

Do not read every template file by default. Use `scripts/thinkos-doctor.sh --json` for setup state and `scripts/thinkos-state.sh where-am-i` for onboarding phase.

## Setup Principle

Be a guided installer, not a scavenger hunt.

- Ask the user the same questions one at a time — vault location, whether to install Basic Memory, bundle preset — without pre-selecting.
- Run scripts for checks and setup. Avoid manually scraping the user's home folder or reading their vault contents.
- Never overwrite a user's existing knowledge files. The setup script copies missing templates only.

## Curated Always-On Instructions

The agent instruction block installed into `~/.claude/CLAUDE.md` is assembled from two layers:

1. **Curated, product-independent guidance** in `templates/instructions/`:
   - `00-think-os-priority.md` — "this user has Think OS, query Basic Memory first, core rules" (includes multi-instance dedup rule and cost-of-context skip rule)
   - `10-token-efficiency.md` — tool-use defaults (Grep over Read+grep, Edit over Write, batching, etc.)
   - `20-skill-routing.md` — topic → skill mapping (design → `frontend-design`, etc.)
   - `30-think-os-write-targets.md` — content type → vault destination
   - `40-emergent-seeding.md` — HOT-file stub detection, propose-then-save, per-file draft state
   - `50-drift-detection.md` — four contradiction types flagged mid-flow; bounded one-line nudge
   - `60-shared-mode.md` — `tier: sensitive` frontmatter, shared-mode flag file, `/thinkos-shared on|off`
2. **Adapter-specific instructions** in `adapters/claude-code/instructions.md`.

`scripts/thinkos-setup.sh` concatenates layer 1 then layer 2 between `<!-- BEGIN THINK OS -->` / `<!-- END THINK OS -->` markers. `scripts/thinkos-update.sh` re-applies the same block (use after editing curated content or pulling new content from this repo).

When working on Think OS itself, prefer editing the curated files over duplicating their content in adapter instructions — anything that should apply across all products belongs in `templates/instructions/`.

## Token Efficiency

- Prefer `scripts/thinkos-doctor.sh --json` over exploratory shell commands.
- Prefer `scripts/thinkos-setup.sh --yes` over hand-running each step.
- Do not load the live vault content during Phase 1 setup unless the user asks you to inspect their actual notes.
- Do not read connector data, email, calendar, Slack, or project tracker content during **Phase 1**. (Phase 2 is the consented exception — see below.)

- After basic setup, offer the bundle wizard (`--bundle <preset>`); see `data/plugin-catalog.yaml`.

## Phase 1 vs Phase 2 vs Emergent Seeding

Onboarding has three paths. The line between them matters:

- **Phase 1** — Infrastructure. Setup installs vault templates, Basic Memory MCP, the Claude Code adapter, and the plugin bundle. No connector data is read. Ends by writing `~/.thinkos/wizard-state.json` with `phase: awaiting_oauth_and_restart`.
- **Emergent seeding (default)** — After Phase 1, HOT-tier files start as stubs. The agent detects the `<!-- thinkos:stub -->` marker, proposes facts from conversation turn-by-turn, and saves with explicit per-fact confirmation. Per-file draft state lives at `~/.thinkos/emergent-state.json`. No bulk connector reads required. See `docs/emergent-seeding.md`.
- **Phase 2 (opt-in bulk-seed)** — For users with rich connector data who want to front-load. After OAuth + restart, the user runs `/thinkos-continue`. The agent follows `docs/phase-2-seeding-playbook.md` and *does* read from connectors — but only with per-source consent, only the minimum needed, and only drafts content (the user approves before each commit).

On every new session, check whether setup is in progress:

```bash
test -f ~/.thinkos/wizard-state.json && bash scripts/thinkos-state.sh where-am-i
```

If `phase != complete`, surface a one-line nudge before answering the user's actual question.

## First-Run Command Shape

Recommended default:

```bash
scripts/thinkos-setup.sh \
  --os-home "$HOME/ThinkOS/vault" \
  --install-basic-memory \
  --yes
```

Then verify:

```bash
scripts/thinkos-doctor.sh \
  --os-home "$HOME/ThinkOS/vault" \
  --deep
```

## Safety

- Keep the recommended vault path local: `~/ThinkOS/vault`.
- If the user chooses Documents, Desktop, Downloads, or an external/cloud folder, explain that macOS permissions may require Files/Folders or Full Disk Access.
- If a command fails, run the doctor script again and report the smallest actionable next step.

## Multi-vault awareness

Think OS supports multiple vaults: one personal hub plus zero-or-more project vaults (shared via git) plus reference vaults (read-only). When operating in any session:

1. Check `~/.thinkos/vaults.json` for the registry. If absent, single-vault legacy mode.
2. Determine active vault (sticky override at `~/.thinkos/active-vault`, else CWD-derived, else default).
3. Mention the active vault in your first response: `Active vault: <id>. Personal hub always loaded.`
4. Always load personal hub HOT-tier (Identity, Current Focus). Layer in project HOT (Project Home, Roster) if a project vault is active.
5. Route writes per design doc §8: personal markers → personal hub regardless; schema mismatch → personal hub; team activity → project vault; ambiguous → ask.

The full design is at `docs/multi-vault-architecture.md`. Use `scripts/thinkos-vault.sh` to manage the registry; never edit `~/.thinkos/vaults.json` by hand.
