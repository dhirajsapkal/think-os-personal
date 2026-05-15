---
type: design-doc
tags:
- agents
- maintenance
permalink: think-os/docs/drift-detection
---

# Drift Detection

Long-form rationale and operational reference. The curated rule lives at `templates/instructions/50-drift-detection.md` — that file gets the rules; this doc explains the why.

## Problem

Vault contents drift. The user's role changes; Current Focus's `covers_week` slides past; new people show up in conversation who aren't in `People.md`; a project surfaces that isn't in the Project Index. Without drift detection, the agent either:

1. Answers from stale context (worst: confidently states the wrong role / focus / collaborator).
2. Pretends nothing is wrong and hopes `/weekly-review` catches it next Sunday.

Both fail the user. The fix is a mid-flow nudge — one terse line at the end of the turn, never the answer itself.

## Heuristics

Four checks, all read-only against context the agent already has loaded:

### 1. Identity contradiction

Identity.md says `role: X`. The agent has read 3+ recent Work Log entries that imply role `Y` (different title / different employer / different team). Flag.

False positives to avoid:
- A single Work Log entry mentioning a freelance engagement does NOT imply a role change. Require 3+ entries.
- Past tense ("when I was at X") does NOT imply current role. Look for present-tense framing.

### 2. Current Focus stale

`covers_week` frontmatter end date is past today. Flag.

False positives to avoid:
- A `covers_week` exactly equal to today is fresh, not stale. Strict greater-than.
- If `covers_week` is missing entirely, do not flag — the user may have customized the template.

### 3. Unknown person

The current turn mentions a proper noun (capitalized, two or more words, OR a known first-name pattern like "Jordan said") that appears nowhere in `People.md`. Flag.

False positives to avoid:
- Generic capitalized terms (Claude, GitHub, Slack, Linear) are not people. Maintain a small denylist.
- A first name that already appears in People.md as part of a fuller entry is not unknown. Match against entries, not headings.

### 4. Project not in index

The current turn references a project slug (kebab-case) or project name that does not appear as a row in `Project Index.md`. Flag.

False positives to avoid:
- Internal-only working terms ("the dashboard refactor") are not projects unless the user says they are.
- A slug used once tangentially is not necessarily a new project. Require explicit framing ("the X project," "working on X," "shipped X").

## Nudge format

One line, appended at the end of the turn, after the substantive answer:

```
Drift note: Current Focus expired 2 days ago. /thinkos-vitals to refresh.
```

```
Drift note: "Jordan Wells" isn't in People.md yet. /thinkos-who Jordan Wells to log them.
```

Each nudge:
- Names the specific drift (not "you have drift").
- Points at a remediation command.
- Stays under one line. No bullet points. No further explanation.

## Mute scope

The agent respects two mute signals:

1. **Weekly-review mute.** After `/weekly-review` runs, write `~/.thinkos/drift-muted.json` with `{ "until": "<next Sunday ISO>" }`. Drift nudges are silent until that timestamp. Auto-resumes the following week.
2. **Shared-mode mute.** When `THINKOS_SHARED=1` or `~/.thinkos/shared-mode` exists, drift nudges are silent. Shared sessions should not surface unrequested vault internals.

The mute file structure:

```json
{
  "until": "2026-05-17T00:00:00Z",
  "topics": {
    "current-focus-stale": "2026-05-15T18:30:00Z",
    "unknown-person:Jordan Wells": "2026-05-14T09:00:00Z"
  }
}
```

`topics` records the last surface time per drift topic, used for the bounded-nagging check.

## Bounded nagging

- **Max one nudge per session.** Even if three heuristics fire, surface only the most actionable one. Priority: Current Focus stale > Identity contradiction > Project not in index > Unknown person. (Rationale: stale focus is the highest-impact freshness signal; unknown people are recoverable any time.)
- **Max one re-surface per topic per week.** If the user saw a nudge about "Current Focus expired" Monday, don't re-surface it Tuesday. Check the `topics` map.

## Handoff to `/weekly-review`

Drift nudges are a stopgap between weekly reviews. The user's pattern should be:

1. Weekly review on Sunday refreshes Current Focus and audits People / Project Index.
2. During the week, drift nudges flag anything the review missed or anything that emerged mid-week.
3. The user fixes ad hoc (`/thinkos-who`, `/thinkos-capture`, etc.) or waits for next Sunday.

Nudges that fire repeatedly across multiple weeks indicate the weekly review isn't catching the pattern — that's a signal for the maintainer to tune the review prompt, not to increase nag frequency.
