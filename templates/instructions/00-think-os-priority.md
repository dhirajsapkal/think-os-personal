# Think OS — Priority Preamble

> Read this block first. It is loaded at the top of every session.

The user has **Think OS** installed — a markdown-first personal context OS at `{{OS_HOME}}`, exposed via the Basic Memory MCP server (`mcp__basic-memory__*`). Consult it before answering anything substantive.

## IMPORTANT: First-action protocol

**BEFORE answering any substantive question, call Basic Memory.** At minimum:

1. `mcp__basic-memory__search_notes("identity", page_size=3)` — who the user is and how they work
2. `mcp__basic-memory__search_notes("current focus", page_size=3)` — what they're on this week

Layer in project, people, decisions, and learnings as needed. The vault is the source of truth; your built-in memory is a cache over it.

**Retrieval doctrine** (every vault read):

- Mandated first-action searches run with `page_size=3`. Escalation ladder on miss: `page=2`, then `page_size=10`, then `read_note` of the best candidate.
- Snippets are pointers: never quote or synthesize from a search snippet without reading the source span first.
- No same-session re-reads: if a note was read this session, refer to context.
- Whole-file `read_note` stays correct for small HOT files (Identity, Current Focus) — verbatim reads are the grounding; do not optimize them away.
- Large files (Work Log, Capture Log, Tasks) are never read in full — see Token Efficiency.

**Exceptions** (skip the mandated reads): trivial syntax / one-off shell commands; generic factual questions; the user says "skip context" / "fast answer"; continuing a thread with context already loaded; or a **project-local generic question** — ALL of: CWD is a registered project (`vaults.json`, `type: project`), the question mentions none of "I"/"me"/"my"/"we"/"our", a person's name, or "identity"/"focus"/"decisions"/"learnings"/"vault"/"week", and it is a how-to / factual / single-file pattern. When ANY criterion is uncertain, read — when in doubt, read.

## Core operating rules

- **Files are the source of truth.** When you and the index disagree, trust the file; fix wrong files via `mcp__basic-memory__edit_note`, not by acting on a stale memory.
- **Vault WRITES go through Basic Memory** (`edit_note` / `write_note`) — never `cat >` into the vault; the index needs to see changes. Deterministic READ-ONLY shell extraction (`tail`, `sed`/`awk`) is allowed and preferred for large files.
- **Capture habit.** When the user makes a reusable decision or shares a learning, offer to log it. They confirm; you write.
- **Multi-instance Claude is normal.** Shared state (capture ledger, vault writes, BM entities) reflects concurrent sessions — parallel work, not conflict. For any dedup check, compare semantic overlap (topic, content, intent), not timestamp proximity; different topic → proceed silently.
- A project-level `CLAUDE.md` in the CWD takes precedence for project-scoped work; this block is the global baseline.

## Where to look next in this block

1. **Global rules** (`05`) — non-negotiable NEVER / ALWAYS rules.
2. **Token efficiency** (`10`) — tool-use defaults + large-file read rules.
3. **Skill routing** (`20`) — topic → skill map.
4. **Write targets** (`30`) — content-type routing + multi-vault rules.
5. **Emergent seeding** (`40`) — core; save flow in the `thinkos-emergent-seeding` skill.
6. **Drift detection** (`50`) — one terse staleness nudge at end of turn.
7. **Shared mode** (`60`) — redaction core; full spec in the `thinkos-shared-mode` skill.
8. **Claude.ai bridge** (`70`) — stub; full guide in the `thinkos-bridge` skill.
9. **Adapter-specific instructions** — multi-vault resolution, mid-setup detection.

`/thinkos-help` lists every command. `/thinkos-mcp-help` is the MCP tutorial.

**Fallback:** if the `basic-memory` MCP is unavailable, say so once, then fall back to direct filesystem reads under `{{OS_HOME}}` if available; otherwise answer from general context and flag the limitation.
