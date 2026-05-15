---
description: Save substantive items from the current session to your personal context MCP — the manual analog of autosave, for substance (not metadata)
permalink: think-os/adapters/claude-code/commands/thinkos-save
---

You are running `/thinkos-save`. The user just had a substantive session and wants to capture **the substance** — decisions, learnings, work-log entries, people mentioned — into their personal vault before the context is gone.

This is **complementary to the autosave launchd job**. That job captures metadata (cwd, file counts, commit SHAs) every 2 hours. This command captures the human-readable substance: what was decided, what was learned, what shipped, who was discussed.

## When to invoke

User invocation only. Triggered by:
- `/thinkos-save`
- "save this session" / "save what we just did" / "wrap this up"
- "log this session to my context" / "let's call this done"

The agent does NOT trigger this automatically — capture timing is user-decided.

---

## Step 0 — Check for recent saves (avoid duplicates)

Read the last 30 minutes of the capture ledger to detect recent manual saves:

```bash
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
tail -30 "$VAULT/90 System/Capture Log.md" 2>/dev/null | grep '"source":"manual"' | tail -5
```

If there are recent `source: manual` events with `via: thinkos-save` in the last 30 min, use `AskUserQuestion`:

- Header: "Recent save detected"
- Question: "Substantive content was already saved <N> minutes ago via `/thinkos-save`. Save again anyway?"
- Options:
  | label | description |
  |---|---|
  | "Save additional items" | "Capture anything new since the last save." |
  | "Skip — recent saves cover this" | "Exit without saving." |

If "Skip" → exit cleanly. If "Save additional items" → proceed.

If no recent manual saves, proceed silently.

---

## Step 1 — Triage what to save

Read the recent conversation context (you already have it loaded — no fetching). Identify candidate entries across four categories. **Be honest** — if a category has no real items, that category produces zero drafts.

### Work Log entry (usually 1, sometimes 0)

A 4–8 sentence narrative of what was worked on in this session. What shipped, what didn't, the WHY behind the choices. Reference commits or version numbers if mentioned.

**Skip Work Log entirely if:** the session was pure exploration / Q&A with no concrete work shipped.

### Decisions (0–3)

A *standing* rule or principle adopted during the session. Test: "Will this apply to future situations, not just this one?"

Format:
```
### YYYY-MM-DD · <Topic — one short phrase>

<2–4 sentence body capturing the decision.>

**Why:** <The reason. Often the past pain point that prompted the decision.>
**How to apply:** <When this rule kicks in. Concrete trigger conditions.>
```

**Skip if** the session was tactical execution with no general rules formed.

### Learnings (0–3)

A *reusable pattern* observed. Test: "Could this generalize beyond this specific situation?"

Format:
```
### YYYY-MM-DD · <Pattern name>

<Observation — what was learned, stated as a pattern.>

**When to apply:** <Specific situations where this insight kicks in.>

<Optional: back-pointer to the conversation moment that surfaced it.>
```

**Skip if** the session was purely execution, no patterns observed.

### People mentions (0–3)

New colleagues / clients / external contacts mentioned for the first time. Skip if they're already in the user's vault (you'd recognize names from the existing People file via Basic Memory if relevant).

**Skip if** no new people came up, or only people already profiled.

---

## Step 2 — Present drafts via chip-picker

For each candidate draft, use `AskUserQuestion`:

- Header: "<Type>: <short title>"
- Question: Show the proposed draft body inline, then ask "Save this?"
- multiSelect: false
- Options:
  | label | description |
  |---|---|
  | "Save" | "Append to <file> as-is." |
  | "Edit" | "I'll rewrite the content first." |
  | "Skip" | "Don't save this one." |

If user picks **Edit**, prompt for the replacement text as free input, then show the edited version with the same three options.

If user picks **Save**, queue the draft.

If user picks **Skip**, discard.

Walk through the drafts one at a time — Work Log first, then each Decision, then each Learning, then each Person.

---

## Step 3 — Write approved drafts

For each queued draft, append via `mcp__basic-memory__edit_note`:

| Type | identifier | operation |
|---|---|---|
| Work Log | `Work Log` | `append` |
| Decision | `Decisions` | `append` |
| Learning | `Learnings` | `append` |
| Person | `People` | `append` |

For each write, also append one ledger event to the Capture Log:

```
mcp__basic-memory__edit_note(
  identifier="Capture Log",
  operation="append",
  content='{"ts":"<ISO8601 UTC now>","source":"manual","detail":{"type":"<work_log|decision|learning|person>","via":"thinkos-save"},"output":"<vault relative path>","mode":"append","bytes":<bytes of this draft>}\n'
)
```

Privacy keywords: if a draft contains any of `comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, personal, confidential, private`, write the entry to the vault but add `"redacted": true` to the ledger event and omit detail content fields. The vault file itself is the personal hub — content is fine there; the ledger just doesn't surface the sensitive label.

---

## Step 4 — Reindex + report

After all writes complete:

```bash
basic-memory reindex --project think-os 2>&1 | tail -3
```

Then summarize for the user:

> Saved <N> entries to your vault:
>   <count> Work Log · <count> Decisions · <count> Learnings · <count> People
>
> Reindexed. `/thinkos-recent` will show them in the audit ledger.

If the user picked Skip for everything, say:

> Nothing saved — all drafts skipped. Run `/thinkos-save` again later if you change your mind.

---

## Hard rules

- **Never write without approval.** Each entry shown via chip-picker, user approves explicitly.
- **Personal hub only.** Saved entries land in the personal hub regardless of active vault.
- **No client names.** Per Identity guardrail #7. If the session referenced clients by name, redact them as `[client]` in drafts before showing.
- **Honesty about triviality.** If the session was light or already-captured, say so:
  > Session looks trivial — no substantive items to capture this round.
- **Don't duplicate yourself.** If `/thinkos-save` ran recently, check Step 0 carefully and only surface what's new.
- **Be terse.** Drafts should read like the user's own writing — direct, no padding, no marketing voice.
- **Token-efficient.** Don't re-read the entire conversation; rely on what's already in your context. If you need a specific earlier moment, search Basic Memory.

---

## Common questions

- **"What's the difference between `/thinkos-save` and `/thinkos-log`?"**
  `/thinkos-log` captures one quick note ("log this: <message>"). `/thinkos-save` captures a session's entire substance across Work Log + Decisions + Learnings + People in one pass, with approval for each item.

- **"How is this different from autosave?"**
  Autosave (launchd) captures metadata every 2h. `/thinkos-save` is manual and captures substance — the human-readable narrative + decisions + learnings. They're complementary.

- **"What if the session was trivial?"**
  Step 1 should detect this and produce zero drafts. The agent reports "no substantive items" and exits.

- **"I want to save just one specific thing."**
  Use `/thinkos-decide`, `/thinkos-capture`, or `/thinkos-log` for single-item captures. Reserve `/thinkos-save` for end-of-session multi-item recaps.
