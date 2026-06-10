---
type: design-doc
tags:
- onboarding
- seeding
- agents
permalink: think-os/docs/emergent-seeding
---

# Emergent Seeding

Sibling to `phase-2-seeding-playbook.md`. This is the **default** path for filling HOT files on a new Think OS install (v0.5+). Phase 2 is the opt-in alternative.

## Why default to emergent

Phase 2 is powerful — it pulls from Slack, Notion, calendar, Gmail, and others to draft Identity / Project Index / Current Focus / People from real connector data in one ~30-minute pass. The cost is a 30-minute commitment up front, plus the need for connector auth, plus the cognitive load of reviewing four AI-drafted HOT files in one sitting.

Most new users don't want to commit 30 minutes to a setup ceremony before they've used the OS once. Emergent seeding flips the curve: HOT files arrive as empty stubs and fill in **turn-by-turn from natural conversation**, with explicit per-fact approval. The first session captures one or two facts. The third session captures another four. By session five, the HOT files are usefully populated — without a setup wall.

Phase 2 stays valid for users who *do* want to front-load. They run `/thinkos-continue` explicitly. The flows compose: a user can emergent-seed for a week, then run `/thinkos-continue` to fill the gaps.

## How it works

The shipped HOT-file templates carry a literal marker:

```
<!-- thinkos:stub -->
```

The marker sits on its own line, immediately after the frontmatter `---` close. Its presence tells the agent the file is empty and emergent seeding is active for it. The marker is removed when emergent seeding promotes a draft into the file.

Per-file draft state is tracked in the vault note `90 System/Emergent State.md` — a fenced JSON block managed via `mcp__basic-memory__edit_note`, so multiple Claude instances share the same draft accumulation and the state survives across machines. As the agent observes facts in conversation that map to a stub HOT file, it appends them to that file's `draft` field. When the draft is coherent enough to surface, the agent offers it at the end of the turn:

> Noticed you mentioned **role: Principal Designer at Think Co**. Want me to save it to your Identity file? (y / n / later)

On `y`, the agent replaces the stub with the rendered draft via `mcp__basic-memory__edit_note(operation="replace")`, removes the stub marker, and clears the draft state. On `n`, discards. On `later`, keeps the draft and increments a deferral counter — after 3 deferrals, stops offering until `/thinkos-vitals` re-surfaces the stub.

## Worked examples

### Identity

Session 1, user asks "what should I work on this morning?" Agent does first-action MCP reads, sees Identity is a stub, no draft yet, no facts in this turn — answers the question normally.

Session 2, user mentions "I'm a Principal Designer at Think Co, four years in, mostly design systems." Agent appends `name: -, role: Principal Designer, employer: Think Co, tenure: 4 years, focus: design systems` to the Identity draft. End of turn: offers once. User confirms. Agent replaces the stub Identity.md with a rendered Identity file (Who I am / What I do sections filled; Working style / Tool stack / Guardrails sections left as template placeholders for the user to fill on their own time).

### Project Index

Across three turns: "the Acme redesign," "the design tokens audit," "the Q3 hiring loop." Each turn the agent appends one row to the Project Index draft. End of third turn (or whenever the draft hits two or more rows): offers once. User confirms. Agent replaces stub with a 3-row index plus the standard conventions block.

### People

User mentions "Jordan, who runs platform at Think Co." Draft = one entry. Offers. User defers (`session_count: people = 1`). Two turns later: "Jordan and I are aligned on the platform direction — they're driving the migration." Draft updates with more context. Offers again. User confirms.

## What emergent seeding does NOT do

- **Does not pull from connectors.** No Slack search, no Notion fetch, no calendar lookups. That's Phase 2's job — by design, emergent stays in-conversation.
- **Does not infer facts the user didn't say.** If the user never mentions their tool stack, the Tool stack section of Identity stays as template placeholders.
- **Does not silently rewrite filled HOT files.** Once the stub marker is gone, the file is the user's. Emergent seeding becomes a no-op for that file until the user manually re-adds the marker (which they won't).

## When Phase 2 is the better choice

Recommend `/thinkos-continue` (Phase 2) when:

- The user has authenticated several connectors during Phase 1's optional capabilities step.
- The user explicitly says "set up my context all at once."
- The user is migrating from another personal-OS tool and has a folder of existing notes to import.

Recommend emergent (the default) when:

- The user skipped most connectors during Phase 1.
- The user prefers to "see how it works" before committing 30 minutes.
- The user has installed Think OS on a second machine and only wants Identity carried over.

## Curated rule reference

The behavioral rules live in `templates/instructions/40-emergent-seeding.md`. That file is loaded at the top of every Claude Code session as part of the Think OS curated block. The doc you're reading is the long-form rationale + worked examples.
