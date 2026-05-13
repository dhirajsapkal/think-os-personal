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

Use the richest interaction model the host app gives you.

If the app supports a form, quick-pick, buttons, checkboxes, or structured choices, collect these as one setup card:

| Field | Recommended default | Options |
|---|---|---|
| Vault location | `~/ThinkOS/vault` | Recommended local path / existing folder / custom path |
| Products | Current app + Codex if present | Claude Cowork / Claude Code CLI / Codex |
| Install Basic Memory if missing | Yes | Yes / No, show manual command |
| Register MCPs automatically | Yes | Yes / No, manual docs |
| macOS permissions path | Avoid protected folders | Use recommended path / open settings if needed |

If the app only supports plain chat, ask one short question at a time. Start with:

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
- selected products
- whether Basic Memory will be installed
- whether MCP registration can be automated

Then ask for approval before writing outside the repo.

### 3. Run Setup

Run:

```bash
scripts/thinkos-setup.sh \
  --os-home "<vault-path>" \
  --products "<selected-products>" \
  --install-basic-memory \
  --yes
```

Use `--skip-mcp` if the user wants manual product registration.

### 4. Verify

Run doctor again:

```bash
scripts/thinkos-doctor.sh \
  --os-home "<vault-path>" \
  --deep \
  --products "<selected-products>"
```

Then verify in the selected product:

```text
Use Basic Memory to answer: who am I and what am I working on?
```

Expected: a specific answer from `05 Profile/Identity.md` and `01 Now/Current Focus.md`. If those files still have placeholders, the agent should say setup is connected but the user still needs to fill in the HOT tier.

## Product Paths

### Claude Cowork

Cowork MCP registration is UI-managed.

The setup script writes:

- `~/.thinkos/claude-cowork-mcp.txt`
- `~/.thinkos/claude-cowork-instructions.md`

Guide the user to Cowork settings, add the Basic Memory MCP server, then paste the generated instructions into personalization/custom instructions.

### Claude Code CLI

Automatable pieces:

- `claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os`
- global instructions in `~/.claude/CLAUDE.md`
- slash commands in `~/.claude/commands/`

After setup, restart Claude Code and type `/` to confirm commands appear.

### Codex

Automatable pieces:

- `codex mcp add basic-memory -- basic-memory mcp --project think-os`
- global instructions in `~/.codex/AGENTS.md`

After setup, start a fresh Codex session outside the vault and ask the verification question.

## Permission Handling

The recommended path `~/ThinkOS/vault` usually avoids macOS privacy friction.

If the user insists on a protected location, do not try to bypass permissions. Explain what is happening and open the settings pane if they want:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
```

The user must grant access manually.

## Failure Recovery

Use this order:

1. `scripts/thinkos-doctor.sh --json --products <selected-products>`
2. Fix missing binary/project/MCP based on the first warning or failure.
3. `basic-memory reindex --project think-os`
4. Product-specific MCP list/get command:
   - `claude mcp list`
   - `codex mcp get basic-memory`
5. Fresh product session with the verification question.

Keep the user-facing explanation small: say what failed, why it matters, and the next command you are running.
