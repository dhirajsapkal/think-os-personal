# Think OS Agent Guide

Use this file when you are an agent helping someone install, inspect, or improve Think OS.

## Read First

1. `README.md` for the product overview.
2. `docs/agent-setup-playbook.md` for first-run setup behavior.
3. `adapters/README.md` to pick the user's tool path.
4. The selected adapter only:
   - `adapters/claude-cowork/README.md`
   - `adapters/claude-code/README.md`
   - `adapters/codex/README.md`

Do not read every template file by default. Use `scripts/thinkos-doctor.sh --json` for setup state.

## Setup Principle

Be a guided installer, not a scavenger hunt.

- Ask for only the choices needed: vault location, products to configure, whether to install missing dependencies.
- Use native interactive controls if the host app supports them: choice chips, forms, checkboxes, or quick-pick lists.
- If rich controls are unavailable, ask one concise question at a time.
- Run scripts for checks and setup. Avoid manually scraping the user's home folder or reading their vault contents.
- Never overwrite a user's existing knowledge files. The setup script copies missing templates only.

## Token Efficiency

- Prefer `scripts/thinkos-doctor.sh --json --products <list>` over exploratory shell commands.
- Prefer `scripts/thinkos-setup.sh --products <list> --yes` over hand-running each step.
- Do not load the live vault content during setup unless the user asks you to inspect their actual notes.
- Do not read connector data, email, calendar, Slack, or project tracker content during installation.

- After basic setup, offer the bundle wizard (`--bundle <preset>`); see `data/plugin-catalog.yaml`.

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
