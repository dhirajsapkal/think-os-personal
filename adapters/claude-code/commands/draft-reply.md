---
description: "Draft a reply to an email, Slack message, or comment. ALWAYS produces a draft for review — never sends."
permalink: think-os/adapters/claude-code/commands/draft-reply
---

Draft a reply to an inbound communication. **This command always produces a draft for review. It never sends anything.**

## Step 1 — Load context

1. Search `mcp__basic-memory__search_notes("identity")` to load the user's voice and role.
2. If the message mentions a person by name, search `mcp__basic-memory__search_notes("<name>")` to load relationship context.

## Step 2 — Invoke the scribe subagent (if available)

If the `draft-reply` skill is installed, delegate:

```text
Skill("draft-reply", args="$ARGUMENTS")
```

The skill handles tone-matching, Voice Profile loading, and output formatting. Return its output directly.

## Step 3 — Inline drafting (fallback)

If the skill is unavailable, draft inline:

1. **Identify medium** — email, Slack, PR comment, GitHub issue, other.
2. **Load Voice Profile** — read `05 Profile/Voice Profile.md` via `mcp__basic-memory__read_note` if it exists.
3. **Draft the reply** — match the user's documented tone. Keep it direct; no filler phrases.
4. **Show the draft** in a clearly labelled block:

```
--- DRAFT (review before sending) ---
<draft text here>
--- END DRAFT ---
```

5. Offer: "Want me to adjust tone, length, or emphasis before you send?"

## Hard rules

- **NEVER send, post, or submit the draft.** Surface it for review only.
- **NEVER fabricate facts** about the recipient or context. Use only what the user provides or the vault contains.
- If the user asks you to send it directly, refuse: "I can prepare the draft, but I can't send it — you'll need to copy and send it yourself."

## Example invocations

- `/draft-reply` — draft a reply to whatever the user pastes in
- `/draft-reply --medium slack` — hint the medium for tone calibration

User message: $ARGUMENTS
