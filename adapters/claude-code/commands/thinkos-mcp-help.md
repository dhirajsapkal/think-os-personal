---
description: How to query and update your personal context MCP server
permalink: think-os/adapters/claude-code/commands/thinkos-mcp-help
---

A guide to interacting with Basic Memory — the MCP server that indexes your Think OS vault and makes it queryable by any agent.

---

## The core tools

You almost never call these directly. Ask in natural language; the agent picks the right tool.

| Tool | What it does |
|---|---|
| `search_notes(query, page_size)` | Full-text + semantic search across all vault files |
| `read_note(identifier)` | Read a specific note by title or path |
| `write_note(title, content, folder)` | Create a new note (agent always shows draft first) |
| `edit_note(identifier, operation, content)` | Append, prepend, or replace content in an existing note |
| `recent_activity(timeframe)` | Show what changed recently in the vault |
| `build_context(topics)` | Load a rich multi-note context around a set of topics |

Operations for `edit_note`: `append`, `prepend`, `replace`, `insert_after_section`.

---

## How to ask — natural language examples

The agent translates your intent to the right tool call. You don't need to know which tool is used.

| What you say | What the agent does under the hood |
|---|---|
| "What do I know about Maya Chen?" | `search_notes("Maya Chen", page_size=5)` |
| "What did I decide about auth patterns?" | `search_notes("decisions auth patterns")` |
| "Show me my current focus" | `read_note("Current Focus")` |
| "What learnings do I have tagged #facilitation?" | `search_notes("learnings #facilitation", page_size=10)` |
| "Load context on the Argenx project" | `read_note("02 Projects/Argenx")` then `build_context(["Argenx"])` |
| "What changed in my vault today?" | `recent_activity("1d")` |

---

## The capture habit

When you make a decision or share a reusable insight during a session, the agent will offer:

> Worth logging in Learnings? I can add it with tags [suggested].

If you confirm, the agent calls `edit_note` with `operation: append`. It always shows you the formatted entry before writing — you can edit or reject it.

**Where things land:**

| Content type | Destination file |
|---|---|
| Reusable insight or pattern | `04 Knowledge/Learnings.md` |
| Standing decision | `04 Knowledge/Decisions.md` |
| New person | `03 People/People.md` |
| Session note | `01 Now/Work Log.md` |
| New project | `02 Projects/Project Index.md` + `02 Projects/<slug>.md` |

---

## Writes are always drafted first

The agent never writes to your vault without showing you the proposed content. The flow is:

1. Agent proposes what it wants to write (formatted entry, correct file).
2. You approve (or edit, or say no).
3. Agent calls `edit_note` or `write_note`.
4. Agent confirms what was written.

---

## Multi-vault: scoping queries

If you have more than one vault registered (`~/.thinkos/vaults.json`), each has a `bm_project` ID. The agent scopes MCP calls to the right vault automatically based on the active vault.

To switch active vault: run `/thinkos-vault` and choose "use". Or:

```bash
echo "my-project-vault-id" > ~/.thinkos/active-vault
```

When active vault is a project vault, the agent queries both the project vault and your personal hub, and prefixes results with `[personal]` or `[project-name]` so you know where each result came from.

To query a specific vault explicitly, tell the agent: "search my personal vault for X" or "look in the Argenx project vault for Y".

---

## Freshness and the index

Basic Memory indexes your vault on disk. If you edit files in Obsidian, an external editor, or via a desktop agent task, the index may lag.

To sync: run `/thinkos-reindex` (calls `basic-memory reindex --project think-os` under the hood).

The index does NOT pull new data from connectors (email, Slack, calendar). That's the desktop agent's job — ask it to run the connector-sync workflow if `01 Now/Tasks.md` is stale.

---

## Troubleshooting

- **"MCP unavailable"** — Basic Memory isn't registered or the server isn't running. Check: `claude mcp list`. Re-register: `claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os`.
- **Search returns nothing** — try `/thinkos-reindex` first, then retry. If the vault is new, the templates may still be placeholders with no real content.
- **Wrong vault targeted** — check `cat ~/.thinkos/active-vault` and `cat ~/.thinkos/vaults.json`. Use `/thinkos-vault` to switch.
