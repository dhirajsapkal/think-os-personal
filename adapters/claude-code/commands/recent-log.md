---
description: What did I do recently? Summarize last N days of work-log entries
permalink: think-os/adapters/claude-code/commands/recent-log
---

Summarize recent work-log entries. Defaults to the last 7 days; pass `--days N` to change the window.

## Step 1 — Parse arguments

Extract `--days N` from `$ARGUMENTS` if present. Default to 7 if omitted.

## Step 2 — Extract the window (NEVER read the full Work Log)

The full Work Log is ~9.3k tokens and growing. **Never** `read_note` the whole note — extract only the requested window.

**Primary path** — the scoped-extraction script. Resolve the installed repo first (the script lives in the Think OS repo, not the vault):

```bash
REPO_ROOT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.thinkos/install-manifest.json'))).get('repo_path',''))" 2>/dev/null)"
bash "${REPO_ROOT:-$HOME/code/think-os}/scripts/thinkos-recent.sh" --worklog --days <N> --json
```

If the manifest is missing `repo_path`, fall back to `~/code/think-os`, or check the vault's `90 System/OS Instructions.md` for a `repo_path:` hint.

**Fallback** (script or shell unavailable): scoped search, not a full read:

```text
mcp__basic-memory__search_notes(query="work log", after_date="<today − N days, YYYY-MM-DD>", entity_types=["observation"], page_size=3)
```

Escalate per the standard ladder on a miss (page=2, then page_size=10). Treat snippets as pointers — read the matching date span before quoting from it.

## Step 3 — Filter to the requested window

From the extracted entries, keep those whose date falls within the last N days from today. Work-log entries are expected to have date headers in ISO format (`YYYY-MM-DD`) or similar.

If fewer than 3 entries are found, note: "Only <count> entries in the last N days — log may be sparse. Run `/thinkos-doctor` to check capture health."

## Step 4 — Summarize

Present:

1. **By-day list** — one bullet per day with a short summary of what was logged.
2. **Themes** — 2–4 recurring topics or projects that appeared across entries.
3. **Notable decisions or learnings** — anything that looks like a reusable insight (flag with "Worth logging?").

Keep the summary tight. Do not reproduce the raw log verbatim — the scoped extraction already capped the read at the N-day window (vs ~9.3k tokens for the full note); don't give the savings back by echoing it.

## Step 5 — Offer to drill into a day (interactive)

After the summary, offer: "Want to see the full entry for any specific day?"

If the user picks a day, show the raw entry for that date only.

## Flags reference

| Flag | Effect |
|------|--------|
| `--days N` | Look back N days instead of 7 |
| `--raw` | Dump the raw lines from the extracted window without summarising (still window-scoped — never the full log) |

## Example invocations

- `/recent-log` — last 7 days
- `/recent-log --days 14` — last two weeks
- `/recent-log --raw` — unprocessed log dump

User message: $ARGUMENTS
