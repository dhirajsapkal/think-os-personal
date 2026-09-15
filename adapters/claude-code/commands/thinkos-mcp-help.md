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

Operations for `edit_note`: `append`, `prepend`, `replace`, `find_replace`, `insert_after_section`.

---

## Retrieval doctrine — how agents read the vault efficiently

This is the reference card. Every Think OS playbook follows these rules; agents answering ad-hoc questions should too.

**1. Search lean, escalate on miss.** Mandated first-action searches run with `page_size=3` (measured: ~520 tokens vs ~1,620 at `page_size=10`, with top-3 recall held). On a miss, escalate in order: `page=2` → `page_size=10` → `read_note` of the best candidate. Don't start wide.

**2. Snippets are pointers, not sources.** Never quote or synthesize from a search-result snippet without reading the source span first. A snippet tells you *where* the answer lives; `read_note` (or a scoped extraction) is what grounds the answer.

**3. No same-session re-reads.** If a note was read this session, refer to context. Re-read only if it may have changed — and then only the relevant range.

**4. `build_context`: text mode, explicit timeframe.** Always pass `output_format="text"` and an explicit `timeframe` — the default 7d silently drops older relations, which looks like missing data but isn't. Its bodies are truncated at 4k: treat them as pointers requiring `read_note` before quoting.

**5. Small HOT files: whole-file reads are correct.** Identity (~1.2k tokens) and Current Focus (~1.65k) are read in full via `read_note`. Verbatim reads are the grounding — don't optimize them away.

**6. Large files: never read in full.** Scoped extraction patterns (read-only shell reads of vault files are allowed and preferred for large files; vault *writes* always go through Basic Memory):

| File | ~Size | Scoped-read pattern |
|---|---|---|
| `01 Now/Work Log.md` | ~9.3k tokens | `bash <repo>/scripts/thinkos-recent.sh --worklog --days N --json` (fallback: `search_notes` with `after_date`) |
| `90 System/Capture Log.md` | ~6.5k tokens | `tail -n 30` of the file (read-only) — the dedup check only needs the recent tail |
| `01 Now/Tasks.md` | ~4k tokens | Extract the `## Today` section (and `## This week` if present) via `sed -n` / `awk` (fallback: `read_note`) |

---

## How to ask — natural language examples

The agent translates your intent to the right tool call. You don't need to know which tool is used.

| What you say | What the agent does under the hood |
|---|---|
| "What do I know about Alex Park?" | `search_notes("Alex Park", page_size=3)` — escalate on miss |
| "What did I decide about auth patterns?" | `search_notes("decisions auth patterns", page_size=3)` |
| "Show me my current focus" | `read_note("Current Focus")` |
| "What learnings do I have tagged #facilitation?" | `search_notes("learnings #facilitation", page_size=3)` — widen to 10 only if the top 3 miss |
| "Load context on the Acme Health project" | `read_note("02 Projects/Acme Health")` then `build_context(["Acme Health"], output_format="text", timeframe="90d")` |
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

To query a specific vault explicitly, tell the agent: "search my personal vault for X" or "look in the Acme Health project vault for Y".

---

## Freshness and the index

Basic Memory indexes your vault on disk. If you edit files in Obsidian, an external editor, or via a desktop agent task, the index may lag.

To sync: run `/thinkos-refresh` (calls `basic-memory reindex --project think-os` under the hood).

## Vault index vs. runtime tools — two separate surfaces

This is the part that most often confuses agents. There are two unrelated MCP surfaces, and conflating them leads to wrong "X is unavailable" answers.

| Surface | What it is | What it gives you |
|---|---|---|
| **Vault index** (this skill, `mcp__basic-memory__*`) | Full-text + semantic search over the markdown files in your vault | Identity, decisions, learnings, people, project notes, work log — everything *already captured* |
| **Runtime bridge** (`mcp__claude_ai_*`) | The claude.ai marketplace bridge — connectors enabled in your claude.ai account surface as deferred MCP tools in Claude Code | Direct read/write against Gmail, Slack, Calendar, Drive, Notion, Atlassian, ClickUp, etc. — independent of the vault |

The vault index does NOT pull from Gmail/Slack/Calendar — that's the desktop agent / continuous-capture's job. If `01 Now/Tasks.md` is stale, ask the desktop agent to run the connector-sync workflow.

But the runtime bridge gives the agent direct access to those services right now, even before anything has been captured. Check `claude mcp list` for entries prefixed `claude.ai *` (e.g. `claude.ai Slack: ✓ Connected`). Their tools are namespaced `mcp__claude_ai_<Service>__<tool>` and load on demand via `ToolSearch`. The `70-claude-ai-bridge.md` block in the curated instructions has the full protocol.

So "the vault doesn't have your Slack messages yet" and "the agent can't reach Slack" are different statements. The first one is often true; the second one is almost certainly false if `claude mcp list` shows a bridge entry.

---

## Troubleshooting

- **"MCP unavailable"** — Basic Memory isn't registered or the server isn't running. Check: `claude mcp list`. Re-register: `claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os`.
- **Search returns nothing** — try `/thinkos-refresh` first, then retry. If the vault is new, the templates may still be placeholders with no real content.
- **Wrong vault targeted** — check `cat ~/.thinkos/active-vault` and `cat ~/.thinkos/vaults.json`. Use `/thinkos-vault` to switch.
