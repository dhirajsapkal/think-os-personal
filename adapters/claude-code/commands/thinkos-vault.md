---
description: Manage Think OS vaults — create, clone, switch, add reference, or remove
permalink: think-os/adapters/claude-code/commands/thinkos-vault
---

Manage Think OS vaults. Canonical reference: `docs/multi-vault-architecture.md`.

## Step 0 — Confirm repo access

Check that `scripts/thinkos-vault.sh` exists. If not, ask the user for the path to the Think OS export repo and use it as the prefix for all script calls below.

## Step 1 — List current vaults

```bash
bash scripts/thinkos-vault.sh list
```

Show the output verbatim. If `~/.thinkos/vaults.json` doesn't exist yet, the script will auto-register the existing personal vault (or report none). Relay whatever it prints.

## Step 2 — Ask what the user wants to do

> What would you like to do?
>
> 1. Create a new project vault
> 2. Clone an existing project vault from a git URL
> 3. Add a reference vault (read-only)
> 4. Switch the active vault
> 5. Remove a vault from the registry

Wait for the user's choice, then follow the matching branch below.

---

## Branch 1 — Create new project vault

Ask in sequence (one question at a time):

1. **Project name** — must match `[a-z0-9-]+`. Example: `argenx-team`.
2. **Human-readable label** — e.g. "Argenx Team OS".
3. **Local path** — default `~/ThinkOS/projects/<name>/`. If `~/Documents/Think/` exists on this machine, also offer `~/Documents/Think/<Label>/team-os/` as an alternative. Wait for the user to confirm or enter a custom path.
4. **Git remote now or skip?** — ask Y/N. Default: N.

If the user wants a git remote (Y):

- Ask: "Enter a remote URL, OR type `gh` to create a new private repo on GitHub via `gh repo create`."
- If they enter a URL: use it directly.
- If they type `gh`:
  - Check: `command -v gh && gh auth status`
  - If either fails: tell the user to run `bash scripts/thinkos-git.sh setup-gh` in their terminal, then confirm when done before continuing.
  - Once gh is ready: ask for `<org>/<repo-name>` and note you'll run `gh repo create <org>/<repo-name> --private`.

Run:

```bash
bash scripts/thinkos-vault.sh create-project <name> \
  --label "<label>" \
  --path "<path>" \
  [--remote <url-or-gh-shorthand>]
```

Show all output verbatim. Then confirm the new vault appears:

```bash
bash scripts/thinkos-vault.sh list
```

End: "Vault `<name>` created. Teammates can join with: `thinkos vault clone <remote-url>` (or `/thinkos-vault` in their agent)."

---

## Branch 2 — Clone existing project vault

Ask in sequence:

1. **Git URL** — e.g. `git@github.com:thinkco/argenx-os.git`
2. **Local path** — default `~/ThinkOS/projects/<derived-name>/` (derive from the last segment of the URL, strip `.git`).

Pre-flight git check — run both:

```bash
bash scripts/thinkos-git.sh check-or-install
bash scripts/thinkos-git.sh check-auth
```

If either fails, surface the error line-for-line and tell the user:

- Missing git: run `brew install git` in their terminal.
- Missing git config: run `git config --global user.name "..."` and `git config --global user.email "..."`.
- SSH auth failed: run `bash scripts/thinkos-git.sh setup-ssh` in their terminal.
- `gh` auth failed: run `bash scripts/thinkos-git.sh setup-gh` in their terminal.

Ask them to confirm the fix is done, then re-run the checks before continuing.

Once both checks pass:

```bash
bash scripts/thinkos-vault.sh clone <url> --path "<path>"
```

Show output verbatim. If the script reports "this doesn't look like a Think OS project vault": relay that message and ask: "Register it as a read-only reference vault instead? (Y/N)" — if Y, drop to Branch 3 with this path.

End: "Vault `<derived-name>` cloned and registered. Run `git pull` inside `<path>` to stay in sync with teammates."

---

## Branch 3 — Add reference vault

Ask:

1. **Path** to the existing folder.
2. **Label** — short display name, e.g. "Material Design Docs".

```bash
bash scripts/thinkos-vault.sh add-reference "<path>" --label "<label>"
```

Show output. End: "Registered `<label>` as a read-only reference vault. The agent will mark results from it as `[reference]`."

---

## Branch 4 — Switch active vault

Show the vault list again (already visible from Step 1, but re-run if needed):

```bash
bash scripts/thinkos-vault.sh list
```

Ask: "Enter the id of the vault to make active."

```bash
thinkos vault use <chosen-id>
```

Show output. End: "Active vault is now `<chosen-id>`. Your agent will surface this in its first response next session."

---

## Branch 5 — Remove a vault

Show:

```bash
bash scripts/thinkos-vault.sh list
```

Ask: "Enter the id of the vault to remove from the registry."

Confirm once: "This only removes the vault from the registry — your files on disk are not deleted. Confirm? (Y/N)"

If Y:

```bash
bash scripts/thinkos-vault.sh remove <id> --yes
```

Show output. End: "Removed `<id>` from the registry. Files at `<path>` are untouched."

---

## Error handling

- Surface all script error output verbatim — do not swallow or paraphrase.
- On unexpected exit codes, tell the user the exact command that failed and the error, then offer to retry or abort.
