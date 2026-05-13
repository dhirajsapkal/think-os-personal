---
type: setup-guide
tags:
- setup
- adapters
- desktop-agent
- mcp
- global
- automation
permalink: think-os/setup-global-integration
---

# Setup — Global Integration

One-time setup to make your OS the durable memory layer for the agentic tools you use.

Prefer the product-specific adapters first:

- [`../adapters/claude-cowork/README.md`](../adapters/claude-cowork/README.md)
- [`../adapters/claude-code/README.md`](../adapters/claude-code/README.md)
- [`../adapters/codex/README.md`](../adapters/codex/README.md)

Use this guide for the shared pattern behind those adapters and for scheduled maintenance ideas.

**Time**: ~20 minutes total
**Prereqs**: Basic Memory installed and working (see `setup-basic-memory.md`); at least one MCP-aware tool you want to wire in

**Variable used throughout**: `{{OS_HOME}}` = the folder where your live OS files live. Should be identical to the path you registered with Basic Memory in the previous guide.

---

## Part 1 — Wire Basic Memory Into A CLI Agent (~5 min)

Many CLI agents have their own MCP config separate from desktop apps. Register Basic Memory at **user scope** when the tool supports it so the MCP is available in every session regardless of cwd.

### Claude Code example

Add the MCP at user scope:

```bash
claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os
```

Breakdown:
- `claude mcp add basic-memory` — register an MCP named "basic-memory"
- `--scope user` — applies to ALL projects (vs `--scope project` per-cwd, or default `--scope local` just current session)
- `--` — separator
- `basic-memory mcp --project think-os` — the actual Basic Memory server command

Verify:

```bash
claude mcp list
```

Should show `basic-memory` connected. Test:

```bash
cd ~
claude
```

Inside Claude Code, ask: *"Use Basic Memory tools to find my identity"* — should return hits from `identity.md` even though you're in your home directory.

Troubleshooting:

If `command not found: basic-memory`, use the full path:

```bash
claude mcp add basic-memory --scope user -- /full/path/to/basic-memory mcp --project think-os
```

(Replace path with whatever `which basic-memory` returns.)

Remove + re-add:

```bash
claude mcp remove basic-memory --scope user
```

---

## Part 2 — Add Global Tool Instructions (~5 min)

Most agentic tools have some form of global instructions, custom instructions, or user memory. Add the Think OS behavior there. For Claude Code, that file is `~/.claude/CLAUDE.md`.

### Claude Code example

Open or create the file:

```bash
mkdir -p ~/.claude
nano ~/.claude/CLAUDE.md
```

Paste this content. If the file already has content, paste this section at the top.

```markdown
# Global instructions — Think OS

My personal context OS lives at {{OS_HOME}} and is accessible through the `basic-memory` MCP server.

## Always available: Basic Memory MCP

Before answering anything substantive, use Basic Memory tools (selectively — don't load everything every session):

- `mcp__basic-memory__search_notes("identity")` — my role, working style, guardrails
- `mcp__basic-memory__search_notes("active projects")` — project index
- `mcp__basic-memory__search_notes("current focus")` — this week's priorities
- `mcp__basic-memory__search_notes("os instructions")` — meta-rules
- `mcp__basic-memory__read_note("TASKS")` — connector-synced inbox
- `mcp__basic-memory__read_note("people")` — colleagues / clients
- `mcp__basic-memory__search_notes("learnings " + topic)` — prior reusable patterns

For trivial questions (factual lookup, code completion, syntax), skip the OS query — it's overhead. For anything about my work, projects, people, or decisions, load the relevant slice.

## Project detection by cwd

If `cwd` is under a known project root, that's a known project. Pull its deep file:

```
mcp__basic-memory__search_notes("active-projects/" + <project-slug>)
```

## Freshness check (before relying on HOT files)

Check `last_reviewed` / `covers_week` frontmatter. Flag staleness:

- HOT files (`identity`, `active-projects`, `os-instructions`) stale > 7 days → mention
- `current-focus` past its `covers_week` end → must flag before "what am I working on this week"
- `TASKS` last_synced > 24 hours → offer to run `productivity:update`

## Capture habit (write back to the OS)

When I make a decision or share a learning that has any chance of being reusable on a future project, offer to capture it:

> "Worth logging in learnings.md? I can add it with tags [suggested]."

If yes, append via `mcp__basic-memory__edit_note(identifier="Learnings", operation="append", content="...")`.

Other capture targets:
- New person mentioned → offer to add to `people.md`
- Standing decision → offer to add to `decisions.md`
- New active task → offer to append to `TASKS.md` Manually-added section
- New project surfaces → row in `active-projects.md` AND stub at `active-projects/<slug>.md`

Default write targets: {{OS_HOME}} for memory/notes; project subfolder for project work. Never write above project folders unless explicitly told.

## Communication style

Terse, direct. Skip preamble. Surface tradeoffs explicitly. When unsure, ask — don't paper over uncertainty. Code / file refs in `path:line` format. Exploratory question? 2-3 sentences + recommendation.

## Frontend / UI work — load a design skill first

For any task producing frontend code / UI mocks / design tokens / visual artifacts: load `/frontend-design` (Anthropic plugin) before writing code. Working from Figma? Load `figma:figma-implement-design` or `figma:figma-use` first. Commit to typography + palette + layout philosophy BEFORE implementation. No Inter + purple-gradient defaults.

## Guardrails (mirror of identity.md)

See identity.md for the full list. The hard rule: **draft, never send.** All outbound (email, Slack, comments, PRs, calendar invites) is drafted only — I approve before send.
```

Verify:

Open a fresh Claude Code session in any directory (`cd ~ && claude`). Ask:

> "Who am I and what am I working on?"

You should get a specific answer pulled from `identity.md` + `current-focus.md`. If you get a generic answer, run `claude mcp list` — the MCP may not be reachable.

---

## Part 3 — Add Desktop Agent Instructions (~3 min)

For desktop tools with global personalization/custom instructions, use this MCP-first version:

```
You are operating in my personal context OS. The source-of-truth files live at {{OS_HOME}} and are accessible via the `basic-memory` MCP server.

Before answering anything substantive, query Basic Memory:
- search_notes("identity") — who I am, role, guardrails
- search_notes("active projects") — project index
- search_notes("current focus") — this week's priorities
- search_notes("os instructions") — meta-rules

For "what's on my plate" → also read_note("TASKS")
For people questions → also read_note("people")
For comms drafting → also read_note("business-brain") and relevant active-projects/<slug>
For starting new work → search_notes("learnings " + topic) to surface past patterns

Freshness: flag HOT files stale > 7 days; `current-focus` past `covers_week`; `TASKS` last_synced > 24h.

Capture habit: offer "Worth logging in learnings.md?" when I make a reusable decision or share a learning, and append via edit_note if I confirm. Same for new people (people.md), standing decisions (decisions.md), new tasks (TASKS.md), new projects (active-projects.md + stub).

Default write targets: {{OS_HOME}} for memory/notes; project subfolder for project work. Never write above project folders unless explicitly told.

Communication: terse, direct, no preamble, surface tradeoffs. Path:line for file refs. 2-3 sentences for exploratory questions.

Frontend / UI work — always load a design skill BEFORE code. Commit to typography + palette + layout philosophy first.

Draft, never send (all outbound).

If Basic Memory MCP is unavailable, fall back to direct file reads under {{OS_HOME}}.
```

Save wherever your tool keeps global personalization / custom instructions.

---

## Part 4 — Auto-update cadence (what updates when)

This is the system that keeps the OS current without you remembering to do anything.

| File | Update mechanism | Cadence |
|---|---|---|
| `work-log.md` | Tool hook or manual `/log` | Every session end |
| `TASKS.md` | `productivity:update` skill | Daily (when you ask) OR scheduled |
| `current-focus.md` | `/weekly-review` skill | Sundays (scheduled) |
| `people.md` | Capture-on-mention + monthly mining | Continuous + monthly |
| `decisions.md` | Capture habit | When made |
| `learnings.md` | Capture habit | When made |
| `connectors.md` | Manual quarterly review | Quarterly |
| `active-projects.md` + stubs | Capture-on-mention + quarterly audit | Continuous + quarterly |
| `archive/` | `/quarterly-review` | Quarter start |
| `identity.md`, `business-brain.md` | Annual hand-review | Annually |

### Step 4.1 — Set Up Scheduled Tasks

If your desktop agent supports scheduled tasks, add these:

**Daily 7am — morning brief** (optional, high-value)
- Schedule: daily at 7:00 AM
- Prompt: *"Run morning brief: check TASKS.md staleness; if stale, run productivity:update. Then summarize: today's calendar, top 3 action items, this week's priority. Cap at 200 words."*

**Daily 6pm — TASKS sync** (recommended)
- Schedule: daily at 6:00 PM
- Prompt: *"Run productivity:update --comprehensive against the Think OS project. Refresh TASKS.md with new connector data."*

**Sundays 8pm — Weekly review** (recommended)
- Schedule: weekly, Sunday at 8:00 PM
- Prompt: *"Weekly review: roll over current-focus.md to next week. Capture this week's wins / blockers. Check for stale projects in active-projects.md. Suggest 3-5 priorities for next week based on TASKS.md + calendar."*

**Quarter start — Quarterly audit** (recommended)
- Schedule: quarterly (first day of Q1 / Q2 / Q3 / Q4)
- Prompt: *"Quarterly audit: rotate work-log.md to archive/. Audit active-projects.md (mark dormant ⚪, archive completed). Re-mine connectors for people.md updates. Review connectors.md for staleness."*

### Step 4.2 — Tool Hooks (optional but high-leverage)

To auto-capture session activity into `work-log.md`, add a Stop/session-end hook if your tool supports it. Claude Code example:

```json
{
  "hooks": {
    "Stop": [{"matcher": "*", "command": "~/.claude/hooks/log-session.sh"}]
  }
}
```

The script reads the session transcript and appends a one-paragraph summary to `{{OS_HOME}}/work-log.md`. Failure modes exit 0 to avoid blocking your workflow.

---

## Part 5 — Verification end-to-end

- [ ] Your CLI agent's MCP list shows basic-memory connected
- [ ] Fresh CLI agent session in any project responds specifically to "who am I?"
- [ ] Fresh desktop agent session in any project responds specifically to "who am I?"
- [ ] Scheduled tasks panel shows your chosen schedules, if supported
- [ ] Tool-specific global instruction file exists with Think OS instructions
- [ ] After a few days: `work-log.md` shows new auto-captured entries
- [ ] After a week: `TASKS.md` last_synced is < 24h (auto-refresh working)

---

## What this gets you

- **Every agentic tool knows your OS exists**, when to query it, and how to update it. No more re-explaining context every session.
- **Cross-project queries work everywhere.** "What did I do on Project X that applies to Project Y" works from any directory.
- **The OS self-maintains.** Scheduled tasks refresh `TASKS.md` and `current-focus.md`. Work-log captures session activity. The capture habit prompts surface learnings into searchable form.
- **Failure modes are well-defined.** MCP down → file fallback. Hook breaks → manual `/log`. Scheduled task misses → manual run.

## What's still manual (by design)

- **Capture decisions.** The agent prompts; you confirm. This is human judgment.
- **Yearly identity / business-brain review.** Slow-changing things benefit from deliberate review.
- **Connector setup if new tools appear.** Add to `connectors.md`, register MCP if applicable.

---

*Refresh this guide whenever the architecture changes.*
