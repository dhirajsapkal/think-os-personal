---
description: Pre-fill this week's Harvest timesheet from your team's capacity plan
permalink: think-os/adapters/claude-code/commands/thinkos-timesheet
---

Pre-fill the user's Harvest week, show the diff, apply on confirmation.

`$ARGUMENTS` may contain `--week YYYY-MM-DD` (any date in the target week; default is the
Monday of the current week) or `--ledger-report`, which runs the provenance report and stops.

Requires `scripts/harvest-timesheet.py` to be set up — a token in
`~/.thinkos/secrets/harvest.env` and a catalog at `~/.thinkos/harvest-catalog.json`
(`harvest-timesheet.py catalog --init` generates the latter). **Never print the token.**

---

## The division of labour

The script does no reasoning: it takes a plan and converges Harvest onto it. *You* gather
the inputs and propose the plan. Keeping those apart means a bad inference can never
silently rewrite a week — the user sees a diff first.

## Where the numbers come from

Read `90 System/Timesheet Sources.md` in the vault for this user's configuration: which
project their billable hours are planned in, where that plan lives, which calendar events
map to which catalog slug, and anything they check manually.

If that note doesn't exist, ask the four questions once and offer to write it:

1. Where does your weekly capacity allocation come from? (a planning doc, a resourcing
   tool, your delivery lead)
2. Which recurring calendar events should map to which catalog slugs?
3. Is there anything you have to check by hand, with no API?
4. Which slug absorbs whatever's left over? (this is the catalog's `fill`)

## Step 1 — Show the current state

```bash
python3 ~/code/think-os/scripts/harvest-timesheet.py status [--week YYYY-MM-DD]
```

If the week is full, balanced, and every entry reads `submitted`/`approved`, say so and
stop. Don't re-derive a settled week.

## Step 2 — Gather evidence (run these in parallel)

**a. The capacity allocation** — from whatever `Timesheet Sources.md` names. If this
week's plan hasn't been published yet, ask rather than extrapolating from last week.

**b. Calendar — time off, holidays, and mapped meetings.** Look for `OUT_OF_OFFICE`, all-day
time-off blocks, and company holidays. Map recurring events to slugs using their **real
durations**; this is the one defensible, zero-effort input, so always compute it. Expect
meetings to be a small share of the week — a floor, not the answer.

**c. Solo work.** This is the part that actually needs the user, because the hard question
is recall, not data entry. Lead with the measured signal:

```bash
python3 ~/code/think-os/scripts/session-activity.py --week YYYY-MM-DD --format text
```

That reports real per-project, per-day active time from Claude Code session logs, derived
from each entry's own timestamp, and names the files touched.

**It is an attribution signal, not a total.** It only sees time spent in Claude Code —
meetings, design tools, review and email are invisible to it. Use it for *proportion
between projects*, then scale to the hours actually being allocated. Never present its
number as the week's total.

Supporting signals, where connected: meeting-transcript tools, the task tracker.

**d. Manual checks.** Ask about anything `Timesheet Sources.md` flags as having no API.
One line, with the link. Don't block if the answer is "none".

## Step 3 — Propose the split

Show the derivation as a short table — what came from the plan, what came from the
calendar, what's left. Then **offer a concrete split to react to** rather than asking an
open "what did you do?":

> The plan has you at 20h on <project>. Calendar shows 2h of mapped meetings. That leaves
> 18h heading for <fill slug>.
>
> Roughly how did that 18h go? e.g. `slug-a=8 slug-b=4`

Run `harvest-timesheet.py catalog` for the slug list.

```bash
python3 ~/code/think-os/scripts/harvest-timesheet.py propose \
  --alloc <slug>=20 --alloc <slug>=1@YYYY-MM-DD --alloc <slug>=8 > /tmp/plan.json
```

**Pin meetings to the day they happened** with `@YYYY-MM-DD`. Always do this for
calendar-derived hours — an hour-long standup belongs on its day, not smeared across four.
It's more accurate and it survives scrutiny. Un-pinned allocations fill the room left in
each working day, so every day still lands on a full day's hours.

`--fill` overrides the catalog's fill slug. `--off YYYY-MM-DD=<day-slug>` and
`--holiday-on YYYY-MM-DD` book whole days and are excluded from the spread.

For anything `propose` can't express, hand-write the plan JSON:

```json
{
  "week_start": "YYYY-MM-DD", "capacity": 40.0,
  "holidays": ["YYYY-MM-DD"], "time_off": { "YYYY-MM-DD": "<day-slug>" },
  "allocations": [
    { "project_id": 123456, "task_id": 654321, "hours": 20.0, "slug": "<slug>" }
  ]
}
```

## Step 4 — Diff, then explicit confirmation

```bash
python3 ~/code/think-os/scripts/harvest-timesheet.py plan --week YYYY-MM-DD < /tmp/plan.json
```

Restate the derivation in one line so it's checkable. **Wait for explicit confirmation —
this writes to a payroll system. Never apply in the same turn you propose.**

Exit code `2` means the plan doesn't reach capacity — surface the gap and ask. Don't paper
over it with `--allow-imbalance`.

Say once, when the numbers came from a plan rather than from the user directly:
*plan ≠ actuals — correct anything that diverged before submitting.*

## Step 5 — Apply, then hand off the submit

```bash
python3 ~/code/think-os/scripts/harvest-timesheet.py apply --week YYYY-MM-DD < /tmp/plan.json
```

Idempotent, and it never modifies entries already `submitted` or `approved`.

**Harvest exposes no submit-for-approval endpoint**, so finish by handing over the link and
saying the last step is manual. Never claim to have submitted. Even if an API existed, the
submit is an attestation the user makes.

## Step 6 — Log it

Append one ledger event to `90 System/Capture Log.md` via
`mcp__basic-memory__edit_note(identifier="Capture Log", operation="append", content=...)`:

```json
{"ts":"<ISO8601 UTC>","source":"harvest","detail":{"week_start":"<YYYY-MM-DD>","total":<h>,"changes":<n>,"slugs":{"<slug>":<h>}},"output":null,"mode":"apply","bytes":0}
```

---

## `--ledger-report` mode

Skip everything above and run:

```bash
python3 ~/code/think-os/scripts/harvest-timesheet.py ledger-report [--from ...] [--to ...]
```

This totals the slugs listed under `ledger` in the catalog — per task, with first and last
dates and a share of all hours logged. Use it when someone asks what a given stream of work
has actually cost, or when you want provenance for something you built.
