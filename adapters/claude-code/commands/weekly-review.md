---
description: Weekly OS digest — refresh Current Focus, surface drift, end-of-week review
permalink: think-os/adapters/claude-code/commands/weekly-review
---

Run the weekly OS review playbook. Reads the past 7 days of work-log entries, surfaces patterns, proposes a refreshed Current Focus, and flags any drift or stale notes.

## Step 0 — Which mode are you in?

```bash
echo "${THINKOS_UNATTENDED:-0}"
```

`1` means a scheduled run with **no human present to confirm anything**. `thinkos-cron-run.sh` sets it before invoking `claude -p`.

This gate exists because the interactive flow below says "after the user confirms" — which, unattended, can only resolve two ways, and both are wrong: write without confirmation, or correctly decline and silently change nothing. The second is what actually happened. `/weekly-review` fired on schedule for four months and left `Current Focus` eight weeks stale, because it had nothing to confirm against.

- **`$ARGUMENTS` contains `--apply-pending`** → go to **Step 5**.
- **Unattended (`1`)** → run Steps 1–3 as normal, then **Step 4-U** instead of Step 4.
- **Interactive (`0` or unset)** → Steps 1–4 exactly as before. Nothing changes.

## Step 1 — Load the weekly-review prompt

Read the cron prompt as the authoritative playbook for this command:

```bash
cat scripts/cron-prompts/weekly-review.txt
```

Execute every instruction in that file as if it were written here, **except where this wrapper overrides it** — notably the Current Focus write in Step 4 below (the wrapper's REPLACE-and-prune flow wins over any draft-file or append instruction in the cron prompt).

## Step 2 — Preflight checks

Before running the playbook:

1. Confirm recent Work Log entries exist — **never read the full Work Log** (~9.3k tokens). Use the scoped extraction: `bash <repo>/scripts/thinkos-recent.sh --worklog --days 7 --json` (resolve `<repo>` from `repo_path` in `~/.thinkos/install-manifest.json`, fallback `~/code/think-os`). Fallback: `mcp__basic-memory__search_notes` with `after_date=<today − 7d>`.
2. Read `01 Now/Current Focus.md` via `mcp__basic-memory__read_note` (small HOT file — whole read is correct; skip if already loaded this session) to check the `covers_week` field.
3. If the log has fewer than 3 entries for the past 7 days, warn the user before continuing — the digest will be thin.

## Step 3 — Execute the playbook

Follow the steps from `weekly-review.txt` in order. Do not skip steps. Surface all outputs inline.

## Step 4 — Refresh Current Focus: REPLACE-and-prune (confirm before writing)

Current Focus must contain **exactly one week** — never two concatenated week blocks. Append is forbidden here; the refresh is a replace. The mechanics, in order, after the user confirms the proposed content:

1. **Build the new week block** — covering next week (Mon–Sun), matching the existing file's structure.
2. **Archive the outgoing week** — append the outgoing week's block to the Work Log as a dated entry:

   ```
   mcp__basic-memory__edit_note(identifier="01 Now/Work Log", operation="append", content="\n## <today YYYY-MM-DD> — Current Focus archive (week of <outgoing covers_week>)\n<outgoing week's block verbatim>")
   ```

3. **Replace the live file** — `mcp__basic-memory__edit_note(identifier="Current Focus", operation="replace", content="<new week block>")` so the body holds only the incoming week. Update the `covers_week` frontmatter to the new Mon–Sun range as part of the same write.

If the current file already contains more than one week block (legacy append damage), prune now: archive every outgoing block to Work Log in step 2, keep only the new week in step 3.

Also propose any new Decisions or Learnings worth capturing.

**Do not write anything until the user confirms each item.** Show the diff or summary first.

## Step 4-U — Unattended: stage, never write

Do **not** touch `Current Focus.md`. Do not archive the outgoing week. Both belong to the apply step, and doing either here would leave the vault half-updated if the user never applies.

Write the proposal to `90 System/Pending Focus Refresh.md` via `mcp__basic-memory__write_note` (overwrite any existing pending file — only the newest proposal is useful):

```
---
title: Pending Focus Refresh
staged_at: <ISO8601 UTC>
proposes_week: <YYYY-MM-DD> → <YYYY-MM-DD>
supersedes_covers_week: <the covers_week currently live in Current Focus.md>
staged_by: weekly-review (unattended)
---

# Pending Focus Refresh

> Staged by a scheduled run. `Current Focus.md` is untouched. Apply with
> `/weekly-review --apply-pending`, or discard by deleting this file.

## Proposed week block

<the complete new week block, exactly as it would be written to Current Focus.md>

## Digest

<the week's digest: patterns, drift, stale notes — everything Steps 1–3 produced>
```

Then append one ledger event:

```json
{"ts":"<ISO8601 UTC>","source":"maintenance","detail":{"task":"weekly-review","staged":true,"proposes_week":"<range>"},"output":"90 System/Pending Focus Refresh.md","mode":"create","bytes":<n>}
```

Output one line: `Staged focus refresh for <range> — apply with /weekly-review --apply-pending.`

The SessionStart hook surfaces the pending file at the top of the next interactive session, so it gets confirmed then.

## Step 5 — `--apply-pending`

1. Read `90 System/Pending Focus Refresh.md`. If absent, say so and stop.
2. Check `supersedes_covers_week` against the live `covers_week`. If they differ, the file changed since staging — show both and ask before proceeding.
3. Show the proposed week block and ask for explicit confirmation.
4. On confirmation, run the **Step 4** mechanics unchanged: archive the outgoing block to Work Log, then REPLACE Current Focus with the new block and update `covers_week`.
5. Delete the pending file with `mcp__basic-memory__delete_note` so the hook stops advertising it.
6. Append a ledger event with `"mode":"replace"` and `"applied_from":"90 System/Pending Focus Refresh.md"`.

**Invariant, both paths:** `Current Focus.md` contains exactly one week block. Never two. If staging and applying both wrote, you would get two — which is the failure this whole flow is built to avoid.

## Notes

- This is a read-heavy, write-careful command. Default posture: propose, don't apply.
- Unattended runs stage; they never write Current Focus. Staging is not applying.
- If Basic Memory MCP is unavailable, fall back to direct reads under `$OS_HOME`.

User message: $ARGUMENTS
