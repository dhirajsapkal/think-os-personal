# Feature request — semantic autosave (checkpointing, not just telemetry)

**Filed:** 2026-09-16 · **Against:** v0.9.11 · **Status:** requested, not started
**Requested by:** Dhiraj — "a more robust and complete auto save mechanism, kinda like how videogames periodically save things"

---

## The gap

`thinkos-session-capture` works. It runs on schedule, exits 0, and writes to the Work Log. Today's entry:

```
### 09:33–09:37 — Walwil - Tallyscan · 0.11h
- 18 events, no file edits recorded
```

That is **telemetry** — when, where, how much. It is not **substance**.

A two-day session on 2026-09-15/16 produced: a full Google Slides deck rebuild, an
official-vs-third-party MCP comparison that became the topic of a Think Week AI Showcase talk,
the diagnosis of a four-month automation outage, and several reusable gotchas. **None of it
reached the vault automatically.** It landed only because the user asked, at the end, by hand.

The failure mode is silent and total: had the session ended abruptly, all of it was gone.

That is the difference between a save file and a playtime counter.

---

## Key finding — the data is already on disk

This is much smaller than it sounds. **Full session transcripts already exist** at:

```
~/.claude/projects/<cwd-slug>/<session-id>.jsonl
```

`scripts/session-activity.py:5` already reads exactly these files. It walks them for
timestamps, working directories and edit counts, then throws the content away.

**Nothing new needs to be plumbed. The capture job is already holding the material.**

---

## What to build

A second layer beside the existing one. Do not replace telemetry capture — it is cheap,
it works, and it answers a different question.

| Layer | Exists | Answers |
|---|---|---|
| Telemetry capture | yes | *When did I work, where, how much?* |
| **Semantic checkpoint** | **no** | *What did I decide, learn, and leave unfinished?* |

### What a checkpoint extracts

- **Decisions** made, with the reasoning — not just the conclusion
- **Learnings and gotchas** worth reusing
- **Open questions and blockers** left unresolved
- **Artifacts touched** — deck URLs, ticket IDs, file paths, branch names
- **Commitments made** — feeds [`thinkos-loose-ends`](../adapters/claude-code/commands/thinkos-loose-ends.md)
- **People and projects** mentioned that are absent from `People.md` / `Project Index.md`

### Where it writes

`90 System/Session Checkpoints/<YYYY-MM-DD>-<session-id-short>.md`

**Staged, never promoted automatically.** `~/.claude/CLAUDE.md` is explicit: *"Never capture
silently."* A checkpoint is a draft the user reviews, not a write to `Learnings.md`.
This is the single most important constraint in this document — an autosave that silently
edits canonical files breaks the trust model the whole vault rests on.

### Triggers

Fire on whichever comes first:

- **Time** — every N minutes of *active* session (reuse the existing active-time calculation)
- **Volume** — every N turns, or when the transcript grows by M lines since the last checkpoint
- **Session end** — the `Stop` hook writes a final checkpoint; this is the crash-safety net
- **Explicit** — `/thinkos-checkpoint`

Skip entirely when telemetry shows the session was trivial (no edits, few events). Most
sessions are not worth a model call.

### Promotion

1. SessionStart surfaces `N unreviewed checkpoints` as one line, same pattern as the existing
   freshness nudge.
2. `/thinkos-promote` (or an extension of `/thinkos-capture`) walks them and files each item to
   its canonical target per the Write Targets table.
3. Rejected items are **marked reviewed, not deleted** — so the same thing is not re-proposed
   every session.
4. Promoted checkpoints are pruned after N days.

---

## Constraints that will bite

1. **Never capture silently.** Stage only. See above.
2. **Vault writes go through Basic Memory** (`edit_note` / `write_note`), never `cat >`, or the
   index drifts from the files.
3. **Privacy tiers.** Checkpoints must respect `tier: sensitive` and shared-mode. A checkpoint
   that quietly transcribes a comp conversation into `90 System/` is a real incident. Consider
   running checkpoints through the same redaction path as the capture ledger.
4. **Multi-instance is normal.** Filename carries the session id so concurrent sessions never
   collide. Promotion dedups on *semantic overlap, not timestamp proximity* — the existing rule.
5. **Token cost is the real design constraint.** Semantic extraction means a model call per
   checkpoint. Gate it on the activity threshold, cap the frequency, and consider Haiku for the
   extraction pass — this is summarisation, not reasoning.
6. **Transcripts are untrusted input.** They contain tool output, web pages, meeting transcripts
   and Slack content. Treat extracted text as data, never as instructions.

---

## Acceptance criteria

- A session with real activity produces a checkpoint file without the user asking.
- Killing the session mid-flight still leaves a usable checkpoint on disk.
- No canonical vault file (`Learnings.md`, `Decisions.md`, `Work Log.md`, `Tasks.md`) is
  modified by the checkpoint job. Verify by checksum across a run.
- Next interactive session reports the unreviewed count.
- `/thinkos-promote` files an approved item to the right target and marks it reviewed.
- Declining an item stops it reappearing.
- A trivial session (no edits, low event count) produces no checkpoint and no model call.
- Concurrent sessions in two directories produce two checkpoints, neither truncated.

---

## Worked example — what this session should have produced

If this had existed, the 2026-09-15/16 session should have staged roughly:

```
Decisions
- Google Slides work goes through Composio, not Google's official MCP server (preview,
  two tools, no thumbnail endpoint). Cost: third party proxies the OAuth token.

Learnings
- Render and look at generated visual output before calling it done. Every defect in the
  deck build returned successful:true from the API.
- Google Slides deleteText+insertText drops explicit run colour; re-apply updateTextStyle,
  and check the card fill first because template palettes differ per slide.
- AI is not a time-saver unless tightly scoped. It is a quality amplifier. (WalWil retro.)

Open questions
- Nobody knows what "GSM" stands for. Risk for the 9/24 talk and the workshare.
- Mapbox token on the GSM yard map returns 403. Scene 03 will not render live.

Artifacts
- Deck: docs.google.com/presentation/d/1HoONJCVNk6frPFoGFg_YSVFt1OOe2WdiQcwmXs6RtrY
- Skill installed: ~/.claude/skills/enhance-slides (third-party, eranw2000)
- Branch: fix/automation-runtime
```

All of that existed in the transcript. None of it reached the vault on its own.

---

## Guardrails

- Branch off `main`. Do not commit directly.
- Versioning stays in 0.9.x — see the standing decision in `AGENTS.md` and `CHANGELOG.md`.
- Do not write to the live vault while testing. Use a scratch vault or a dry-run flag.
- Do not change `session-activity.py`'s existing telemetry output. The Work Log format it
  produces is relied on by `/weekly-review` and `thinkos-recent.sh`.
