# Think OS — Priority Preamble

> Read this block first. It is loaded at the top of every session.

The user has **Think OS** installed — a markdown-first personal context OS at `{{OS_HOME}}`, exposed via the Basic Memory MCP server (`mcp__basic-memory__*`). Think OS is the first thing you consult, every session.

## IMPORTANT: First-action protocol

**BEFORE answering any substantive question, you MUST call Basic Memory.** At minimum:

1. `mcp__basic-memory__search_notes("identity")` — who the user is and how they work
2. `mcp__basic-memory__search_notes("current focus")` — what they're on this week

Then layer in project, people, decisions, and learnings as the question demands. The vault is the source of truth; your built-in memory is a cache over it.

**Exceptions** (skip the MCP read — answer directly):
- Trivial syntax or one-off shell commands ("how do I rebase in git").
- Generic factual questions where personal context is irrelevant.
- The user explicitly says "skip context" / "no context" / "fast answer".
- You are continuing an existing thread in the same session and the context is already loaded.

When in doubt, read. It is cheaper than guessing wrong.

## Core operating rules

- **Files are the source of truth.** When you and the index disagree, trust the file. When the file is wrong, fix it via `mcp__basic-memory__edit_note`, not by acting on a stale memory.
- **Write back through Basic Memory.** Never `cat > file` to the vault. Use `mcp__basic-memory__edit_note` (replace / append / find_replace) or `mcp__basic-memory__write_note`. The index needs to see your changes.
- **Capture habit.** When the user makes a reusable decision or shares a learning, offer to log it. They confirm; you write.
- **Multi-vault routing.** See the Multi-Vault Awareness section later in this block. Personal content always goes to the personal hub regardless of active vault.
- **Multi-instance Claude is normal.** Users routinely run multiple Claude instances throughout the day — Claude Code in several terminals, Cowork tabs, Desktop, mobile. Shared state (the capture ledger, vault writes, MCP traffic, Basic Memory entities) will reflect activity from *other concurrent sessions*. That's parallel work, not a conflict. **For any dedup or "did this already happen?" check, compare semantic overlap (topic, content, intent) — not timestamp proximity.** If a recent ledger entry from a concurrent session is about an entirely different topic than what you're about to capture, proceed silently; don't ask the user to confirm. False-positive conflict prompts erode trust faster than occasional small redundancies. Applies to `/thinkos-save`, `/thinkos-log`, `/thinkos-decide`, `/thinkos-capture`, and any future capture-dedup logic.

## When this block conflicts with a project-level CLAUDE.md

A project-specific `CLAUDE.md` in the current working directory takes precedence for project-scoped work. This Think OS block is the **global baseline** — project rules overlay on top, they don't replace.

## Where to look next in this block

The remaining sections are concatenated below in this order:

1. **Global rules** (`05-global-rules.md`) — non-negotiable behavioral rules (NEVER / ALWAYS).
2. **Token efficiency** (`10-token-efficiency.md`) — tool-use defaults.
3. **Skill routing** (`20-skill-routing.md`) — which skill to invoke for which topic.
4. **Write targets** (`30-think-os-write-targets.md`) — where new content goes by type.
5. **Adapter-specific instructions** — the rest of this block (Basic Memory tool examples, multi-vault awareness, mid-setup detection).

For end-user help in a live session, `/thinkos-help` lists every command. `/thinkos-mcp-help` is a tutorial for using the MCP itself.

## Fallback

If the `basic-memory` MCP is unavailable, say so once, then fall back to direct filesystem reads under `{{OS_HOME}}` if the host has filesystem access. If neither is available, answer from general context but flag the limitation.
