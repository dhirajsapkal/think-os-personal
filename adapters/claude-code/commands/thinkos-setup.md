---
description: Run the Think OS first-time setup wizard from Claude Code
permalink: think-os/adapters/claude-code/commands/thinkos-setup
---

Run the Think OS setup flow from the export repository.

1. Confirm the current working directory is the Think OS export repo by checking for:
   - `scripts/thinkos-doctor.sh`
   - `scripts/thinkos-setup.sh`
   - `docs/agent-setup-playbook.md`

2. If not in the repo, ask for the path to the downloaded Think OS export repo.

3. Follow `docs/agent-setup-playbook.md`.

4. Ask for the minimal setup choices:
   - vault path, default `~/ThinkOS/vault`
   - products to configure, default `claude-code`
   - whether to install Basic Memory if missing, default yes

5. Run:

```bash
scripts/thinkos-doctor.sh --json --os-home "<vault-path>" --products "<products>"
scripts/thinkos-setup.sh --os-home "<vault-path>" --products "<products>" --install-basic-memory --yes
scripts/thinkos-doctor.sh --deep --os-home "<vault-path>" --products "<products>"
```

Use the scripts instead of manually probing files. Do not read the user's live vault content during setup unless they explicitly ask.

6. After the setup script completes successfully, offer the bundle picker. Tell the user:

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
