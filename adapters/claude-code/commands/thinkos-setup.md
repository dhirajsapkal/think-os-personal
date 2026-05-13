---
description: Run the Think OS first-time setup wizard from Claude Code
permalink: think-os/adapters/claude-code/commands/thinkos-setup
---

Set up Think OS end-to-end. Two paths — let the user pick:

1. Confirm the current working directory is the Think OS export repo by checking for:
   - `scripts/thinkos-doctor.sh`
   - `scripts/thinkos-setup.sh`
   - `scripts/thinkos-wizard.sh`

   If not in the repo, ask for the path to the downloaded Think OS export repo.

2. Offer the user two setup paths:

   > I can set up Think OS two ways. Which do you prefer?
   >
   > **A. Run the interactive wizard in your terminal** — a guided DOS-style
   >    installer that walks you through every choice with clear screens.
   >    Open a new terminal in this repo and run:
   >
   >       bash scripts/thinkos-wizard.sh           # apply at the end
   >       bash scripts/thinkos-wizard.sh --preview # walk through, no changes
   >
   > **B. Walk through it here in chat** — I'll ask each question and run the
   >    commands for you. Slightly less theatrical but works inside this session.

   If the user picks A: print the exact command, then stop. They drive from their own shell.

   If the user picks B: continue with steps 3–7 below.

3. Follow `docs/agent-setup-playbook.md`.

4. Ask the setup choices one at a time (mirroring the wizard's order — do NOT pre-select):
   - **Vault path** — suggest `~/ThinkOS/vault` as default.
   - **Products** — ask Y/N separately for claude-code, claude-cowork, codex.
   - **Basic Memory** — if `command -v basic-memory` succeeds, tell the user it's already there. Otherwise offer to install via `uv tool install basic-memory`.
   - **Bundle preset** — present the four named presets (pm / eng / design / ops) plus "skip", with a one-line summary of what each contains.

5. Summarize the choices and ask: "Apply this plan? (yes / change something / abort)" — wait for an explicit yes.

6. After approval, run the apply pipeline:

```bash
scripts/thinkos-doctor.sh --json --os-home "<vault-path>" --products "<products>"
scripts/thinkos-setup.sh --os-home "<vault-path>" --products "<products>" --install-basic-memory --yes [--bundle <preset>]
scripts/thinkos-doctor.sh --deep --os-home "<vault-path>" --products "<products>"
```

Use the scripts instead of manually probing files. Do not read the user's live vault content during setup unless they explicitly ask.

7. After the setup script completes successfully, offer the bundle picker (skip this step if a `--bundle` flag was already passed to `thinkos-setup.sh`). Tell the user:

   "Pick a plugin bundle to install (you can always run this later):
    1) pm    — Product management stack: Slack, Gmail, Notion, Linear, Granola, Figma, + PM and Productivity skills
    2) eng   — Engineering stack: Slack, Gmail, Atlassian Rovo, Linear, + Engineering and Productivity skills
    3) design — Design stack: Slack, Gmail, Notion, Figma, Granola, + Design and Productivity skills
    4) ops   — Operations stack: Slack, Gmail, Microsoft 365, Notion, QuickBooks, + Productivity skills
    5) custom — Choose individual items from the full catalog
    6) skip   — I'll do this later"

   Based on the user's choice:

   a) If 1–4: run `scripts/thinkos-install-bundle.sh --target claude-code --preset <name> --yes` and show its output.

   b) If 5 (custom): run `scripts/thinkos-install-bundle.sh --target claude-code --all --dry-run --skip-platform-check --yes` to enumerate available items. Present them grouped by category with index numbers. Ask the user to enter comma-separated index numbers or ids. Then run `scripts/thinkos-install-bundle.sh --target claude-code --items <resolved-ids> --yes`.

   c) If 6 (skip): say "OK — run this any time with: `scripts/thinkos-install-bundle.sh --target claude-code --preset <name>`"

   d) After any install (choices 1–5), show the OAuth checklist that the installer printed and remind the user to complete browser auth for each flagged item before using those tools.
