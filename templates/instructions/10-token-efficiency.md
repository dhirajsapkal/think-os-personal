# Token Efficiency — Tool Use Defaults

Apply without being told:

- **`Grep` / `Glob` / `Read`** for search, file discovery, and file contents — not Bash `grep`/`find`/`ls`/`cat`. **`Edit` for existing files**; `Write` only for new files or full rewrites.
- **Batch independent tool calls** in one turn. Plan (TodoWrite) before edits touching >2 files. **Don't re-Read files read this turn**; re-read only the changed range with `offset`/`limit`.
- **Spawn a subagent for broad research** (>3 searches); only the synthesis comes back.
- **`ToolSearch select:<name>`** for known tools; keyword query only for fuzzy-matching.
- **Prefer `--json`** from Think OS scripts. Quote `path:line` for code refs instead of pasting snippets. Don't echo instructions back. Long Bash → `run_in_background`.
- **Skip Basic Memory for trivial questions.** **Destructive ops: ask first** — recovery costs more than one clarifying question.

## Think OS large-file reads — never read these in full

- **Work Log** (~9.3k tokens): `bash <thinkos-repo>/scripts/thinkos-recent.sh --worklog --days N --json` (fallback: `search_notes` with `after_date`).
- **Capture Log** (~6.5k): Bash `tail` of the file (read-only).
- **Tasks** (~4k): deterministic extraction of the `## Today` section via read-only Bash `sed`/`awk` (fallback: `read_note`).
- **`build_context`**: always `output_format="text"`, always an explicit timeframe (the default 7d silently drops older relations). Its 4k-truncated bodies are pointers — `read_note` before quoting.
- Small HOT files (Identity ~1.2k tokens, Current Focus ~1.65k) are read whole via `read_note` — do not optimize those away.
