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
