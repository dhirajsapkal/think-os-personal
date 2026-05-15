---
description: Commit + pull --rebase + push your personal-hub vault state
permalink: think-os/adapters/claude-code/commands/thinkos-sync
---

You are running `/thinkos-sync`. Synchronize the user's personal-hub vault with its remote git repository: stage any local changes, commit them, pull the latest with rebase, then push.

## Step 1 — Resolve vault path

The script resolves the vault automatically (from `--vault` flag, `~/.thinkos/active-vault`, or `vaults.json`). Pass any flags the user supplied in `$ARGUMENTS` directly to the script.

## Step 2 — Run the sync script

```bash
bash scripts/thinkos-git.sh sync-vault $ARGUMENTS
```

Capture the exit code and the full output (stdout + stderr combined).

## Step 3 — Interpret the result

**Exit 0 — clean sync:**

Report in one line:

```
Vault synced. (or: Vault is up to date — nothing to push.)
```

Include a brief summary if the script's output mentions files committed (e.g. "3 files committed before push").

**Exit non-zero — conflict or push rejection:**

Surface the script's output verbatim (do not paraphrase or redact). Then append:

---

**Pause — conflicts above need a human.**

Recovery options:

- **Edit and re-sync:** Resolve the conflict markers in the listed files, save them, then run `/thinkos-sync` again.
- **Abort the rebase:** Run `git -C <vault-path> rebase --abort` to reset to the pre-sync state. Your local uncommitted changes will still be there.

Think OS never auto-resolves conflicts. The vault state is yours to decide.

---

## Flags

Any flags in `$ARGUMENTS` are passed through verbatim. Supported flags:

| Flag | Effect |
|---|---|
| `--vault <path>` | Sync a specific vault path instead of the default personal hub |
| `--message <msg>` | Custom commit message for local changes |
| `--dry-run` | Preview planned actions without executing any git commands |

## Example invocations

- `/thinkos-sync` — sync personal hub with default settings
- `/thinkos-sync --dry-run` — preview what would happen
- `/thinkos-sync --message "save before travel"` — custom commit message
- `/thinkos-sync --vault ~/work/team-vault` — sync a specific vault

User message: $ARGUMENTS
