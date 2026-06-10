---
description: Refresh Basic Memory's index after external edits
permalink: think-os/adapters/claude-code/commands/thinkos-reindex
---

Refresh Basic Memory's view of the personal context OS so any external edits (made in Obsidian, an editor, or by desktop agent's scheduled tasks) are picked up:

1. Resolve the active vault's `bm_project` from `~/.thinkos/active-vault` and `~/.thinkos/vaults.json`. If neither is set, fall back to `think-os`. Then run via Bash tool:

```bash
BM_PROJECT="$(python3 -c "
import json, os
v = json.load(open(os.path.expanduser('~/.thinkos/vaults.json')))
try:
    av = open(os.path.expanduser('~/.thinkos/active-vault')).read().strip()
    print(next(x['bm_project'] for x in v['vaults'] if x['id'] == av))
except (FileNotFoundError, StopIteration):
    print(next(x['bm_project'] for x in v['vaults'] if x.get('default')))
" 2>/dev/null || echo "think-os")"
basic-memory reindex --project "$BM_PROJECT"
```
2. After it completes, call the Basic Memory recent-activity tool to show what's changed in the last day
3. Show `01 Now/Tasks.md` staleness: read its `last_synced` frontmatter and report how stale it is

**Important boundary**: this command refreshes the INDEX. It does NOT pull fresh data from connectors (email / chat / project tracker). If `01 Now/Tasks.md` is stale, suggest `/thinkos-refresh` — the connector-sweep command that pulls from Gmail / Slack / Calendar / ClickUp / Atlassian / Notion / Granola via the claude.ai bridge or native MCPs.

If you want a one-shot natural-language equivalent: "refresh basic-memory and show me what changed."
