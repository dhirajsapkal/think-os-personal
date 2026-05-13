---
description: Capture an AI draft vs my rewrite into 05 Profile/Voice Profile.md so the agent
  learns my voice
permalink: think-os/adapters/claude-code/commands/voice-rewrite
---

Append a rewrite delta to `05 Profile/Voice Profile.md` so the agent's voice modeling improves over time. The user's input ($ARGUMENTS) contains either:

1. **A before / after pair** — the agent's draft, then how I actually said it. Format hints: separated by `|`, `→`, `vs`, newlines with labels like "AI:" / "Me:", or whatever's clear from context.
2. **A standalone positive sample** — just a message I wrote that should be studied as a reference pattern.

Identify which case it is, identify the channel (Slack / Email / Spoken / Doc) from context, and shape the entry like this:

For a before/after pair:

```markdown
### YYYY-MM-DD — <channel> — <short context>
- **AI wrote**: <verbatim>
- **I wrote**: <verbatim>
- **Rule extracted**: <the lesson — concrete, e.g., "drop the 'Hey [name]!' opener in Slack DMs; jump straight to the point" or "no em-dashes in short replies — replace with periods">
```

For a positive sample:

```markdown
### YYYY-MM-DD — <channel> — positive sample
- **I wrote**: <verbatim>
- **What's worth copying**: <2-3 specific patterns to absorb — sentence structure, vocab, signoff, etc.>
```

Use today's date. Then call:

```
mcp__basic-memory__edit_note(
  identifier="Voice Profile",
  operation="insert_after_section",
  section="## Rewrite log",
  content="<formatted entry, with a blank line before>"
)
```

This places the new entry at the top of the Rewrite log section (newest-first convention).

If `05 Profile/Voice Profile.md` doesn't load or the rule isn't clear from $ARGUMENTS, ask ONCE for the missing piece (usually: "what was the rule you want me to take away from this?") before writing.

Confirm written and quote the rule extracted in one short line.

User message: $ARGUMENTS
