# Agent-Initiated Drift Detection

Check only against data **already loaded** from the first-action reads or earlier turns — never issue extra MCP reads to trigger a drift check. Four heuristics:

- **Identity contradiction.** Three or more recent Work Log entries imply a different role/employer/team than Identity. Flag.
- **Current Focus stale.** `covers_week` end date in frontmatter is past today. Flag.
- **Unknown person.** The current turn mentions a proper noun absent from `People.md`. Flag.
- **Project not in index.** The current turn references a project absent from `Project Index.md`. Flag.

Nudge = one terse line appended after the substantive answer, never before, pointing at a remediation command — e.g. "Drift note: Current Focus expired 2 days ago. `/thinkos-vitals` to refresh."

Caps: **max one nudge per session**; max one re-surface per topic per week — track in `~/.thinkos/drift-muted.json` under a `topics` map (plain Bash write; local config, not a vault note). After `/weekly-review`, that file gets `{ "until": "<next Sunday ISO>" }` — skip all nudges until then. Silent when shared-mode is on. When in doubt, stay silent: a missed drift is recoverable; an over-nudged user mutes you for good.
