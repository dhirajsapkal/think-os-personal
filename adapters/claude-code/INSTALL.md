---
type: agent-playbook
audience: ai-agent
permalink: think-os/adapters/claude-code/install
---

# Think OS — Install Playbook (for AI agents)

**If you're an AI agent installing Think OS for a user, this is the file you follow. Skip the rest of this repo's docs — they're human-facing reference. Everything you need is here.**

---

## Step 0 — Where are you?

Two possibilities:

**A. You're being run via a one-line user prompt like "Install Think OS for me from https://github.com/dhirajsapkal/think-os".** The user has NOT cloned the repo yet. Clone it:

```bash
mkdir -p ~/code && cd ~/code
git clone https://github.com/dhirajsapkal/think-os.git
cd think-os
```

Don't announce the clone — the welcome message in Step 1 mentions it.

**B. You're already inside a local checkout of the repo.** Skip the clone; you're ready.

Verify you're in the right place: `ls scripts/thinkos-setup.sh` should exist.

---

## Step 1 — Welcome the user

Before asking anything, show this welcome message verbatim:

> ## Welcome to Think OS
>
> Think OS gives me durable memory across every session — who you are, what you're working on, who you work with, and how you like to work. I'll have you set up in about five minutes.
>
> The repo is cloned to `~/code/think-os/`. I'll ask you five quick questions — each has a recommended default you can pick with a click, so you barely need to type.

---

## Step 2 — Ask 5 questions using AskUserQuestion

**Use the `AskUserQuestion` tool for every question.** Claude Code renders it as a chip-picker the user can click — no typing required to accept defaults. If `AskUserQuestion` isn't loaded yet, load it first via:

```
ToolSearch select:AskUserQuestion
```

Ask one question at a time. Wait for each answer before moving to the next.

**Important formatting rule for all questions below.** Each chip option has a `label` (one short phrase, shown ON the chip) and a `description` (one sentence, shown under or alongside the chip). Don't combine them into one string. Don't put dashes between preset keys and human names in the label — that causes duplicate-looking chips ("design-Design"). The user's pick is mapped to a preset key by you, internally.

### Question 1 of 5 — Vault location

`AskUserQuestion`:

- Header: "Vault location"
- Question: "Where should your Think OS vault live? Your vault is a folder of markdown files — identity, projects, decisions, work log."
- multiSelect: false
- Options (one chip per option; map the user's choice to the actual path internally):
  | label | description | maps to |
  |---|---|---|
  | "Recommended" | "Lives at ~/ThinkOS/vault. Clean local path; no macOS permission friction." | `~/ThinkOS/vault` |
  | "Under Documents" | "Lives at ~/Documents/ThinkOS. Convenient if you already keep notes there. May require Files & Folders access for Claude Code." | `~/Documents/ThinkOS` |
  | "Custom path" | "I'll specify a different location." | (follow-up free-text prompt) |

If the user picks "Custom path", follow up with a plain text prompt asking for the full path. Expand `~` to `$HOME`. Warn if the path is under `~/Documents`, `~/Desktop`, or `~/Downloads`.

### Question 2 of 5 — Basic Memory

First, check the local environment:

```bash
command -v basic-memory && command -v uv
```

If `basic-memory` already exists: tell the user "Basic Memory is already installed at `$(which basic-memory)`. I'll use that." Skip this question entirely.

If basic-memory is missing, use `AskUserQuestion`:

- Header: "Install Basic Memory?"
- Question: "Basic Memory is the MCP server that exposes your vault to me. It needs to be installed."
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Yes, install via uv" | "Recommended. Takes ~30 seconds." |
  | "Skip for now" | "Setup will continue, but I can't query your vault until you install Basic Memory manually later." |

### Question 3 of 5 — Plugin bundle

`AskUserQuestion`:

- Header: "Plugin bundle"
- Question: "Think OS can install a curated set of MCPs for you. Pick the bundle that matches your work — you can change later."
- multiSelect: false
- Options (chip `label` is human-readable; map to the preset key in your bundle install command):
  | label | description | maps to preset |
  |---|---|---|
  | "Product Management" | "Slack, Gmail, Notion, Linear, Granola, Figma + PM and Productivity skills." | `pm` |
  | "Engineering" | "Slack, Gmail, Atlassian Rovo, Linear + Engineering and Productivity skills." | `eng` |
  | "Design" | "Slack, Gmail, Notion, Figma, Granola + Design and Productivity skills." | `design` |
  | "Operations" | "Slack, Gmail, Microsoft 365, Notion, QuickBooks + Productivity skills." | `ops` |
  | "Skip" | "No bundle. Add individual tools later via `/thinkos-vault`." | (omit `--bundle` flag) |

### Question 4 of 5 — Vault id

`AskUserQuestion`:

- Header: "Vault name"
- Question: "What should I call this vault? It's the id you'll type in commands like `thinkos vault use <name>`."
- multiSelect: false
- Options:
  | label | description | maps to |
  |---|---|---|
  | "personal (work)" | "Your own vault, not shared with a team." | `personal` |
  | "Custom" | "Type your own id (lowercase letters, digits, hyphens)." | (follow-up free-text prompt, validate `[a-z0-9-]+`) |

### Question 5 of 5 — Display label

First, get the user's name:

```bash
git config user.name 2>/dev/null || whoami
```

Build the default label as `<that name>'s Think OS`.

`AskUserQuestion`:

- Header: "Display label"
- Question: "Friendly label shown when listing vaults. Just for your benefit."
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Use default" | The default label you computed (e.g., "Dhiraj's Think OS"). |
  | "Customize" | "I'll write my own label." (follow-up free-text prompt) |

---

## Step 3 — Run the install

Construct the command from the user's answers:

```bash
bash scripts/thinkos-setup.sh \
  --os-home "<vault-path>" \
  --install-basic-memory \
  --yes \
  [--bundle <preset>]
```

Include `--bundle <preset>` only if the user picked pm/eng/design/ops. Omit if they picked skip.

If basic-memory turned out to be already installed (Step 2 detected it), drop `--install-basic-memory`.

Run the command. Show the output to the user as it streams. The script handles vault folder creation, template copy, Basic Memory project registration, `~/.claude/CLAUDE.md` block injection, slash command install, and (if bundled) Claude Code MCP registrations.

If the script fails: stop, surface the error verbatim, suggest the user run `bash scripts/thinkos-doctor.sh --deep` for diagnosis. Don't continue to Step 4 on failure.

---

## Step 4 — Register the vault in the registry

After setup.sh succeeds, run:

```bash
bash scripts/thinkos-vault.sh migrate \
  --id "<vault-id>" \
  --label "<display-label>"
```

This auto-detects the vault, registers it in `~/.thinkos/vaults.json`, and makes it the default active vault. Idempotent — re-running is safe.

---

## Step 5 — Show the user what landed

Display the install manifest:

```bash
cat ~/.thinkos/install-manifest.json | python3 -m json.tool
```

Then present the post-install checklist as a clear numbered list. Emphasize these are not optional fluff — Phase 2 in particular is where Think OS actually becomes useful.

> ## ✦ INSTALL COMPLETE — 3 STEPS REMAIN
>
> ### Step A — Restart Claude Code right now
>
> Quit Claude Code (Cmd+Q) and reopen it. The new MCPs and slash commands won't load until you do.
>
> ### Step B — OAuth your connectors (only if you installed a plugin bundle)
>
> Open `claude`, type `/mcp`, and authorize each one. Items needing OAuth from your bundle:
>
> [list each item from the bundle's `oauth: true` entries in `data/plugin-catalog.yaml`]
>
> Without OAuth, those connectors are installed but can't read data.
>
> ### Step C — Run Phase 2 (context seeding) — DO THIS NEXT
>
> **This is the step that makes Think OS useful.** Without Phase 2, your vault is empty markdown templates and the agent has nothing personalized to read.
>
> In a fresh Claude Code session (after the restart in Step A), type:
>
> ```
> /thinkos-continue
> ```
>
> The agent will:
> - Ask you which project folders to scan (filesystem indexing — pure local, no LLM cost)
> - Ask permission per connector (Granola, Calendar, Slack, Gmail, Linear/Jira/ClickUp)
> - Pull data from consented sources, cache to disk, synthesize draft Identity / Project Index / Current Focus / People files
> - Show you each draft for review and edits before committing
>
> Plan ~15-30 minutes. You can pause and resume anytime — state is saved.
>
> ### Step D — (Optional but recommended) Set up automations
>
> After Phase 2, run:
>
> ```
> /thinkos-automate
> ```
>
> The agent will offer to set up scheduled triggers that keep your OS fresh: daily reindex, weekly Current Focus refresh, quarterly archive rotation, optional daily morning brief. These run remotely on Anthropic's infrastructure — your machine doesn't need to stay on.
>
> Each trigger fire uses Anthropic API tokens. Whether that's covered by your Claude subscription or counts as pay-as-you-go API spend depends on your account; check your plan.

---

## Step 6 — Quick verify

Run the doctor:

```bash
bash scripts/thinkos-doctor.sh --deep
```

Surface any FAIL or WARN results as a one-line punch list. If everything's green, tell the user: "Install complete. Restart Claude Code and try `/thinkos-help` to see your new commands."

---

## Notes for you (the agent)

- **Don't read every doc in this repo.** The user is waiting. This playbook plus `data/plugin-catalog.yaml` (only if they ask what's in a bundle) is enough.
- **Use bracketed defaults visibly.** Users skim. Showing `[~/ThinkOS/vault]` lets them just press ENTER.
- **One question at a time.** Batching feels like a form; one-at-a-time feels like a conversation.
- **Wait for the user's answer** before running anything. Don't pre-emptively run setup.sh until all 5 questions are answered.
- **Surface failures verbatim.** Don't paraphrase script errors — the user might recognize them.
- **The setup script is idempotent.** Re-running with the same args is safe; existing files aren't overwritten. If the user's machine has partial Think OS state from a prior attempt, just re-run.
- **OAuth steps are the user's responsibility.** The script can't authorize browser flows.
- **If anything in Step 1's question batch confuses the user**, they may ask "what's a vault id?" — answer briefly and re-ask the question. Don't read them the spec.

That's it. After Step 5, you're done. Stop unless the user has follow-up questions.
