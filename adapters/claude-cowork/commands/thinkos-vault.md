---
description: Manage Think OS vaults — create, clone, switch, add reference, or remove
permalink: think-os/adapters/claude-cowork/commands/thinkos-vault
---

Manage Think OS vaults. Canonical reference: `docs/multi-vault-architecture.md`.

## Step 0 — Confirm repo access

Check that `scripts/thinkos-vault.sh` exists (via bash tool or by asking the user). If the scripts directory is not accessible, ask the user for the absolute path to the Think OS export repo and use it as the prefix for all script calls below.

## Step 1 — List current vaults

```bash
bash scripts/thinkos-vault.sh list
```

Show the output. If `~/.thinkos/vaults.json` doesn't exist yet, the script auto-registers the existing personal vault (or reports none). Relay whatever it prints.

## Step 2 — Ask what the user wants to do

Use `AskUserQuestion` (`multiSelect: false`):

```
header: "What would you like to do with your vaults?"
options:
  - Create a new project vault
  - Clone an existing project vault from a git URL
  - Add a reference vault (read-only)
  - Switch the active vault
  - Remove a vault from the registry
```

Then follow the matching branch below.

---

## Branch 1 — Create new project vault

Collect answers via `AskUserQuestion` one at a time (Cowork renders each as its own prompt):

**Q1** — Project id name (must match `[a-z0-9-]+`, e.g. `argenx-team`).

**Q2** — Human-readable label (e.g. "Argenx Team OS").

**Q3** — Local path. Suggest `~/ThinkOS/projects/<name>/` as the default. If `~/Documents/Think/` exists on this machine, also offer `~/Documents/Think/<Label>/team-os/` as an alternative. Include a free-text option.

**Q4** (`multiSelect: false`) — "Set up a git remote now?"
- Yes — enter a remote URL
- Yes — create a new private GitHub repo via `gh`
- No — skip for now

If the user chooses a `gh` option:

- Run: `command -v gh && gh auth status`
- If either fails: tell the user to run `bash scripts/thinkos-git.sh setup-gh` in their terminal and confirm when done. Re-run checks before continuing.
- Then ask for `<org>/<repo-name>` to pass to `gh repo create`.

Once all inputs are gathered:

```bash
bash scripts/thinkos-vault.sh create-project <name> \
  --label "<label>" \
  --path "<path>" \
  [--remote <url-or-gh-shorthand>]
```

Show all output. Confirm the new vault appears in `list`. End: "Vault `<name>` created. Teammates can join with `thinkos vault clone <remote-url>` (or `/thinkos-vault` in their agent)."

---

## Branch 2 — Clone existing project vault

Use `AskUserQuestion` (`multiSelect: false`) to collect:

**Q1** — Git URL (e.g. `git@github.com:thinkco/argenx-os.git`).

**Q2** — Local path. Default `~/ThinkOS/projects/<derived-name>/` (strip `.git` from the last URL segment).

Pre-flight git checks:

```bash
bash scripts/thinkos-git.sh check-or-install
bash scripts/thinkos-git.sh check-auth
```

If either fails, surface the error and tell the user what to run in their terminal:

- Missing git: `brew install git`
- Missing git config: `git config --global user.name/email`
- SSH auth failed: `bash scripts/thinkos-git.sh setup-ssh`
- `gh` auth failed: `bash scripts/thinkos-git.sh setup-gh`

Ask them to confirm the fix is done, then re-run the checks before continuing.

Once checks pass:

```bash
bash scripts/thinkos-vault.sh clone <url> --path "<path>"
```

Show output verbatim. If the script reports "this doesn't look like a Think OS project vault": relay that message, then use `AskUserQuestion` (`multiSelect: false`):

```
header: "This doesn't look like a Think OS project vault. Register it as a read-only reference vault instead?"
options:
  - Yes, register as reference vault
  - No, cancel
```

If yes: drop to Branch 3 with this path.

End: "Vault `<derived-name>` cloned and registered. Run `git pull` inside `<path>` to stay in sync with teammates."

---

## Branch 3 — Add reference vault

Use `AskUserQuestion` (`multiSelect: false`) to collect the path to the existing folder.

Then ask for a label (short display name, e.g. "Material Design Docs") — either via another `AskUserQuestion` or as a free-text follow-up.

```bash
bash scripts/thinkos-vault.sh add-reference "<path>" --label "<label>"
```

Show output. End: "Registered `<label>` as a read-only reference vault. The agent will mark results from it as `[reference]`."

---

## Branch 4 — Switch active vault

Show the vault list:

```bash
bash scripts/thinkos-vault.sh list
```

Use `AskUserQuestion` (`multiSelect: false`) with each registered vault id as an option:

```
header: "Which vault should become active?"
options: <one option per vault id, e.g. "personal — Dhiraj's Think OS", "argenx-team — Argenx Team OS">
```

```bash
thinkos vault use <chosen-id>
```

Show output. End: "Active vault is now `<chosen-id>`. Your agent will surface this in its first response next session."

---

## Branch 5 — Remove a vault

Show the vault list:

```bash
bash scripts/thinkos-vault.sh list
```

Use `AskUserQuestion` (`multiSelect: false`) with each registered vault id as an option:

```
header: "Which vault should be removed from the registry?"
options: <one option per vault id>
```

Confirm with a second `AskUserQuestion` (`multiSelect: false`):

```
header: "This only removes the vault from the registry — files on disk are NOT deleted. Confirm?"
options:
  - Yes, remove from registry
  - No, cancel
```

If confirmed:

```bash
bash scripts/thinkos-vault.sh remove <id> --yes
```

Show output. End: "Removed `<id>` from the registry. Files at `<path>` are untouched."

---

## Error handling

- Surface all script error output verbatim — do not swallow or paraphrase.
- On unexpected exit codes, tell the user the exact command that failed and the error, then offer to retry or abort.
- If bash tools are unavailable in this Cowork session, ask the user to run the relevant command in their terminal and paste back the output.
