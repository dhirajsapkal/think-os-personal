---
description: Canonical capture command — type-infers decision / learning / log / session-recap
permalink: think-os/adapters/claude-code/commands/thinkos-capture
---

You are running `/thinkos-capture`. This is the **canonical capture command**. It accepts any substance the user wants to save — a decision, a learning, a work-log entry, or a multi-item session recap — and routes it to the right vault destination.

`/thinkos-log`, `/thinkos-decide`, and `/thinkos-save` are soft aliases that delegate here with a `--mode` flag. Same behavior, fewer commands to remember.

---

## Step 0 — Parse arguments and mode

`$ARGUMENTS` may include a leading `--mode <decision|learning|log|session-recap>` flag.

- If `--mode <X>` is present, strip it from `$ARGUMENTS` and force mode `X`. Skip Step 1.
- If `$ARGUMENTS` is empty after stripping, force mode `session-recap` (multi-item end-of-session capture).
- Otherwise proceed to Step 1 for type inference.

## Step 1 — Type inference (single-item path)

Inspect the cleaned `$ARGUMENTS` and infer one of `decision | learning | log`. Resolution order — first hit wins:

1. **Decision** — verb phrases like "decided to", "we'll always", "from now on", "going forward", "standing rule", "policy:", "convention:" or a clearly normative future-tense framing. Test: "Will this apply to future situations, not just this one?"
2. **Learning** — phrases like "I learned", "noticed that", "turns out", "the pattern is", "next time" + a generalizable observation. Test: "Could this generalize beyond this specific situation?"
3. **Log entry** — first-person past tense, single concrete event ("ran the migration", "shipped the fix", "merged the PR"). The default when the content is event-flavored.
4. **Session-recap** — multi-paragraph content, multiple distinct items inside one message, or content that doesn't fit any single bucket above. Fall through to recap mode.

When two heuristics seem to fit, prefer the more general (decision > learning > log). When uncertain, ask the user once: `"Looks like this could be a <X> or a <Y> — which is it?"` Don't ask more than once.

---

## Step 2 — Format per type

### Mode: decision

Append to `04 Knowledge/Decisions.md` via Basic Memory. Format (preserve from the previous `/thinkos-decide`):

```markdown
## YYYY-MM-DD — <topic>
**Decision**: <what was decided>
**Why**: <reasoning at the time>
**Context**: <what prompted it>
**Applies to**: <project / general / specific tool>
**Supersedes**: <link to earlier decision if any>
```

Extract topic, decision, why, context, applies-to from the content. If anything is unclear, ask ONCE for the most-missing piece before writing. Per the Decisions.md convention, NEWER entries go above older ones — find the right insertion point or append after the format guide block.

```
mcp__basic-memory__edit_note(identifier="Standing Decisions", operation="append", content="<formatted entry>")
```

### Mode: learning

Append to `04 Knowledge/Learnings.md`. Format (preserve from the previous `/thinkos-capture`):

```markdown
### YYYY-MM-DD — <short title>
- **Context**: where this came up (project, conversation, meeting)
- **Learning**: the reusable insight, decision, or pattern
- **Applies to**: future engagement types where this is relevant
- **Tags**: #tag1 #tag2 #tag3
- **Source**: link to project file, Figma, doc, Slack thread, etc.
```

Propose tags from the existing taxonomy in `04 Knowledge/Learnings.md`. If a section is missing, ask once for that specific piece before writing.

```
mcp__basic-memory__edit_note(identifier="Learnings", operation="append", content="<formatted entry>")
```

### Mode: log

Append to `01 Now/Work Log.md`. Format (preserve from the previous `/thinkos-log`):

```
\n## YYYY-MM-DD HH:MM — <project-or-context>
Session: <verbatim content>
```

Use today's date and current time. Derive `<project-or-context>` from CWD if it's under a known project root; otherwise infer from the content or use "CLI agent session." Keep the user's wording verbatim — no preamble, no summary.

```
mcp__basic-memory__edit_note(identifier="Work Log", operation="append", content="<formatted entry>")
```

### Mode: session-recap

This is the multi-item end-of-session recap (the previous `/thinkos-save` flow). Run the playbook in the "Session-recap mode" section below.

---

## Step 3 — Ledger event

After every successful write, append one event to `90 System/Capture Log.md`:

```
mcp__basic-memory__edit_note(
  identifier="Capture Log",
  operation="append",
  content='{"ts":"<ISO8601 UTC now>","source":"manual","detail":{"type":"<decision|learning|work_log|session_recap>","via":"thinkos-capture-<mode>","topic":"<short slug, 5–10 words>"},"output":"<vault relative path>","mode":"append","bytes":<bytes of this draft>}\n'
)
```

The `topic` field is **required, not optional** — it's what enables the next capture to detect semantic overlap without re-reading vault content. Use a 5–10 word slug that captures the gist (e.g., `"git as default vault sync"`, `"role principal designer think co"`).

The `via` field differentiates the mode: `via: thinkos-capture-decision`, `via: thinkos-capture-learning`, `via: thinkos-capture-log`, `via: thinkos-capture-session-recap`. This preserves the audit-trail differentiation that the v0.4.4 topic-overlap dedup relies on.

Privacy keywords: if the draft contains any of `comp, salary, compensation, bonus, raise, offer letter, HR, performance review, PIP, health, medical, family, personal, confidential, private`, write the entry to the vault but add `"redacted": true` to the ledger event and omit detail content fields. The vault file itself is the personal hub — content is fine there; the ledger just doesn't surface the sensitive label.

---

## Step 4 — Confirm

After the write completes, give the user a one-line confirmation:

> Captured to `<vault path>` as a <decision|learning|log entry>. `/thinkos-recent` shows the audit trail.

Don't echo the formatted entry back — it's in the vault now, the user can read it there.

---

## Session-recap mode

This embeds the previous `/thinkos-save` flow verbatim. Run when `--mode session-recap` is forced or when Step 1 falls through.

### Step 0a — Silent triage (do this before asking the user anything)

> **Important context:** Multi-instance Claude usage is normal. A user can run Claude Code in multiple terminals, Cowork tabs, Desktop, and mobile throughout the day. A session recap from any one of those will see ledger entries from OTHER concurrent sessions. **That's parallel work, not a conflict.** Don't treat it as duplication unless the *topics* of recent saves actually overlap with what THIS session would save.

Read the recent conversation context (you already have it loaded — no fetching). Following the format rules below, internally compose:

- 0 or 1 candidate Work Log entry, each with a one-line **topic slug** (5–10 words)
- 0–3 candidate Decisions, each with a topic slug
- 0–3 candidate Learnings, each with a topic slug
- 0–3 candidate People mentions, each with a name

If triage produces zero candidates across all four categories, exit cleanly:

> Session looks trivial — no substantive items to capture this round.

### Step 0b — Topic-overlap dedup check (silent unless real overlap found)

Read recent manual-save topics from the capture ledger:

```bash
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
tail -50 "$VAULT/90 System/Capture Log.md" 2>/dev/null \
  | grep '"source":"manual"' \
  | grep -oE '"topic":"[^"]+"' \
  | sort -u \
  | tail -15
```

For each topic from the ledger, judge semantically whether it overlaps with any of THIS session's candidate topics from Step 0a.

- **No semantic overlap** → proceed silently to Step 1. Do NOT surface the recent saves to the user. (They're from concurrent sessions doing different work.)
- **Semantic overlap on one or more candidates** → use `AskUserQuestion` (one question per overlapping pair):
  - Header: "Possible duplicate"
  - Question: `Topic "<your candidate slug>" looks similar to a recent save: "<matching ledger topic>". Save anyway, or skip this one?`
  - Options:
    | label | description |
    |---|---|
    | "Save anyway" | "Different angle / additional detail not in the prior save." |
    | "Skip — duplicate" | "Prior save covers this." |

  Non-overlapping candidates proceed to Step 1 without prompting.

When in doubt about overlap, lean toward NOT prompting. False positives (asking about a non-duplicate) are worse than false negatives (saving something redundant) — the user can still decline at the per-draft chip-picker. The earlier blunt "any recent save → prompt" rule was wrong; correct it by using meaning, not timestamps.

### Step 1 — Triage what to save

Identify candidate entries across four categories. **Be honest** — if a category has no real items, that category produces zero drafts.

**Work Log entry** (usually 1, sometimes 0). A 4–8 sentence narrative of what was worked on. What shipped, what didn't, the WHY behind the choices. Reference commits or version numbers if mentioned. Skip if the session was pure exploration / Q&A with no concrete work shipped.

**Decisions** (0–3). A *standing* rule or principle adopted during the session. Format:

```
### YYYY-MM-DD · <Topic — one short phrase>

<2–4 sentence body capturing the decision.>

**Why:** <The reason. Often the past pain point that prompted the decision.>
**How to apply:** <When this rule kicks in. Concrete trigger conditions.>
```

Skip if the session was tactical execution with no general rules formed.

**Learnings** (0–3). A *reusable pattern* observed. Format:

```
### YYYY-MM-DD · <Pattern name>

<Observation — what was learned, stated as a pattern.>

**When to apply:** <Specific situations where this insight kicks in.>

<Optional: back-pointer to the conversation moment that surfaced it.>
```

Skip if the session was purely execution, no patterns observed.

**People mentions** (0–3). New colleagues / clients / external contacts mentioned for the first time. Skip if they're already in the user's vault.

### Step 2 — Present drafts via chip-picker

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

If user picks **Edit**, prompt for the replacement text, then show the edited version with the same three options.

Walk through drafts one at a time — Work Log first, then each Decision, then each Learning, then each Person.

### Step 3 — Write approved drafts

For each queued draft, append via `mcp__basic-memory__edit_note`:

| Type | identifier | operation |
|---|---|---|
| Work Log | `Work Log` | `append` |
| Decision | `Decisions` | `append` |
| Learning | `Learnings` | `append` |
| Person | `People` | `append` |

For each write, append one ledger event with `via: thinkos-capture-session-recap` and the `topic` slug from Step 0a. The `topic` field is required — without it, future dedup falls back to noisy timestamp-only checks.

### Step 4 — Reindex + report

After all writes complete:

```bash
basic-memory reindex --project think-os 2>&1 | tail -3
```

Then summarize:

> Saved <N> entries to your vault:
>   <count> Work Log · <count> Decisions · <count> Learnings · <count> People
>
> Reindexed. `/thinkos-recent` will show them in the audit ledger.

If the user picked Skip for everything:

> Nothing saved — all drafts skipped. Run `/thinkos-capture` again later if you change your mind.

---

## Hard rules

- **Never write without approval** in session-recap mode. Single-item modes (decision/learning/log) write directly after parsing — that's by design.
- **Personal hub only.** Saved entries land in the personal hub regardless of active vault.
- **No client names.** Per Identity guardrail #7. If the content references clients by name, redact them as `[client]` in drafts before showing.
- **Honesty about triviality.** If a session-recap surfaces no substance, say so and exit.
- **Don't duplicate yourself.** In session-recap mode, the Step 0a/0b dedup check is mandatory. Use semantic overlap, not timestamp proximity.
- **Be terse.** Drafts read like the user's own writing — direct, no padding.

User message: $ARGUMENTS
