---
name: thinkos-emergent-seeding
description: Save-flow mechanics for Think OS emergent seeding — promoting accumulated conversation drafts into stub seed files (Identity, Project Index, Current Focus, People). Invoke when the user confirms saving a drafted detail into a file still carrying the <!-- thinkos:stub --> marker, or when you need to read or update draft state in 90 System/Emergent State.md (accumulate, defer, discard).
---

# Emergent Seeding — draft state and save flow

> The resident core (stub detection, the four target files, accumulate-then-offer cadence) lives in the always-on instruction stack. This skill holds the mechanics: draft state, the save flow, and worked examples.

## Draft state

Per-file draft state lives in the vault at `90 System/Emergent State.md`, managed via `mcp__basic-memory__edit_note`. Storing state in the vault (rather than a local JSON file) means multiple Claude instances share the same draft accumulation and the state survives across machines.

The file uses a fenced JSON block in its body:

```markdown
---
title: Emergent State
permalink: 90-system/emergent-state
---

# Emergent State

```json
{
  "identity":      { "draft": "...", "session_count": 2, "last_offered": "2026-05-14T18:22:00Z" },
  "current_focus": { "draft": "...", "session_count": 0, "last_offered": null },
  "project_index": { "draft": "...", "session_count": 1, "last_offered": "2026-05-13T09:11:00Z" },
  "people":        { "draft": "...", "session_count": 0, "last_offered": null }
}
```
```

To read state: `mcp__basic-memory__read_note("90 System/Emergent State")` and parse the JSON block.
To update state: `mcp__basic-memory__edit_note(identifier="90-system/emergent-state", operation="find_replace", ...)` with the updated JSON block.
If the note does not exist yet, create it first via `mcp__basic-memory__write_note` with the standard structure above (all four keys, empty drafts, `session_count: 0`, `last_offered: null`).

When natural conversation surfaces a detail that maps to a stub seed file, append it to the relevant `draft` field. Don't save yet — accumulate until an offer is warranted (single coherent fact, not a half sentence).

## Offer responses

The offer must include — or be immediately followed by — the rendered draft, so the user reviews exactly what will be written (per the show-before-write rule in the Write Targets section).

- `y` → run "Save flow" below.
- `n` → discard the draft: clear that file's `draft` field to `""` in `90 System/Emergent State.md` via `edit_note` (find_replace); do not increment `session_count`.
- `later` → keep draft, increment `session_count`, suppress this file's offers for the rest of the session. After 3 deferrals (`session_count >= 3`), stop offering until the user runs `/thinkos-vitals`.

## Save flow

When the user confirms (having already seen the rendered draft in the offer):

1. `mcp__basic-memory__edit_note(identifier="<seed file>", operation="replace", content="<rendered draft>")` — replace the stub with the drafted content, preserving frontmatter.
2. Remove the `<!-- thinkos:stub -->` marker as part of the replace.
3. Remove that file's key from the JSON block in `90 System/Emergent State.md` via `mcp__basic-memory__edit_note` (find_replace the JSON block).
4. Append one ledger event to `90 System/Capture Log.md` with `source: emergent`, `via: emergent-seeding`, `topic: <file slug>`.

## Examples

**Identity.** User says "I'm a Principal Designer at Think Co — been there four years, mostly design systems." Stub Identity is empty. Draft accumulates: name omitted, role + employer + tenure + speciality. End of turn: offer once. User confirms → replace stub with a 4-section draft (Who I am / What I do / Working style placeholder / Tool stack placeholder).

**Project Index.** Across three turns the user references "the Acme redesign," "the design tokens audit," "the Q3 hiring loop." Stub Project Index has no rows. Draft accumulates three project rows. End of third turn: offer once. User confirms → replace stub with a 3-row index plus the standard conventions block.

**People.** User mentions "Jordan, who runs platform at Think Co." Stub People is empty. Draft accumulates one entry. Offer at end of turn. User defers; `session_count` for `people` becomes 1. Two turns later the user mentions Jordan again with more context. Draft updates. Offer again. User confirms → replace stub with a one-person People file using the standard format.
