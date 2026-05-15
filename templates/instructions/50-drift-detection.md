# Agent-initiated drift detection

> Surface contradictions and staleness mid-flow, not only at `/weekly-review`. One terse line at the end of the turn — never the answer itself.

## When to check

Only when the relevant data is **already loaded** in your context from the first-action MCP reads or earlier turns. **Do not** issue extra MCP reads to trigger a drift check — that converts a low-cost nudge into a token tax. If the signal isn't visible to you for free, skip.

## Heuristics

Four checks, all read-only against in-context data:

- **Identity contradiction.** Identity says `role: X`. Three or more recent Work Log entries imply `role: Y` (different title, different employer, different team). Flag.
- **Current Focus stale.** `covers_week` end date in frontmatter is past today. Flag.
- **Unknown person.** The current turn mentions a proper noun (capitalized, two or more words, or a known first-name pattern with context) that appears nowhere in `People.md`. Flag.
- **Project not in index.** The current turn references a project slug or name that is absent from `Project Index.md`. Flag.

## Nudge format

One line, terse, end of turn — appended after the substantive answer, never before:

> Drift note: Current Focus expired 2 days ago. `/thinkos-vitals` to refresh.

> Drift note: "Jordan Wells" isn't in People.md yet. `/thinkos-who Jordan Wells` to log them.

The nudge points the user at a remediation command. No further explanation; the user clicks through if they care.

## Mute scope

- After `/weekly-review` runs, write `~/.thinkos/drift-muted.json` with `{ "until": "<next Sunday ISO>" }`. Skip all drift nudges until that timestamp.
- When shared-mode is on (see `60-shared-mode.md`), drift nudges are silent. Shared sessions should not surface unrequested vault internals.
- The user can also explicitly mute with `/thinkos-mute-drift <duration>` if that command exists; respect the same JSON file.

## Bounded nagging

- **Max one nudge per session.** Even if three heuristics fire, surface only the most actionable one this session.
- **Max one re-surface per topic per week.** If the user ignored "Current Focus expired" Monday, do not re-surface it Tuesday. Track in `~/.thinkos/drift-muted.json` under a `topics` map.
- When in doubt, stay silent. A missed drift is recoverable on the next `/weekly-review` or `/thinkos-vitals`; an over-nudged user mutes you for good.
