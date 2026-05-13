# Think OS Agent Guide

Use this file when you are an agent helping someone install, inspect, or improve Think OS.

## Read First

1. `README.md` for the product overview.
2. `docs/agent-setup-playbook.md` for first-run setup behavior (Phase 1).
3. `docs/phase-2-seeding-playbook.md` for Phase 2 (drafting HOT-tier files from connected tools).
4. `docs/multi-vault-architecture.md` for the multi-vault design (privacy tiers, schema enforcement, git integration).
5. `adapters/README.md` to pick the user's tool path.
6. The selected adapter only:
   - `adapters/claude-cowork/README.md`
   - `adapters/claude-code/README.md`
   - `adapters/codex/README.md`

Do not read every template file by default. Use `scripts/thinkos-doctor.sh --json` for setup state and `scripts/thinkos-state.sh where-am-i` for onboarding phase.

## Setup Principle

Be a guided installer, not a scavenger hunt.

- First offer the user the standalone wizard: `bash scripts/thinkos-wizard.sh` (or `--preview` for a no-op walkthrough). It is the canonical end-to-end setup UX.
- If the user prefers to drive from chat, ask the same questions one at a time — vault location, products, whether to install Basic Memory, bundle preset — without pre-selecting.
- Use native interactive controls if the host app supports them: choice chips, forms, checkboxes, or quick-pick lists.
- Run scripts for checks and setup. Avoid manually scraping the user's home folder or reading their vault contents.
- Never overwrite a user's existing knowledge files. The setup script copies missing templates only.

## Token Efficiency

- Always run `scripts/thinkos-preview.sh --products <list> [--bundle <preset>]` first and relay the plan to the user for approval before mutating anything.
- Prefer `scripts/thinkos-doctor.sh --json --products <list>` over exploratory shell commands.
- Prefer `scripts/thinkos-setup.sh --products <list> --yes` over hand-running each step.
- Do not load the live vault content during Phase 1 setup unless the user asks you to inspect their actual notes.
- Do not read connector data, email, calendar, Slack, or project tracker content during **Phase 1**. (Phase 2 is the consented exception — see below.)

- After basic setup, offer the bundle wizard (`--bundle <preset>`); see `data/plugin-catalog.yaml`.

## Phase 1 vs Phase 2

Onboarding splits into two phases. The line between them matters:

- **Phase 1** — Infrastructure. Wizard installs vault templates, Basic Memory MCP, adapters, and the plugin bundle. No connector data is read. Ends by writing `~/.thinkos/wizard-state.json` with `phase: awaiting_oauth_and_restart`.
- **Phase 2** — Content seeding. After OAuth + restart, the user runs `/thinkos-continue`. The agent follows `docs/phase-2-seeding-playbook.md` and *does* read from connectors — but only with per-source consent, only the minimum needed, and only drafts content (the user approves before each commit).

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
  --products claude-code,codex \
  --install-basic-memory \
  --yes
```

Then verify:

```bash
scripts/thinkos-doctor.sh \
  --os-home "$HOME/ThinkOS/vault" \
  --deep \
  --products claude-code,codex
```

Add `claude-cowork` to `--products` when the user uses Claude Cowork. Its MCP registration is UI-managed, so the script prepares copy/paste instructions rather than controlling the app.

## Product Routing

- Claude Cowork: UI-managed MCP. Generate instructions and walk the user through Cowork settings.
- Claude Code CLI: user-scope MCP, global `~/.claude/CLAUDE.md`, optional slash commands.
- Codex: global MCP and `~/.codex/AGENTS.md`.

## Safety

- Keep the recommended vault path local: `~/ThinkOS/vault`.
- If the user chooses Documents, Desktop, Downloads, or an external/cloud folder, explain that macOS permissions may require Files/Folders or Full Disk Access.
- Draft instructions and config changes for user approval when a product cannot be automated.
- If a command fails, run the doctor script again and report the smallest actionable next step.

## Multi-vault awareness

Think OS supports multiple vaults: one personal hub plus zero-or-more project vaults (shared via git) plus reference vaults (read-only). When operating in any session:

1. Check `~/.thinkos/vaults.json` for the registry. If absent, single-vault legacy mode.
2. Determine active vault (sticky override at `~/.thinkos/active-vault`, else CWD-derived, else default).
3. Mention the active vault in your first response: `Active vault: <id>. Personal hub always loaded.`
4. Always load personal hub HOT-tier (Identity, Current Focus). Layer in project HOT (Project Home, Roster) if a project vault is active.
5. Route writes per design doc §8: personal markers → personal hub regardless; schema mismatch → personal hub; team activity → project vault; ambiguous → ask.

The full design is at `docs/multi-vault-architecture.md`. Use `scripts/thinkos-vault.sh` to manage the registry; never edit `~/.thinkos/vaults.json` by hand.
