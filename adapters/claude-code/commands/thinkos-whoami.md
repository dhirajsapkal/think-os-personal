---
description: Quick identity + role + current focus
permalink: think-os/adapters/claude-code/commands/thinkos-whoami
---

**No re-reads:** if identity / Current Focus were already loaded this session, do not re-issue these searches/reads — answer from context.

Load my personal context from the OS:
- `mcp__basic-memory__search_notes("identity", page_size=3)` — role, working style, guardrails. Escalate on a miss: page=2, then page_size=10, then `read_note` of the best candidate.
- `mcp__basic-memory__read_note("Current Focus")` — this week's priorities (small HOT file; whole-file read is correct)

Then give a 4-line summary: who I am (role, employer, location), what my guardrails are (1-2 most relevant), what my priorities this week are. Skip preamble.
