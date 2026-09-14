---
title: Timesheet Sources
permalink: 90-system/timesheet-sources
type: note
tier: WARM
tags: [timesheet, harvest, config]
visibility: private
---

# Timesheet Sources

> Where `/thinkos-timesheet` gets its numbers. Logic lives in the repo; this file holds
> the parts that are specific to you. Delete the examples and fill in your own.

## Capacity allocation

Where your weekly hours are decided, and how to read them.

- **Source:** <e.g. a planning doc in your task tracker / a resourcing tool / your lead>
- **How to find it:** <search terms, doc id, path — enough for an agent to locate it>
- **How to read it:** <e.g. "the Hours table, my row">
- **Published:** <e.g. Monday morning>
- **Maps to catalog slug:** `<slug>`

## Calendar → slug mapping

Recurring events that should be booked against a specific slug, at their real duration.

| Calendar event | Slug |
|---|---|
| `<event name>` | `<slug>` |

## Manual checks

Anything with no API that the Monday pass should ask about.

- **<tool name>** — <url> — <what to ask for>

## Fill

Leftover capacity goes to the catalog's `fill` slug. Currently: `<slug>`
(set in `~/.thinkos/harvest-catalog.json`).

## Notes

- Plan ≠ actuals. Correct divergence before submitting.
- Harvest has no submit API — submitting stays manual by design.
- Approved weeks are immutable, so corrections are forward-only.
