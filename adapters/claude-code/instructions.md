# Think OS Instructions For Claude Code

My personal context OS lives at `{{OS_HOME}}` and is accessible through the `basic-memory` MCP server.

## Mid-Setup Detection

At the start of any new conversation, check whether Think OS setup is still in progress:

```bash
test -f ~/.thinkos/wizard-state.json && cat ~/.thinkos/wizard-state.json
```

If the file exists and its `phase` is **not** `complete`, mention it once at the top of your first response:

> Heads up — Think OS setup is mid-flight (phase: `<phase>`). Run `/thinkos-continue` (or say "continue Think OS setup") when you're ready to pick it up.

Do not interrupt the user's actual question to deliver this — surface it as a one-line note before answering whatever they asked. If they pick up the thread, follow the playbook at `adapters/claude-code/commands/thinkos-continue.md`.

## Multi-Vault Awareness

See `docs/multi-vault-architecture.md` for the canonical design (§2 registry, §3 resolution, §8 agent integration).

**On session start:**

```bash
test -f ~/.thinkos/vaults.json && cat ~/.thinkos/vaults.json
```

If absent, treat as single-vault legacy mode (current behavior — no change).

**Active vault resolution (in order):**

1. `cat ~/.thinkos/active-vault` — sticky override (one-line vault id); if present and non-empty, use it.
2. Otherwise check CWD: if `pwd` is under a registered vault's `path`, that vault is active.
3. Otherwise use the vault with `"default": true` (the personal hub).

**First response of every session** — surface one line before answering:

> Active vault: `<id>` (`<label>`). Personal hub (`<personal-id>`) always loaded.

**HOT-tier loading:**

- Always load from personal hub: Identity, Current Focus, OS Instructions.
- If active vault is `type: project`: also load that vault's `00 Project Home.md` and `04 Roster.md`.

**Write routing rules:**

- Active vault is `project` type AND content has personal markers (first-person reflection, or keywords: comp, salary, HR, health, family) → write to personal hub instead. Tell the user: `"This sounds personal — routing to your personal hub instead of the project vault."`
- Content type has no slot in the active vault's schema → write to personal hub.
- Ambiguous → ask before writing.
- If `<vault>/.thinkos/schemas/` exists, validate writes against the destination vault's schema for that content type.

**Basic Memory scoping:**

- Each vault has a `bm_project` field in `vaults.json`. Pass `--project <bm_project>` (or equivalent BM tool scope) to target a specific vault.
- Cross-vault search: query personal hub first; if active vault is a project vault, also query it. Never silently merge results — prefix each vault's results with `[<id>]`.

## Always Available: Basic Memory MCP

Before answering anything substantive, use Basic Memory tools selectively:

- `mcp__basic-memory__search_notes("identity")` for role, working style, and guardrails
- `mcp__basic-memory__search_notes("project index active projects")` for the project index
- `mcp__basic-memory__search_notes("current focus")` for this week's priorities
- `mcp__basic-memory__search_notes("os instructions")` for meta-rules
- `mcp__basic-memory__read_note("Tasks")` for the connector-synced inbox
- `mcp__basic-memory__read_note("People")` for people / stakeholder context
- `mcp__basic-memory__search_notes("learnings " + topic)` for prior reusable patterns

Skip Think OS for trivial syntax, shell, or factual questions where personal/project context is irrelevant.

## Project Detection

If `cwd` is under a known project root, search for that project before answering substantively:

```text
02 Projects/<project-slug>
```

## Freshness

Check frontmatter before relying on HOT files:

- `Identity`, `Project Index`, `OS Instructions` stale > 7 days: mention it
- `Current Focus` past its `covers_week`: flag before answering "what am I working on?"
- `Tasks` last_synced > 24 hours: offer to refresh via the desktop agent / connector workflow

## Capture Habit

When I make a reusable decision or share a learning, offer:

```text
Worth logging in Learnings? I can add it with tags [suggested].
```

If I confirm, append via Basic Memory `edit_note`.

Other capture targets:

- New person: `03 People/People.md`
- Standing decision: `04 Knowledge/Decisions.md`
- New task: `01 Now/Tasks.md`
- New project: `02 Projects/Project Index.md` plus `02 Projects/<slug>.md`

## Write Targets

Default write targets:

- Memory / notes: `{{OS_HOME}}`
- Project work: relevant project subfolder

Never write above project folders unless explicitly told.

## Communication

Direct, concise, no preamble. Surface tradeoffs. Ask when unsure. Use `path:line` for file references.

Draft, never send outbound messages.

## Fallback

If Basic Memory MCP is unavailable, say so and fall back to direct file reads under `{{OS_HOME}}` if filesystem access is available.
