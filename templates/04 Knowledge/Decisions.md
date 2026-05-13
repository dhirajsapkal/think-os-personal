---
title: Standing Decisions
aliases:
- Decisions
- decisions
type: note
permalink: think-os/decisions
tier: WARM
last_reviewed: {{YYYY-MM-DD}}
---

# Standing Decisions

Long-term decisions I've already made, so the agent does not re-litigate them every session. New entries go at the top (newest-first).

**Append via `/thinkos-decide`** (CLI agent) or just add a section by hand.

---

## Format

```markdown
## YYYY-MM-DD — <topic>
**Decision**: <what was decided>
**Why**: <reasoning at the time>
**Context**: <what prompted it — meeting, problem, person>
**Applies to**: <project / general / specific tool>
**Supersedes**: <link to earlier decision if any, or "none">
```

---

## Decisions (newest first)

## {{YYYY-MM-DD}} — Example: stop drafting follow-up emails after a meeting
**Decision**: Don't auto-draft follow-up emails after meetings; only when explicitly asked.
**Why**: I was rewriting most of them from scratch — the agent's defaults didn't match my voice.
**Context**: Two weeks of friction; Granola handles meeting summaries, follow-ups need my judgment.
**Applies to**: General — all meetings, all clients.
**Supersedes**: none.

## {{YYYY-MM-DD}} — Example: knowledge home is Obsidian, not Notion
**Decision**: Personal knowledge lives in Obsidian on top of the Think OS vault. Notion is for shared / client-facing pages only.
**Why**: One source of truth; markdown is portable; Notion sync was lossy.
**Context**: Tried dual-write for 3 weeks; lost more than I gained.
**Applies to**: Personal knowledge management.
**Supersedes**: none.

---

*Append new decisions at the top. Quarterly review marks superseded ones.*
