---
type: agent-playbook
audience: ai-agent
permalink: think-os/adapters/claude-code/install
---

# Think OS — Install Playbook (for AI agents)

**If you're an AI agent installing Think OS for a user, this is the file you follow. Skip the rest of this repo's docs — they're human-facing reference. Everything you need is here.**

The declarative schema for every question, optional capability, and managed file lives in `setup/manifest.yaml`. This playbook is the prose walkthrough; the manifest is the source of truth. If the two disagree, trust the manifest and fix the playbook.

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
- Question: "Where do you want your vault?"
- multiSelect: false
- Options:
  | label | description | maps to |
  |---|---|---|
  | "Recommended" | "~/ThinkOS/vault. Clean and out of the way." | `~/ThinkOS/vault` |
  | "Under Documents" | "~/Documents/ThinkOS. May need Files & Folders access." | `~/Documents/ThinkOS` |
  | "Custom path" | "Pick a different location." | (follow-up free-text prompt) |

If the user picks "Custom path", follow up with a plain text prompt asking for the full path. Expand `~` to `$HOME`. Warn if the path is under `~/Documents`, `~/Desktop`, or `~/Downloads`.

### Question 2 of 5 — Basic Memory

First, check the local environment:

```bash
command -v basic-memory && command -v uv
```

If `basic-memory` already exists: tell the user "Basic Memory is already installed. I'll use that." Skip this question entirely.

If basic-memory is missing, use `AskUserQuestion`:

- Header: "Install Basic Memory?"
- Question: "Do you want me to install Basic Memory?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Yes, install it" | "Takes about 30 seconds via uv." |
  | "Skip for now" | "I'll install it myself later." |

### Question 3 of 5 — Plugin bundle

`AskUserQuestion`:

- Header: "Plugin bundle"
- Question: "Which bundle do you want?"
- multiSelect: false
- Options (chip `label` is human-readable; map to the preset key in your bundle install command):
  | label | description | maps to preset |
  |---|---|---|
  | "Product Management" | "Slack, Gmail, Google Calendar, Google Drive, Notion, Granola, Figma + PM and Productivity skills." | `pm` |
  | "Engineering" | "Slack, Gmail, Google Calendar, Google Drive, Atlassian Rovo + Engineering and Productivity skills." | `eng` |
  | "Design" | "Slack, Gmail, Google Calendar, Google Drive, Notion, Figma, Granola + Design and Productivity skills." | `design` |
  | "Operations" | "Slack, Gmail, Google Calendar, Notion, QuickBooks + Productivity skills." | `ops` |
  | "Skip" | "Add tools individually later." | (omit `--bundle` flag) |

### Question 4 of 5 — Vault name

`AskUserQuestion`:

- Header: "Vault name"
- Question: "What do you want to call your vault?"
- multiSelect: false
- Options:
  | label | description | maps to |
  |---|---|---|
  | "personal (work)" | "Your own vault, not shared with a team." | `personal` |
  | "Custom" | "Pick your own id." | (follow-up free-text prompt, validate `[a-z0-9-]+`) |

### Question 5 of 5 — Where does your project work live?

Session capture only records Claude sessions whose working directory is inside your vault or a tracked project folder. This question sets that list, so capture works from day one instead of silently matching nothing.

`AskUserQuestion`:

- Header: "Work folders"
- Question: "Which folders hold the projects you work in? Claude sessions inside them get captured into your work log."
- multiSelect: true
- Options:
  | label | description | maps to |
  |---|---|---|
  | "~/code" | "A conventional code workspace." | `~/code` |
  | "~/Documents" | "Project work under Documents." | `~/Documents` |
  | "Custom path(s)" | "Name one or more folders." | (follow-up free-text prompt; accept several, comma- or space-separated) |
  | "Skip" | "Capture only sessions inside the vault itself." | (omit `--tracked-projects`) |

The selections (plus any custom paths) become the comma-separated value of `--tracked-projects` in Step 3. Tell the user they can change this later with `scripts/thinkos-vault.sh track <path>` / `untrack <path>`.

---

## Step 2.5 — Auto-generate the display label

Don't ask the user. Run:

```bash
git config user.name 2>/dev/null || whoami
```

Build the display label as `<that name>'s Think OS`. This is just a friendly string shown in `thinkos vault list`. The user can rename later via `/thinkos-vault` → "Rename a vault".

---

## Step 3 — Run the install

Construct the command from the user's answers:

```bash
bash scripts/thinkos-setup.sh \
  --os-home "<vault-path>" \
  --install-basic-memory \
  --yes \
  [--bundle <preset>] \
  [--tracked-projects "<path1,path2>"]
```

Include `--bundle <preset>` only if the user picked pm/eng/design/ops. Omit if they picked skip.

Include `--tracked-projects` with the comma-separated folders from Question 5. Omit it if the user picked Skip there.

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

## Step 4.5 — Optional capabilities

After the vault is registered but before the post-install checklist, offer optional capability add-ons. These are not part of core Think OS — they extend what Phase 2 seeding can pull from.

`AskUserQuestion`:

- Header: "Optional capabilities"
- Question: "Add any optional capabilities? Pick none, one, or more."
- multiSelect: true
- Options (full list defined in `setup/manifest.yaml` under `phases.optional_capabilities`):
  | label | description |
  |---|---|
  | "Browser capture" | "Install Playwright so Phase 2 can pull from your personal site, public Notion pages, or LinkedIn profile." |
  | "GitHub CLI (auth now)" | "Authenticate the GitHub CLI so project vaults, the self-healing feedback loop, and /thinkos-update all work without a second hop." |

For each selected capability, run the `install` block from the manifest, then the `verify` command. Surface failures verbatim; don't paper over them. If the user picks none, move on silently.

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
> ### Step C — Context seeding (two paths)
>
> **Default — emergent seeding.** Your vault starts with stub templates. The agent detects them and proposes facts turn-by-turn from natural conversation, with explicit per-fact approval. No bulk connector reads. Just start using Think OS — context fills in over the first few sessions. See `docs/emergent-seeding.md`.
>
> **Opt-in — bulk seed via `/thinkos-continue`.** If you have rich connector data (Slack, Granola, Calendar, Notion) and want to front-load your HOT files in one session, open a fresh Claude Code session and type:
>
> ```
> /thinkos-continue
> ```
>
> The agent will:
> - Offer to import from an existing markdown vault (Obsidian, old Think OS install, etc.)
> - Pull data from your consented connectors (Granola, Calendar, Slack, Gmail, Linear/Jira/ClickUp)
> - Synthesize drafts of Identity / Project Index / Current Focus / People files for your review
> - At the end, offer to set up scheduled triggers (daily reindex, weekly review, quarterly archive, optional morning brief) so your OS stays fresh on its own
>
> Plan ~15-30 minutes. You can pause and resume anytime.

---

## Step 6 — Quick verify

Run the doctor:

```bash
bash scripts/thinkos-doctor.sh --deep
```

Surface any FAIL or WARN results as a one-line punch list. If everything's green, tell the user: "Install complete. Restart Claude Code and try `/thinkos-help` to see your new commands."

---

## Step 7 — Offer the self-healing loop (only if gh CLI is authenticated)

If the user opted into "GitHub CLI (auth now)" in Step 4.5, *or* `gh auth status` already returned success at install time, end the install with this exact line:

> If anything in this install felt off — wrong command, missing step, confusing prompt — just tell me what happened. I'll open a PR upstream so the next person doesn't hit it.

Don't say it if `gh` isn't authenticated; the line is a promise you can't keep without it.

---

## Notes for you (the agent)

- **Don't read every doc in this repo.** The user is waiting. This playbook plus `data/plugin-catalog.yaml` (only if they ask what's in a bundle) is enough.
- **Use bracketed defaults visibly.** Users skim. Showing `[~/ThinkOS/vault]` lets them just press ENTER.
- **One question at a time.** Batching feels like a form; one-at-a-time feels like a conversation.
- **Wait for the user's answer** before running anything. Don't pre-emptively run setup.sh until all 5 questions are answered (the optional-capabilities multi-select comes after, in Step 4.5).
- **Surface failures verbatim.** Don't paraphrase script errors — the user might recognize them.
- **The setup script is idempotent.** Re-running with the same args is safe; existing files aren't overwritten. If the user's machine has partial Think OS state from a prior attempt, just re-run.
- **OAuth steps are the user's responsibility.** The script can't authorize browser flows.
- **If anything in Step 1's question batch confuses the user**, they may ask "what's a vault id?" — answer briefly and re-ask the question. Don't read them the spec.

That's it. After Step 5, you're done. Stop unless the user has follow-up questions.
