---
description: Sanity-check the OS for stale entries, broken references, contradictions
permalink: think-os/adapters/claude-code/commands/validate-os
---

Run a read-only sanity check of the personal OS vault. Surfaces stale entries, broken note references, line-count bloat, and contradictions between files. Proposes fixes — does not apply any.

## Step 1 — Invoke the validate-os skill (if available)

If the `validate-os` skill is installed, delegate:

```text
Skill("validate-os", args="$ARGUMENTS")
```

The skill has a curated checklist. Return its output directly, then continue to Step 5.

## Step 2 — Staleness audit (fallback inline playbook)

Read each HOT-tier file and check the `updated` or `covers_week` frontmatter field:

| File | Stale if… |
|------|-----------|
| `01 Now/Current Focus.md` | `covers_week` is past |
| `05 Profile/Identity.md` | `updated` > 7 days ago |
| `90 System/OS Instructions.md` | `updated` > 7 days ago |
| `02 Projects/Project Index.md` | `updated` > 7 days ago |

Flag each stale file with: `STALE: <file> (last updated: <date>)`.

## Step 3 — Broken reference check

Search for wiki-links (`[[...]]`) and relative paths in all vault files. For each link, verify the target exists via `mcp__basic-memory__search_notes`. Flag any that resolve to nothing as `BROKEN: [[<target>]] in <file>`.

## Step 4 — Contradiction check

Compare `Current Focus.md` priorities against open tasks in `01 Now/Tasks.md`. Flag if focus priorities don't appear in the task list, or if tasks reference projects not in `Project Index.md`.

## Step 5 — Report and propose

Output a structured report:

```
STALE (<count>): ...
BROKEN (<count>): ...
CONTRADICTIONS (<count>): ...
OK: <everything else>
```

For each issue, propose a one-line fix. **Do not apply any fix.** Tell the user: "Run `/thinkos-save` or edit the files manually to resolve — or ask me to fix a specific item."

## Notes

- This command is intentionally read-only. It is safe to run at any time.
- If Basic Memory MCP is unavailable, fall back to direct filesystem reads under `$OS_HOME`.

User message: $ARGUMENTS
