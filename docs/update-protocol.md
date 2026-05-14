# Think OS — Update Protocol

How a Think OS install is kept current without re-running the install wizard, without losing user state, and without ever touching user content.

This document is the canonical reference. The `/thinkos-update` slash-command playbook is the operational walkthrough; `setup/manifest.yaml` is the machine-readable schema; this doc explains the model behind both.

---

## 1. File categories

Think OS owns three categories of files on a user's machine. The category determines what happens on update.

| Category | Examples | On update |
|---|---|---|
| **Managed** — files Think OS writes during install | `~/.claude/CLAUDE.md` BEGIN/END block, `~/.claude/commands/thinkos-*.md`, `~/.codex/AGENTS.md` BEGIN/END block | Re-applied from repo if the on-disk file matches the SHA shipped at the user's current version. If it differs (user edited it), drift handling kicks in. |
| **State** — bookkeeping owned by Think OS but mutated by normal use | `~/.thinkos/vaults.json`, `~/.thinkos/active-vault`, `~/.thinkos/wizard-state.json`, `~/.thinkos/install-manifest.json` | Left alone unless a schema migration applies. Migrations are explicit, versioned, and listed in `setup/manifest.yaml` → `migrations`. |
| **User content** — the user's vault and everything in it | `~/ThinkOS/vault/`, any project vault path registered in `vaults.json`, work logs, decisions, identity, anything inside a vault | **Never touched.** Read-only to the update flow, period. |

The boundary between the first two categories is: a managed file is replaced wholesale (block or whole-file); a state file is migrated in place with a one-shot transform.

---

## 2. Versioning

Think OS uses commit SHAs as the canonical version identifier, with optional semver tags for the stable channel.

- `VERSION` in the repo root holds the current semver (e.g., `0.3.3`).
- `git rev-parse HEAD` in the user's local repo is the precise installed version.
- `~/.thinkos/install-manifest.json` records `thinkos_version` (the SHA) and `channel`.

There is no remote update server. All comparisons are local-git operations against the user's clone of the repo plus `git fetch`.

---

## 3. Channels

Two channels, both served from the same repo:

- **`stable`** (default) — latest tagged release. `/thinkos-update` resolves to the latest `vX.Y.Z` tag on origin.
- **`next`** — latest commit on `origin/main`. Opt-in via `/thinkos-update --channel next`. Tracked persistently in `install-manifest.json` so subsequent updates stay on the same channel until the user opts out.

Channel switch is just a checkout: `git checkout v0.4.0` for stable, `git checkout main` for next. No special tooling.

---

## 4. Drift detection

A managed file is *drifted* when its current sha256 differs from the `shipped_sha` recorded at the user's currently-installed version.

The update flow records, for each managed file at install/update time:

```json
{
  "id": "claude-code-commands/thinkos-vault.md",
  "target": "/Users/dhiraj/.claude/commands/thinkos-vault.md",
  "shipped_sha": "a1b2…",        // sha256 of the file as shipped at the installed version
  "current_sha": "a1b2…"          // sha256 on disk at last write (informational)
}
```

On update, recompute `sha256(target)`:

- `sha256(target) == shipped_sha` → **clean**. Overwrite freely.
- `sha256(target) != shipped_sha` → **drift**. The user (or another process) edited it. Ask before overwriting.
- `target` missing → **gone**. Reinstall fresh.

Drift handling is per-file. The user's choices for one drifted file don't apply to others.

Backups go to `~/.thinkos/backups/<ISO-timestamp>/<relative-path>`, preserving directory structure. Plain files, no special format — restore is `cp`.

---

## 5. Managed-file modes

Two modes, declared per entry in `setup/manifest.yaml`:

- **`block`** — the file may exist for other reasons (user has their own `~/.claude/CLAUDE.md`). Think OS owns only the content between `<!-- BEGIN THINK OS -->` and `<!-- END THINK OS -->`. The update re-renders the block from `templates/instructions/*` and the adapter's `instructions.md`, then splices it back. Drift detection compares only the block, not the whole file.

- **`file`** — Think OS owns the whole file (e.g., a slash command). The update replaces it wholesale. Drift detection compares the whole file.

A third synthetic mode, **`file_dir`** (a glob over a directory), is treated as a set of `file` entries — one drift check per file, one backup per file.

---

## 6. Install manifest schema

```json
{
  "version": 2,
  "thinkos_version": "abc1234…",
  "channel": "stable",
  "installed_at": "2026-05-13T22:53:49Z",
  "last_updated_at": "2026-05-14T09:00:00Z",
  "repo_path": "/Users/dhiraj/code/think-os",
  "vault_path": "/Users/dhiraj/ThinkOS/vault",
  "bm_project": "think-os",
  "bundle": "design",
  "products": ["claude-code", "codex"],
  "managed_files": [
    {
      "id": "claude-code-block",
      "target": "/Users/dhiraj/.claude/CLAUDE.md",
      "mode": "block",
      "shipped_sha": "…",
      "current_sha": "…"
    },
    {
      "id": "claude-code-commands/thinkos-vault.md",
      "target": "/Users/dhiraj/.claude/commands/thinkos-vault.md",
      "mode": "file",
      "shipped_sha": "…",
      "current_sha": "…"
    }
  ],
  "optional_capabilities": ["gh_cli"],
  "mcps": { "claude-code": ["basic-memory", "slack", "gmail"], "codex": ["basic-memory"] },
  "plugins": []
}
```

**Migration from v1 to v2:** `version: 1` manifests (existing installs) lack `thinkos_version`, `channel`, `managed_files`, `repo_path`, `optional_capabilities`. The first `/thinkos-update` on a v1 manifest:

1. Reads `repo_path` from the user (or defaults to `~/code/think-os`).
2. Sets `thinkos_version` to the user's current HEAD.
3. Sets `channel` to `stable`.
4. Walks the managed-file list from `setup/manifest.yaml` and records `shipped_sha = current_sha = sha256(target)` for each. (This assumes the user hasn't edited anything since install — if they have, it gets baked in as "clean.")
5. Sets `optional_capabilities` to `[]`.
6. Bumps `version` to `2`.

This is a one-way migration. No rollback.

---

## 7. Schema migrations

For breaking changes to a state file (`vaults.json`, `install-manifest.json`, etc.), declare a migration in `setup/manifest.yaml` → `migrations`:

```yaml
migrations:
  - from_version: 1
    to_version: 2
    target: install-manifest.json
    description: "Add managed_files tracking with sha256 drift detection."
    playbook: docs/migrations/install-manifest-v1-to-v2.md
```

`/thinkos-update` runs any migration whose `from_version` matches the user's current state-file version, in order. Migrations are executable playbooks (markdown the agent follows), not opaque scripts — they should be reviewable by the user before running.

The migration playbook owns its own backup: every state file gets copied to `~/.thinkos/backups/<timestamp>/state/` before transformation.

---

## 8. What update does NOT do

- It does not re-install Basic Memory.
- It does not re-register MCP servers.
- It does not re-run the install wizard.
- It does not change the user's vault path.
- It does not install or update plugin bundles. (Use `bash scripts/thinkos-install-bundle.sh` for that.)
- It does not pull from any remote other than the user's existing `origin`.

If any of those are needed, the user runs the appropriate dedicated command. The update flow is intentionally narrow.

---

## 9. Failure modes

| Failure | Behavior |
|---|---|
| `git fetch` fails (no network) | Stop; tell the user. No partial state. |
| `git pull --ff-only` fails (non-fast-forward — user committed locally) | Stop; tell the user to handle their local commits first. |
| Repo has uncommitted changes | Stop; surface `git status` output. Don't auto-stash. |
| User cancels mid-update | The script writes files atomically (`tmp + mv`) — partial writes don't happen. Whatever has been written stays; the manifest is only updated at the end, so a half-applied update can be re-run cleanly. |
| Migration playbook errors | The state file's pre-migration backup is in `~/.thinkos/backups/<timestamp>/state/`. Restore is `cp`. |

---

## 10. Comparison to install

| | Install | Update |
|---|---|---|
| Reads `setup/manifest.yaml` | Yes (questions + capabilities) | Yes (managed files + migrations) |
| Asks user questions | 4 install questions + Phase 1.5 capabilities | 1–2 (drift handling, channel, go-ahead) |
| Touches vault | Creates vault directory, copies templates | Never |
| Touches state | Creates `vaults.json`, `wizard-state.json`, `install-manifest.json` | Reads all three; rewrites only `install-manifest.json` (and any migration target) |
| Touches managed files | Writes them | Re-writes them subject to drift |
| Requires restart | Yes (post-install) | Yes (post-update) |
| Idempotent | Yes | Yes |

Re-running `/thinkos-update` after a successful update is a no-op (everything is clean and at the target version).
