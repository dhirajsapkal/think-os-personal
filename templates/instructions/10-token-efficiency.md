# Token Efficiency — Tool Use Defaults

Follow these defaults without being told. They keep the user's context window clean and answers fast. Ranked roughly by impact.

- **Use `Grep`, not `Read`+grep via Bash.** The built-in `Grep` tool is ripgrep with permissions wired correctly. Reading a file and grepping its contents wastes tokens and is slower.
- **Use `Glob` for file discovery, not `find`/`ls` via Bash.** `Glob` returns matches sorted by mtime and respects ignore rules. Don't shell out for pattern-matching file paths.
- **Use `Read`, not `cat`/`head`/`tail` via Bash.** The `Read` tool returns line-numbered output the model can refer to with `path:line`. Bash dumps are opaque to follow-up tool calls.
- **Use `Edit`, not `Write`, for existing files.** Edit sends a diff; Write replaces the whole file. Only `Write` when creating new files or for a full rewrite.
- **Batch independent tool calls in one assistant turn.** If three commands have no data dependency between them, call all three in parallel. Serial tool calls cost extra round-trips.
- **Plan before non-trivial multi-file edits.** Use `TodoWrite` (or an explicit plan in the response) for any change touching >2 files or requiring sequenced steps. Single-line typo fixes do not need a plan.
- **Spawn a subagent for broad research.** If a question needs >3 searches or speculative exploration, delegate to a research subagent. Your own context stays clean; only the synthesized answer comes back.
- **Don't re-Read files you read this turn.** Refer to context. If something might have changed, say so and re-read only the relevant range with `offset`/`limit`.
- **Use `ToolSearch` with `select:<name>`** for tools you know by name. Use keyword query mode only when fuzzy-matching across an unknown space.
- **Prefer JSON output from scripts.** When a Think OS script supports `--json`, use it. Parsing structured output is cheaper than parsing prose.
- **Skip Basic Memory for trivial questions.** Syntax lookups, one-off shell incantations, generic factual questions — answer directly. Querying the vault for "how do I rebase in git" is waste.
- **Don't re-state instructions back to the user.** When you understand a request, act on it. Echoing the prompt is filler.
- **Quote `path:line` for code refs.** Cheaper and more precise than pasting snippets when the user can open the file.
- **Stream long Bash commands with `run_in_background`** when output isn't needed immediately. Don't poll in a sleep loop — use the notification.
- **For destructive ops, ask first; don't undo with another tool call.** A `git reset --hard` you regret costs more tokens to recover from than one clarifying question would have cost upfront.
