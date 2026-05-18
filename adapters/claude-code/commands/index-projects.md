---
description: Scan project directories and reconcile against active-projects index
permalink: think-os/adapters/claude-code/commands/index-projects
---

Walk registered project directories and reconcile them against `02 Projects/Project Index.md`. Surfaces missing entries, stale slugs, and orphaned folders. Proposes changes — does not auto-write.

## Step 1 — Invoke the index-projects skill (if available)

If the `index-projects` skill is installed, delegate:

```text
Skill("index-projects", args="$ARGUMENTS")
```

The skill has a curated reconciliation playbook. Return its output directly.

## Step 2 — Load the current index (fallback inline playbook)

Read `02 Projects/Project Index.md` via `mcp__basic-memory__read_note`. Extract all slugs and their `status` fields.

## Step 3 — Scan registered vault paths

Read `~/.thinkos/vaults.json` if it exists. For each vault with `type: project`, list the subfolders under `02 Projects/` in that vault.

Also check `$OS_HOME/02 Projects/` in the personal hub.

## Step 4 — Reconcile

Compare folders against index entries:

| Finding | Label |
|---------|-------|
| Folder exists, no index entry | `MISSING: <slug>` |
| Index entry exists, no folder | `ORPHAN: <slug>` |
| Index entry status is `active` but no recent activity in folder | `STALE: <slug>` |
| Folder and index entry match | `OK: <slug>` |

## Step 5 — Report and propose

Output the reconciliation table grouped by finding type. For each MISSING or ORPHAN entry, propose a one-line fix (add stub, remove entry, or archive).

**Do not write any changes.** Tell the user: "Review the proposals above and confirm which to apply — or run `/thinkos-save` to capture any decisions made here."

## Flags reference

| Flag | Effect |
|------|--------|
| `--vault <id>` | Scope to one vault instead of all |
| `--status <active\|archived>` | Filter by project status |

## Example invocations

- `/index-projects` — full reconciliation across all vaults
- `/index-projects --status active` — only active projects

User message: $ARGUMENTS
