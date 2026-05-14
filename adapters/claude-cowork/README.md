# Claude Cowork adapter

Think OS support inside Claude Cowork (the agentic tab in Claude Desktop). v0.4 ships **minimal-but-functional**: full vault/memory access, native onboarding chip-pickers, **no slash commands**, **no autonomous capture jobs**.

> **What you'll need to accept:** Cowork uses a different plugin format than Claude Code. We don't ship a Cowork plugin yet (it would require Anthropic marketplace approval and may be blocked by Think Company's org policy anyway). So Cowork users get a thinner integration than Claude Code users. The vault + the agent's behavior is the same; the *invocation surface* is narrower.

---

## What works

- **Vault access** via the `basic-memory` MCP — Cowork shares this with Claude Code through `~/Library/Application Support/Claude/claude_desktop_config.json`.
- **Curated agent instructions** — pasted once into `Settings → Cowork → Edit`. They teach the agent how to use Basic Memory, route writes correctly, surface freshness warnings, etc.
- **Native chip-picker onboarding** — `AskUserQuestion` renders as checkboxes in Cowork exactly like it does in Claude Code, so the install flow looks the same.
- **Connectors** — Granola, Slack, Gmail, Calendar, etc. authenticated through Cowork's own UI work the same way.

## What's degraded

- **No slash commands.** You invoke flows by natural language: "what's on my plate today?" instead of `/thinkos-plate`. The instructions block teaches the agent the patterns, but the precision of a 19-command vocabulary is lost.
- **One manual paste step** — Cowork's global instructions field has no scriptable storage path. The setup script generates the text and copies it to your clipboard; you paste it into Settings once.
- **Autonomous capture works, with one caveat.** Cowork has its own `/schedule` primitive that fires recurring tasks. You can paste any of Think OS's `scripts/cron-prompts/<name>.txt` prompts into a Cowork task and `/schedule` it — Granola hourly, Gmail daily, weekly review on Sunday 8pm, etc. The ledger lives at vault note `90 System/Capture Log.md` so both Cowork and Claude Code see the same data. **Caveat:** Cowork-scheduled tasks only fire while Claude Desktop is open. For app-independent autonomy, run Claude Code as a sidecar — its launchd jobs fire regardless of which app you have open. The two surfaces share the same vault and ledger.

## What's not (yet) possible

- **A native Cowork plugin** — would require building a DXT (Desktop Extension) with a Node.js MCP server, submitting to Anthropic's marketplace, and (for enterprise users) getting org approval. Tracked as v0.5+ work.

---

## Install (~3 minutes, one manual step)

From a terminal in this repo:

```bash
bash scripts/thinkos-setup.sh --products claude-cowork --yes
```

The script:
1. Renders the curated instruction block to `~/.thinkos/claude-cowork-instructions.md` and copies it to your clipboard.
2. Inspects `~/Library/Application Support/Claude/claude_desktop_config.json`:
   - If `basic-memory` is missing → adds it pointing at your Think OS project (`think-os` by default). Writes a `.pre-thinkos.<timestamp>.bak` backup first.
   - If `basic-memory` is present and already points at your Think OS project → no-op.
   - If `basic-memory` is present but points at a different project (e.g., a pre-existing setup) → does **not** overwrite. Writes a proposed merged config to `~/.thinkos/claude-cowork-mcp-conflict.json` for you to apply manually.
3. (If `--bundle <preset>` is passed) Writes `~/.thinkos/claude-cowork-bundle.json` listing the connectors and plugins the Cowork agent should install on first run.

Then the **one manual step**:

1. Open Claude Desktop → `Settings` → `Cowork` → click into the "Global instructions" text field.
2. Paste (Cmd+V — it's already on your clipboard).
3. Save.
4. Quit and reopen Claude Desktop (MCPs load on startup; the global instructions activate immediately).

## Verify

In a fresh Cowork task, ask:

```
Use Basic Memory to tell me who I am and what I'm working on this week.
```

You should see specific answers drawing from `05 Profile/Identity.md` and `01 Now/Current Focus.md` in your vault — not generic LLM padding. If the answer is generic, either the instructions weren't pasted, the MCP isn't connected, or Cowork wasn't restarted.

For deeper diagnosis: `bash scripts/thinkos-doctor.sh --products claude-cowork`.

---

## Using it day-to-day

Anything you'd do via slash commands in Claude Code, do via natural language in Cowork:

| Claude Code slash command | What you'd say in Cowork |
|---|---|
| `/thinkos-whoami` | "Who am I?" or "What's my role and current focus?" |
| `/thinkos-morning` | "Run my morning brief" or "What should I focus on today?" |
| `/thinkos-plate` | "What's on my plate?" |
| `/thinkos-log <msg>` | "Log this: \<your note\>" or "Save \<X\> to my work log" |
| `/thinkos-decisions \<topic\>` | "What did I decide about \<topic\>?" |
| `/thinkos-who \<name\>` | "What do I know about \<name\>?" |
| `/thinkos-vault list` | "List my Think OS vaults" |
| `/thinkos-continue` (Phase 2 seeding) | "Continue Think OS setup" — agent follows the playbook at `adapters/claude-cowork/commands/thinkos-continue.md` |

The agent infers intent from the wording. The instructions block teaches it which Basic Memory tools to use and where things should land.

## What the existing `commands/*.md` files are now

The files at `adapters/claude-cowork/commands/{thinkos-continue,thinkos-vault,thinkos-bundle}.md` are **agent-readable playbooks**, not slash commands. When you say "set up a new project vault" or "continue Think OS setup", the agent reads the relevant file from this repo (or its local copy) and follows the steps. They're internal references, not user-facing commands.

---

## Autonomous capture via Cowork `/schedule`

Cowork has a native `/schedule` command that fires recurring tasks while Claude Desktop is open. You can wire any of Think OS's capture jobs to it.

The prompts live at `scripts/cron-prompts/<name>.txt`. To schedule one:

1. Open a fresh Cowork task.
2. Paste the contents of the prompt file (e.g., `cat scripts/cron-prompts/granola.txt | pbcopy` from a terminal).
3. Type `/schedule` and pick the cadence Think OS expects (hourly for granola/slack, daily 6am for calendar/gmail/clickup, Sunday 8pm for weekly-review, etc.).
4. Cowork saves the scheduled task; it fires on cadence as long as the app is open.

| Prompt | Recommended cadence | What it captures |
|---|---|---|
| `granola.txt` | Hourly | New meeting transcripts |
| `slack.txt` | Hourly | DMs + @-mentions |
| `calendar.txt` | Daily 6am | Today's events |
| `gmail.txt` | Daily 6am | Starred threads + threads where you replied last |
| `clickup.txt` | Daily 6am | Status changes on tickets assigned to you |
| `weekly-review.txt` | Sunday 8pm | Drafts updated `01 Now/Current Focus.md.draft` |
| `quarterly-archive.txt` | First Sunday of each quarter, 9pm | Rotates old work log entries |
| `morning-brief.txt` | Weekdays 7am | Writes one-page brief to `01 Now/briefs/` |
| `daily-reindex` | — | Skip; this is `basic-memory reindex` — Claude Code handles it via launchd |

The ledger lives at vault note `90 System/Capture Log.md`, so events from Cowork-scheduled tasks land in the same place Claude Code's launchd jobs append. `/thinkos-recent` (or natural language "what was captured today?") shows the merged view regardless of which surface fired which event.

**The Mac-must-be-awake-AND-Claude-Desktop-must-be-open constraint** is the real trade-off vs Claude Code's launchd. If you live in Claude Desktop all day, Cowork's `/schedule` is enough. If you close Claude Desktop overnight or for stretches, Claude Code's launchd jobs (which fire whenever the Mac is awake) are more reliable.

---

## Sidecar pattern: Claude Code + Cowork

You can install both. Most users will want to:

- **Claude Code** — handles the install, the autonomous capture jobs (launchd), `/thinkos-update`, anything that benefits from precise slash-command invocation.
- **Cowork** — uses the same vault, the same MCP, the same instructions. Best for conversational work where you want Cowork's agentic features (web search, etc.) layered on top of Think OS's context. Optionally drive its own `/schedule`-based captures for times when Claude Desktop is open anyway.

They share `~/ThinkOS/vault/`, share `basic-memory`, and share the ledger at `90 System/Capture Log.md`. Write a learning from Cowork and read it from Claude Code five minutes later.

## Troubleshooting

- **`basic-memory` doesn't appear in Cowork after restart**: open Claude Desktop's `Settings → Connectors` (or the equivalent panel) and check the list. If your filesystem extension shows `Extension is not approved for your organization`, you may be in a Cowork tenant with strict extension policy — basic-memory should still work since it's a local MCP, but verify in the panel.
- **The agent ignores my instructions**: confirm the global instructions text was saved (open `Settings → Cowork → Edit` and look at the text field — should show ~280 lines starting with `# Think OS — Priority Preamble`). If empty, paste again from `~/.thinkos/claude-cowork-instructions.md`.
- **Conflict with existing basic-memory MCP**: see `~/.thinkos/claude-cowork-mcp-conflict.json` — the setup script wrote a proposed merged config there. Either change the existing `--project` arg to `think-os`, or add a second MCP entry under a different name.

## Uninstall

```bash
bash scripts/thinkos-uninstall.sh --products claude-cowork
```

Removes the `~/.thinkos/claude-cowork-*` files. **Does not** modify `claude_desktop_config.json` (would require the user to choose what to keep). **Does not** clear the global instructions in Cowork's UI — clear that field manually if you want a clean state.
