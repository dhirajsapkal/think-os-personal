---
type: agent-playbook
tags:
- setup
- agents
- onboarding
- automation
permalink: think-os/agent-setup-playbook
---

# Agent Setup Playbook

This is the first-run flow for agents helping a user install Think OS.

The job: guide the user from "I downloaded Think OS" to "my chosen agent can read/write my vault through Basic Memory MCP."

## What To Read

Read only what you need:

1. `AGENTS.md`
2. `README.md`
3. This file
4. `adapters/README.md`
5. The selected adapter README(s)

Do not read all templates. Do not inspect the user's live vault content unless they ask.

## Native Chat UX

Ask one short question at a time. Start with:

```text
Where should your Think OS vault live? I recommend ~/ThinkOS/vault because it avoids macOS protected folders.
```

## Efficient Flow

### 1. Inspect State

Run:

```bash
scripts/thinkos-doctor.sh --json --products <selected-products>
```

Use the JSON summary to decide what is missing. Do not manually probe the same things unless the script output is unclear.

### 2. Confirm Choices

Summarize:

- vault path
- whether Basic Memory will be installed
- whether MCP registration can be automated
- whether a bundle preset was selected (and which one)

Then ask for approval before writing outside the repo.

### 3. Run Setup

Run:

```bash
scripts/thinkos-setup.sh \
  --os-home "<vault-path>" \
  --install-basic-memory \
  --yes
```

Use `--skip-mcp` if the user wants manual MCP registration.

### 4. Verify

Run doctor again:

```bash
scripts/thinkos-doctor.sh \
  --os-home "<vault-path>" \
  --deep
```

Then verify in the selected product:

```text
Use Basic Memory to answer: who am I and what am I working on?
```

Expected: a specific answer from `05 Profile/Identity.md` and `01 Now/Current Focus.md`. If those files still have placeholders, the agent should say setup is connected but the user still needs to fill in the HOT tier.

### 5. Install your stack

Think OS includes a curated plugin/connector bundle installer. After the basic MCP setup, offer the user a preset:

| Preset | Description |
|---|---|
| `pm` | Product management stack |
| `eng` | Engineering stack |
| `design` | Design stack |
| `ops` | Operations stack |

Run the setup script with a bundle flag:

```bash
scripts/thinkos-setup.sh --bundle pm
# or call the installer directly:
scripts/thinkos-install-bundle.sh --target claude-code --preset pm --yes
```

Use `--items id1,id2` to pick specific connectors; `--all` to install everything available. Run with `--dry-run` first to preview.

**OAuth** — connectors that need authorization are listed at the end of each install run. Opening the MCP tool for the first time in Claude Code also triggers the browser auth prompt automatically.

See `data/plugin-catalog.yaml` for the full item list and `scripts/thinkos-install-bundle.sh --help` for all options.

## Setup Details — Claude Code CLI

All pieces are automatable:

- `claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os`
- global instructions in `~/.claude/CLAUDE.md`
- slash commands in `~/.claude/commands/`

After setup, restart Claude Code and type `/` to confirm commands appear.

## Permission Handling

The recommended path `~/ThinkOS/vault` usually avoids macOS privacy friction.

If the user insists on a protected location, do not try to bypass permissions. Explain what is happening and open the settings pane if they want:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
```

The user must grant access manually.

## Failure Recovery

Use this order:

1. `scripts/thinkos-doctor.sh --json`
2. Fix missing binary/project/MCP based on the first warning or failure.
3. `basic-memory reindex --project think-os`
4. Verify MCP registration: `claude mcp list`
5. Fresh Claude Code session with the verification question.

Keep the user-facing explanation small: say what failed, why it matters, and the next command you are running.

---

## Setup flow reference (2+1 steps)

The current user-facing flow. See `README.md` for the canonical wording:

1. **Install** (~5 min) — 4 questions + optional Phase 1.5 capability add-ons (Playwright, GitHub CLI auth). This playbook covers that step.
2. **Restart + authenticate** (~2 min) — quit and reopen; run `/mcp` to authorize any bundle connectors.
3. **Context seeding** — the default is **emergent seeding** (`docs/emergent-seeding.md`): HOT files fill in from natural conversation over the first few sessions, no bulk connector reads required. Users with rich connector data can instead run `/thinkos-continue` for opt-in bulk-seed (Phase 2). See `docs/phase-2-seeding-playbook.md`.

After seeding, users can optionally set up Phase 3 automations (`/thinkos-automate`) and continuous capture (`/thinkos-autosave`, `/thinkos-capture-setup`). See `docs/phase-3-automations-playbook.md` and `docs/continuous-capture/README.md`.
