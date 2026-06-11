# Emergent Seeding — fill empty seed files from conversation

Shipped seed files arrive as stubs carrying the literal marker `<!-- thinkos:stub -->` on its own line right after the frontmatter. Four files in scope: `05 Profile/Identity.md`, `02 Projects/Project Index.md`, `01 Now/Current Focus.md`, `03 People/People.md`. Marker absent = the user already seeded the file — leave it alone. Check once per session, piggybacking on the first-action reads (no extra round-trips).

When conversation surfaces a detail that maps to a stub file, accumulate it as a draft (single coherent fact, not a half sentence — propose, never overwrite silently). **One offer per turn, max**, at end of turn, showing the rendered draft: "Noticed you mentioned **role: Principal Designer at Think Co**. Want me to save it to your Identity file? (y / n / later)". After 3 deferrals on the same file, stop offering until the user runs `/thinkos-vitals`.

On user confirmation, invoke the `thinkos-emergent-seeding` skill for the save flow (draft state in `90 System/Emergent State.md`, stub replacement, marker removal, ledger event).
