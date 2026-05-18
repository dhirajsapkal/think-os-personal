---
description: Refresh Basic Memory's index after external edits
permalink: think-os/adapters/claude-code/commands/thinkos-reindex
---

Refresh Basic Memory's view of the personal context OS so any external edits (made in Obsidian, an editor, or by desktop agent's scheduled tasks) are picked up:

1. Resolve the active vault's `bm_project` from `~/.thinkos/active-vault` and `~/.thinkos/vaults.json`. If neither is set, fall back to `think-os`. Then run via Bash tool:

```bash
BM_PROJECT="$(python3 -c "
import json, os
try:
    av = open(os.path.expanduser('~/.thinkos/active-vault')).read().strip()
    print(av)
except FileNotFoundError:
    v = json.load(open(os.path.expanduser('~/.thinkos/vaults.json')))
    print(next(x['bm_project'] for x in v['vaults'] if x.get('default')))
" 2>/dev/null || echo "think-os")"
basic-memory reindex --project "$BM_PROJECT"
```
2. After it completes, call the Basic Memory recent-activity tool to show what's changed in the last day
3. Show `01 Now/Tasks.md` staleness: read its `last_synced` frontmatter and report how stale it is

**Important boundary**: this command refreshes the INDEX. It does NOT pull fresh data from connectors (email / chat / project tracker). Those live in desktop agent. If `01 Now/Tasks.md` is stale, tell me to run `/productivity:update` in **desktop agent**, not here.
OR — if `claude mcp list` shows `claude.ai <Service>: ✓ Connected` for the connector you need, the agent can pull fresh data directly via `mcp__claude_ai_<Service>__*` tools without going to desktop agent. Check `70-claude-ai-bridge.md` for the protocol.

If you want a one-shot natural-language equivalent: "refresh basic-memory and show me what changed."
