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

Tell the user once: "Cloned to `~/code/think-os/`. I'll walk you through the install."

**B. You're already inside a local checkout of the repo.** Skip the clone; you're ready.

Verify you're in the right place: `ls scripts/thinkos-setup.sh` should exist.

---

## Step 1 — Ask the user 5 questions, one at a time

Don't batch. Don't pre-fill from your guesses. Show the bracketed default and wait for each answer before asking the next.

### Question 1: Vault location

> Where should your Think OS vault live? **[~/ThinkOS/vault]**

Notes for you:
- Accept the default (press ENTER) or a custom path.
- Expand `~` to `$HOME` if the user typed it.
- Warn if the path is under `~/Documents`, `~/Desktop`, or `~/Downloads` — macOS protected folders that require Files & Folders access. Suggest `~/ThinkOS/vault` instead.

### Question 2: Install Basic Memory if missing

> Should I install Basic Memory via uv if it's missing? **[Y]**

Notes:
- Check first: `command -v basic-memory && command -v uv` — if both exist, tell the user it's already installed and skip the question.
- If basic-memory exists but uv doesn't, they're using a different install. Confirm with: "I see basic-memory at `$(which basic-memory)`. Use that?"

### Question 3: Plugin bundle

> Pick a plugin bundle to install with Think OS:
>   - **pm** — Product management stack: Slack, Gmail, Notion, Linear, Granola, Figma + PM and Productivity skills
>   - **eng** — Engineering: Slack, Gmail, Atlassian Rovo, Linear + Engineering and Productivity skills
>   - **design** — Design: Slack, Gmail, Notion, Figma, Granola + Design and Productivity skills
>   - **ops** — Operations: Slack, Gmail, Microsoft 365, Notion, QuickBooks + Productivity skills
>   - **skip** — install nothing now; the user can add later

Notes:
- If the user is unsure, suggest based on their role if you can infer it from context (you may have it from prior turns).
- Accept lowercase preset names or the literal word "skip".

### Question 4: Vault id

> What would you like to call your vault in commands? **[personal]**

Notes:
- Validate: must match `[a-z0-9-]+`. Reject capitals, spaces, special chars; ask again.
- Used as the registry key (e.g., `thinkos vault use <id>`).

### Question 5: Display label

> Display label for your vault? **[<name>'s Think OS]**

Notes:
- Default to `$(git config user.name)'s Think OS` if git is configured; otherwise `$(whoami)'s Think OS`.
- Free-form. Any text.

---

## Step 2 — Run the install

Construct the command from the user's answers:

```bash
bash scripts/thinkos-setup.sh \
  --os-home "<vault-path>" \
  --install-basic-memory \
  --yes \
  [--bundle <preset>]
```

Include `--bundle <preset>` only if the user picked pm/eng/design/ops. Omit if they picked skip.

If basic-memory turned out to be already installed (Step 1 detected it), drop `--install-basic-memory`.

Run the command. Show the output to the user as it streams. The script handles vault folder creation, template copy, Basic Memory project registration, `~/.claude/CLAUDE.md` block injection, slash command install, and (if bundled) Claude Code MCP registrations.

If the script fails: stop, surface the error verbatim, suggest the user run `bash scripts/thinkos-doctor.sh --deep` for diagnosis. Don't continue to Step 3 on failure.

---

## Step 3 — Register the vault in the registry

After setup.sh succeeds, run:

```bash
bash scripts/thinkos-vault.sh migrate \
  --id "<vault-id>" \
  --label "<display-label>"
```

This auto-detects the vault, registers it in `~/.thinkos/vaults.json`, and makes it the default active vault. Idempotent — re-running is safe.

---

## Step 4 — Show the user what landed

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
> Total cost across all four triggers: ~$5-15/month in API tokens.

---

## Step 5 — Quick verify

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
