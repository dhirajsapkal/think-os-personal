---
title: Voice Profile
aliases:
- voice-profile
- writing style
type: note
permalink: think-os/voice-profile
tier: WARM
last_reviewed: {{YYYY-MM-DD}}
---

# Voice Profile

How I actually write, vs. how AI defaults to writing. Append a rewrite delta every time I rewrite an AI draft (use `/voice-rewrite`) so the agent's voice modeling gets sharper over time.

This is the file that makes drafts sound like me instead of like generic AI.

---

## Core rules (hand-curated, updated quarterly)

Stable patterns about my voice. Don't append here from `/voice-rewrite` — let those land in the Rewrite log section below, then promote into this list at quarterly review.

- {{e.g., "Drop the 'Hey [name]!' opener in Slack DMs — go straight to the point"}}
- {{e.g., "Em-dashes are fine in long-form; in Slack, replace with periods"}}
- {{e.g., "Don't end emails with 'Let me know if you have questions' — pick a specific next step or stop"}}
- {{e.g., "Lead with the recommendation, then the why; never the other way around"}}
- {{e.g., "If I'm declining, say so in the first sentence — no preamble"}}

## Channel-specific notes

- **Slack DM**: {{e.g., "1-3 sentences max; no signoff; cap with a question mark or a next step"}}
- **Slack channel**: {{e.g., "Slightly more context; lead with TL;DR if more than 4 lines"}}
- **Email**: {{e.g., "First sentence = ask or update; never bury the lede"}}
- **Doc / proposal**: {{e.g., "Structured prose, headers, no consultancy speak"}}
- **Spoken / meeting**: {{e.g., "Punchier than written; rhetorical pauses encouraged"}}

---

## Rewrite log

Append-only. New entries at the top via `/voice-rewrite`. Re-promote stable patterns into "Core rules" at quarterly review.

### {{YYYY-MM-DD}} — {{channel}} — {{short context}}
- **AI wrote**: {{verbatim AI draft}}
- **I wrote**: {{verbatim my rewrite}}
- **Rule extracted**: {{the concrete lesson}}

---

*Quarterly review: promote stable rules from log → Core rules; archive log entries older than 6 months.*
