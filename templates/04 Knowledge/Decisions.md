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

### The `supersedes:` convention

Decisions form a chain, not a pile. When a new decision replaces an old one:

- The **new** entry carries `**Supersedes**: [[YYYY-MM-DD — <old topic>]]`.
- The **old** entry gets a `**Superseded-by**: [[YYYY-MM-DD — <new topic>]]` line added as its first body line. Don't delete the old entry — the history is the point.

Search will still surface the old entry; the `Superseded-by` line tells the agent (and you) which one is live. Quick example:

```markdown
## 2026-03-02 — deploys go through CI only
**Decision**: All deploys run through CI; no laptop deploys.
**Supersedes**: [[2025-11-10 — manual deploys allowed for hotfixes]]

## 2025-11-10 — manual deploys allowed for hotfixes
**Superseded-by**: [[2026-03-02 — deploys go through CI only]]
**Decision**: Hotfixes may be deployed from a laptop with a second approver.
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
