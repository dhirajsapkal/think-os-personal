---
description: Update Think OS in place — pull latest curated instructions, commands, and skills without touching your vault
permalink: think-os/adapters/claude-code/commands/thinkos-update
---

You are running an **in-place update** of Think OS for the user. Goal: pull the latest curated instructions, slash commands, and managed files from the repo and re-apply them on the user's machine without re-running the install wizard and without ever touching the user's vault content.

The canonical design lives in `docs/update-protocol.md`. Read it if you hit anything this playbook doesn't cover.

---

## Step 0 — Locate the repo

The user's local repo lives wherever they cloned it. Check the install manifest first:

```bash
python3 -c "import json; print(json.load(open('$HOME/.thinkos/install-manifest.json')).get('repo_path', ''))" 2>/dev/null
```

If empty, fall back to `~/code/think-os` (the install playbook's default). If that's missing too, ask the user.

If the repo isn't a git checkout, tell the user the update flow needs a git checkout (not a tarball download) and stop.

---

## Step 0.5 — Migrate manifest v1 → v2 if needed

If `~/.thinkos/install-manifest.json` is `version: 1` (no `managed_files` array, no `thinkos_version`), drift detection isn't possible until it's migrated. Run:

```bash
bash "$REPO_PATH/scripts/thinkos-migrate-manifest-v1-to-v2.sh" --dry-run
```

Show the user what would change, then ask:

`AskUserQuestion`:

- Header: "Migrate manifest"
- Question: "Your install manifest is v1. Migrate to v2 now so drift detection works?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Migrate now" | "Bakes current installed-file SHAs as the baseline. Backups the v1 file. ~1 second." |
  | "Skip" | "Continue without drift detection for this update." |

On "Migrate now", run without `--dry-run`. On "Skip", carry on but warn that Step 3 will be skipped.

---

## Step 1 — Fetch latest

```bash
cd "$REPO_PATH"
git fetch origin
```

Read the channel from `~/.thinkos/install-manifest.json`:

- `channel: "stable"` (default) → compare against the latest `vX.Y.Z` tag.
- `channel: "next"` → compare against `origin/main`.

```bash
CURRENT="$(git -C "$REPO_PATH" rev-parse HEAD)"
LATEST="$(git -C "$REPO_PATH" rev-parse origin/main)"  # or the latest tag for stable
```

Also check the working tree state — uncommitted local work won't show up in the SHA comparison:

```bash
DIRTY="$(git -C "$REPO_PATH" status --short | wc -l | tr -d ' ')"
```

If `CURRENT == LATEST` AND `DIRTY == 0`, tell the user "Think OS is up to date." and stop.

If `CURRENT == LATEST` AND `DIRTY > 0`, the user has uncommitted work that may already have been applied locally via `thinkos-update.sh --skip-pull`. Tell them:

> Up to date with origin. But you have `<N>` uncommitted local files — if you've already run `--skip-pull`, your install is ahead of remote. Commit and push to propagate to other machines. Drift detection (Step 3) still works against your local files.

Then continue to Step 3 (skip Step 2 — no commits to summarize).

If `CURRENT != LATEST`, continue to Step 2 normally.

---

## Step 2 — Show what changed

```bash
git -C "$REPO_PATH" log --oneline "$CURRENT..$LATEST"
git -C "$REPO_PATH" diff --stat "$CURRENT..$LATEST" -- adapters/claude-code/ templates/instructions/ setup/manifest.yaml
```

Group the changes for the user — don't dump the raw diff. Aim for three lines max:

> Available update: `abc1234` → `def5678` (3 commits)
>
> - Commands: 2 updated, 1 new (`thinkos-update`)
> - Curated instructions: 1 changed (token-efficiency rules)
> - Vault content: untouched (Think OS never modifies your vault)

If the user wants the full diff, link them to `git -C "$REPO_PATH" diff "$CURRENT..$LATEST"` rather than pasting it.

---

## Step 3 — Detect drift on managed files

Read `setup/manifest.yaml` → `managed_files` (the list of files Think OS owns on the user's machine). For each entry, compute the current sha256 on disk and compare to the `shipped_sha` recorded in `~/.thinkos/install-manifest.json`.

Three states per file:

- **Clean** — disk matches `shipped_sha`. Safe to overwrite.
- **Drift** — disk differs from `shipped_sha`. The user edited it. Don't overwrite without asking.
- **Missing** — disk file doesn't exist. Treat as clean; install fresh.

If any drift is detected, distinguish two cases:

**System-caused drift** — likely if the manifest's `last_updated_at` is recent (within the last ~30 days) and there's no obvious reason the user would have edited the file. Mention this in the question so the user can pick the no-backup option without guilt:

> Note: this drift may be system-caused (prior `--skip-pull` runs touched the file without refreshing the baseline). If you haven't manually edited it, the backup is mostly noise — pick "Just replace, no backup."

`AskUserQuestion`:

- Header: "Drift detected"
- Question: "`<file path>` differs from the shipped baseline. What should I do?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Back up and replace" | "Save your version to `~/.thinkos/backups/<timestamp>/` and apply the new one. Safe default." |
  | "Just replace, no backup" | "Skip the backup. Use when you know the drift is system-caused or you don't need to preserve the local version." |
  | "Keep mine" | "Skip this file. The new version is not applied." |
  | "Show diff first" | "Print the diff so I can decide." |

---

## Step 4 — Ask for the go-ahead

`AskUserQuestion`:

- Header: "Apply update?"
- Question: "Apply the update now?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Apply now" | "Re-apply all clean files. Drifted files use the choices above." |
  | "Show me the full diff" | "Print the cross-commit diff before deciding." |
  | "Cancel" | "Don't update. Nothing changes." |

---

## Step 5 — Apply

1. `git pull --ff-only` (or `git checkout <tag>` for stable channel).
2. Run `bash scripts/thinkos-update.sh --skip-pull` to re-apply curated instructions blocks and slash commands. The script is idempotent.
3. For any file the user chose "Back up and replace", copy the user's current file to `~/.thinkos/backups/<ISO-timestamp>/<relative-path>` before the script writes.
4. Update `~/.thinkos/install-manifest.json`:
   - bump `thinkos_version` to the new commit SHA
   - refresh each managed file's `shipped_sha` and `current_sha` to the post-write sha256
   - set `last_updated_at` to now (UTC)
5. Run any pending entries in `setup/manifest.yaml` → `migrations` whose `from_version` matches the user's prior version. (As of v1, none exist. If the list is empty, skip this step.)

---

## Step 6 — Wrap up

Tell the user, in three short lines:

> Updated to `<new SHA>` on the `<channel>` channel.
> Your vault was not touched.
> Restart Claude Code (Cmd+Q, reopen) to load the new commands and instructions.

If any drift was kept, append:
> Backed-up versions of your edited files live in `~/.thinkos/backups/<timestamp>/`.

---

## Hard rules

- **Never touch the user's vault.** Not the vault directory, not `vaults.json` (state only), not `wizard-state.json`, not any file inside a vault path listed in `vaults.json`.
- **Never run `git reset --hard` or `git clean -f`** in the user's repo. If the repo has uncommitted changes, stop and tell the user — don't paper over it.
- **Never skip the drift check.** Even if you're sure nothing changed, run it. Cheap to run; expensive to overwrite the user's work.
- **Restart is mandatory after update.** Tell the user every time — Claude Code only re-reads `~/.claude/CLAUDE.md` and the commands directory on launch.

---

## Recovery

If something went wrong mid-update, the user runs:

```bash
ls ~/.thinkos/backups/
```

To restore a single file: copy from `~/.thinkos/backups/<timestamp>/<relative-path>` back to its original location. No special undo command needed — backups are plain files.
