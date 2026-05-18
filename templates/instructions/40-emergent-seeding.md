# Emergent Seeding — HOT files fill in from conversation

> When the user hasn't bulk-seeded via Phase 2, their HOT files arrive as empty stubs. Fill them in from natural conversation — propose, never overwrite silently.

## When to check

Once per session, **after** the mandatory first-action MCP reads. No extra round-trips: the stub check piggybacks on the reads you already did. If a HOT file's body is empty or matches the shipped template, it's a stub and emergent seeding is active for it.

## Stub detection

The shipped templates for the four HOT files carry the literal marker:

```
<!-- thinkos:stub -->
```

It sits on its own line, immediately after the frontmatter `---` close. The marker survives a user pasting their own content above it; it only goes away when emergent seeding promotes a draft into the file (Step "Save flow" below). The four files in scope:

- `05 Profile/Identity.md`
- `02 Projects/Project Index.md`
- `01 Now/Current Focus.md`
- `03 People/People.md`

If the marker is absent, the user has already seeded the file — leave it alone.

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

When natural conversation surfaces a detail that maps to a stub HOT file, append it to the relevant `draft` field. Don't save yet — accumulate until an offer is warranted (single coherent fact, not a half sentence).

## Offer cadence

- **One offer per turn, max.** Even if three stub files have draft content ready, surface only the most-developed one this turn.
- **Bounded nagging.** After 3 deferrals on the same file (`session_count >= 3`), stop offering until the user runs `/thinkos-vitals` (which re-surfaces stale stubs explicitly).
- **Offer format** — one line at the end of the turn:

  > Noticed you mentioned **role: Principal Designer at Think Co**. Want me to save it to your Identity file? (y / n / later)

  `y` → run "Save flow." `n` → discard the draft, do not increment `session_count`. `later` → keep draft, increment `session_count`, suppress this file's offers for the rest of the session.

## Save flow

When the user confirms:

1. `mcp__basic-memory__edit_note(identifier="<HOT file>", operation="replace", content="<rendered draft>")` — replace the stub with the drafted content, preserving frontmatter.
2. Remove the `<!-- thinkos:stub -->` marker as part of the replace.
3. Remove that file's key from the JSON block in `90 System/Emergent State.md` via `mcp__basic-memory__edit_note` (find_replace the JSON block).
4. Append one ledger event to `90 System/Capture Log.md` with `source: emergent`, `via: emergent-seeding`, `topic: <file slug>`.

## Examples

**Identity.** User says "I'm a Principal Designer at Think Co — been there four years, mostly design systems." Stub Identity is empty. Draft accumulates: name omitted, role + employer + tenure + speciality. End of turn: offer once. User confirms → replace stub with a 4-section draft (Who I am / What I do / Working style placeholder / Tool stack placeholder).

**Project Index.** Across three turns the user references "the Acme redesign," "the design tokens audit," "the Q3 hiring loop." Stub Project Index has no rows. Draft accumulates three project rows. End of third turn: offer once. User confirms → replace stub with a 3-row index plus the standard conventions block.

**People.** User mentions "Jordan, who runs platform at Think Co." Stub People is empty. Draft accumulates one entry. Offer at end of turn. User defers; `session_count` for `people` becomes 1. Two turns later the user mentions Jordan again with more context. Draft updates. Offer again. User confirms → replace stub with a one-person People file using the standard format.
