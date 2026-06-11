---
description: Show what you know about a specific person
permalink: think-os/adapters/claude-code/commands/thinkos-who
---

Search the personal context OS for the person named in arguments:

```
mcp__basic-memory__search_notes(query="$ARGUMENTS", page_size=3)
```

On a miss, escalate: page=2, then page_size=10, then `read_note` of the best candidate. Snippets are pointers — read the person's entry before synthesizing from it.

**Aliases.** People entries may carry an `aliases:` field (frontmatter on a per-person note, or an `- aliases:` line under the person's heading in `03 People/People.md`) listing nicknames, short forms, and handles (e.g. `aliases: [AJ, @ajchen, Alex]`). Match the queried name against canonical names AND aliases — "AJ" should resolve to "Alex J. Chen" if the alias is recorded. If the literal query misses but an alias-bearing entry plausibly matches, treat it as the hit and say which alias matched.

Return their canonical name (matching `03 People/People.md` heading), role, organization, current projects with this person, last touched, any "Avoid" flags. If multiple matches, show top 3 with confidence.

If no hit, say so explicitly and offer to add them via `mcp__basic-memory__edit_note(identifier="People", operation="append", ...)` if I want to capture.

**New-name capture.** When the user refers to a known person by a name/handle not yet recorded (e.g. they say "Sandy" and the entry only knows "Sandra Liu"), offer once to add it to that entry's `aliases:` list via `edit_note` `find_replace` — confirm before writing.

User arguments: $ARGUMENTS
