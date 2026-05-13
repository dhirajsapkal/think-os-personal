---
description: Manage Think OS vaults — create, clone, switch, add reference, or remove
permalink: think-os/adapters/claude-code/commands/thinkos-vault
---

Manage Think OS vaults. Canonical reference: `docs/multi-vault-architecture.md`.

## Critical UX rules

- **Use `AskUserQuestion` for every choice.** No free-text "type 1/2/3" prompts, no "Y/N for each" bullet lists. Load via `ToolSearch select:AskUserQuestion` if needed.
- **Run state-check shell commands silently.** Don't paste their output to the user unless something's broken.
- **One short message at a time.** No preambles, no recaps, no lectures.
- **Surface script errors verbatim.** When `thinkos-vault.sh` or `thinkos-git.sh` print errors, relay the exact text.

---

## Step 0 — Confirm repo access

Check that `scripts/thinkos-vault.sh` exists (silent — don't echo). If not, ask the user for the path to the Think OS export repo and use it as the prefix for all script calls below.

## Step 1 — Silent state read

Run `bash scripts/thinkos-vault.sh list` silently to know what's currently registered. Use this internally for chip options below. Don't paste raw output to the user unless they ask "what's currently registered?"

## Step 2 — Top-level picker

`AskUserQuestion`:
- Header: "Vault management"
- Question: "What do you want to do?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Create new project vault" | "Spin up a fresh project vault for your team." |
  | "Clone existing project vault" | "Pull a teammate's vault from a git URL." |
  | "Add reference vault" | "Register a folder of markdown as read-only context." |
  | "Switch active vault" | "Change which vault the agent treats as 'current'." |
  | "Remove a vault" | "Deregister a vault (files stay on disk)." |

Branch on the answer. The flows below all use `AskUserQuestion` for sub-choices.

---

## Branch 1 — Create new project vault

### 1a. Project name (free text)

Ask plainly: "What's the project name? Used as the vault id in commands. Lowercase letters, digits, hyphens only (e.g., `argenx-team`)."

Validate `[a-z0-9-]+`. Re-ask if invalid.

### 1b. Label (free text, with auto-default)

Default label is `<project name> Team OS` (title-cased). Ask: "Friendly label? (Enter to keep default: `<that>`)" — accept empty input as the default.

### 1c. Path (chip picker)

`AskUserQuestion`:
- Header: "Where should this vault live?"
- Question: "Where do you want the folder?"
- multiSelect: false
- Options (only include `~/Documents/Think/` if that folder exists):
  | label | description | maps to |
  |---|---|---|
  | "Default" | `~/ThinkOS/projects/<name>/` | `~/ThinkOS/projects/<name>` |
  | "Under Documents/Think" | `~/Documents/Think/<Label>/team-os/` | (computed) |
  | "Custom path" | "I'll specify." | (free-text follow-up) |

### 1d. Git remote (chip picker)

`AskUserQuestion`:
- Header: "Git remote"
- Question: "Set up a git remote now?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Skip for now" | "Local only. Add a remote later via `git remote add origin <url>`." |
  | "Paste a URL" | "I already have a repo URL." |
  | "Create on GitHub via gh" | "Make a new private repo for me." |

- "Paste a URL" → free-text prompt for the URL.
- "Create on GitHub via gh" → silently check `command -v gh && gh auth status`. If either fails: tell the user briefly to run `bash scripts/thinkos-git.sh setup-gh` in their terminal, then wait for confirmation. Once ready, ask for `<org>/<repo-name>` as a free-text prompt; you'll run `gh repo create <org>/<repo-name> --private` as part of the next command.

### 1e. Run create-project

```bash
bash scripts/thinkos-vault.sh create-project <name> \
  --label "<label>" \
  --path "<path>" \
  [--remote <url-or-gh-shorthand>] \
  --yes
```

Show output. After success, run `bash scripts/thinkos-vault.sh list` and show the result.

End with one line: "Vault `<name>` created. Teammates can join via `/thinkos-vault` → Clone → `<remote-url>`."

---

## Branch 2 — Clone existing project vault

### 2a. Git URL (free text)

Ask: "Git URL of the project vault?" (e.g., `git@github.com:thinkco/argenx-os.git`)

### 2b. Local path (chip picker)

Derive default name from the URL's last segment (strip `.git`).

`AskUserQuestion`:
- Header: "Where should it land?"
- Question: "Where do you want the clone?"
- multiSelect: false
- Options:
  | label | description | maps to |
  |---|---|---|
  | "Default" | `~/ThinkOS/projects/<derived-name>/` | (computed) |
  | "Custom path" | "I'll specify." | (free-text follow-up) |

### 2c. Pre-flight git check

Run silently:

```bash
bash scripts/thinkos-git.sh check-or-install
bash scripts/thinkos-git.sh check-auth
```

If either fails, show the error verbatim and `AskUserQuestion`:
- Header: "Git not ready"
- Question: "Git isn't set up for clone. What do you want to do?"
- Options based on the failure:
  - For missing git: "Install via brew" → tell user to run `brew install git` in their terminal, then come back.
  - For missing config: "Set up name/email" → tell user to run `git config --global user.name "..."` and `git config --global user.email "..."` in terminal.
  - For SSH auth failure: "Set up SSH key" → tell user to run `bash scripts/thinkos-git.sh setup-ssh` in terminal.
  - For gh auth failure: "Set up gh auth" → tell user to run `bash scripts/thinkos-git.sh setup-gh` in terminal.
  - Always include: "Skip — I'll fix it later" → abort the clone.

After user confirms the fix is done, re-run the checks. Once both pass, proceed.

### 2d. Run clone

```bash
bash scripts/thinkos-vault.sh clone <url> --path "<path>"
```

Show output. If the script reports "this doesn't look like a Think OS project vault" — `AskUserQuestion`:
- Header: "Not a Think OS vault"
- Question: "This repo doesn't have Think OS metadata. What do you want to do?"
- Options:
  | label | description |
  |---|---|
  | "Register as reference (read-only)" | "I'll mark results from it as `[reference]`. Good for company wikis." |
  | "Abort" | "Don't register; remove the clone." |

If "Register as reference": continue with `add-reference` (Branch 3 logic) using the cloned path.

End with one line: "Vault `<derived-name>` cloned and registered."

---

## Branch 3 — Add reference vault

### 3a. Path (free text)

Ask: "Path to the folder you want to register as read-only context?"

### 3b. Label (free text, with auto-default)

Default label is the basename of the path. Ask: "Friendly label? (Enter to keep default: `<basename>`)"

### 3c. Run add-reference

```bash
bash scripts/thinkos-vault.sh add-reference "<path>" --label "<label>"
```

Show output. End: "Registered `<label>` as a read-only reference vault."

---

## Branch 4 — Switch active vault

`AskUserQuestion`:
- Header: "Active vault"
- Question: "Which vault should be active?"
- multiSelect: false
- Options: one chip per registered vault (parse from the `list` output you ran in Step 1).
  - `label`: vault id
  - `description`: label + path + type (e.g., "Argenx Team OS · ~/ThinkOS/projects/argenx · project")

```bash
bash scripts/thinkos-vault.sh use <chosen-id>
```

End: "Active vault is now `<chosen-id>`."

---

## Branch 5 — Remove a vault

`AskUserQuestion`:
- Header: "Remove which vault?"
- Question: "Which vault should I deregister? (Files on disk stay.)"
- multiSelect: false
- Options: one chip per registered vault. Don't include the personal hub if there's only one personal vault — removing it would orphan the user. Add a final "Cancel" chip.

If user picks a vault, confirm once:

`AskUserQuestion`:
- Header: "Confirm removal"
- Question: "Remove `<id>` from the registry? Files at `<path>` will NOT be deleted."
- Options:
  | label | description |
  |---|---|
  | "Yes, remove" | "Deregister `<id>`." |
  | "Cancel" | "Don't touch anything." |

If confirmed:

```bash
bash scripts/thinkos-vault.sh remove <id> --yes
```

End: "Removed `<id>` from the registry. Files at `<path>` are untouched."

---

## Error handling

- Surface all script error output verbatim. Don't paraphrase.
- On unexpected exit codes, show the exact command that failed and the error, then `AskUserQuestion` with options "Retry" / "Abort".
