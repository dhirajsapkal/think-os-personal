---
description: Record a standing decision in your vault (alias for /thinkos-capture --mode decision)
permalink: think-os/adapters/claude-code/commands/thinkos-decide
---

**This command now delegates to `/thinkos-capture` with `--mode decision`. Result is identical; one fewer command to remember.**

Follow `adapters/claude-code/commands/thinkos-capture.md` with `$ARGUMENTS` treated as if the user had typed `/thinkos-capture --mode decision $ARGUMENTS`. The canonical playbook handles formatting, ledger event, and confirmation.

**Supersedes convention** (handled by the canonical playbook — restated here because this is the decision entry point): if the new decision replaces an earlier one, the new entry carries `**Supersedes**: <YYYY-MM-DD — old topic slug>` AND the old entry gets a `**Superseded-by**: <YYYY-MM-DD — new topic>` line added via `edit_note` `find_replace`. Both edges are required — `/thinkos-decisions` filters superseded entries out of default answers using the `Superseded-by` marker. If the user's wording implies replacement ("instead of", "changing our rule on", "reversing the earlier call"), search Decisions for the old entry and propose the link.

Show this one-line hint to the user exactly once per session (track via the session-scoped reasoning; do not re-surface on every invocation):

> Routing through /thinkos-capture (same behavior, one fewer command to remember).

User message: $ARGUMENTS
