# Think OS Instructions For Claude Code

My personal context OS lives at `{{OS_HOME}}`, served by the `basic-memory` MCP server.

A SessionStart hook (`scripts/thinkos-session-start.sh`) injects dynamic session state (setup phase, active vault, freshness) as hook output. When that output is present in context, trust it and skip the equivalent shell checks below.

## Mid-Setup Detection

On a new conversation: `test -f ~/.thinkos/wizard-state.json && cat ~/.thinkos/wizard-state.json`. If `phase` is not `complete`, add one line at the top of your first response — "Heads up — Think OS setup is mid-flight (phase: `<phase>`). Run `/thinkos-continue` to pick it up." — without interrupting the user's actual question. Playbook: `adapters/claude-code/commands/thinkos-continue.md`.

## Multi-Vault Awareness

Canonical design: `docs/multi-vault-architecture.md`. On session start: `test -f ~/.thinkos/vaults.json && cat ~/.thinkos/vaults.json`; absent = single-vault legacy mode.

Active vault resolution, in order: (1) `~/.thinkos/active-vault` sticky override (one-line vault id); (2) CWD under a registered vault's `path`; (3) the vault with `"default": true` (the personal hub).

First response of every session, one line before answering: `Active vault: <id> (<label>). Personal hub (<personal-id>) always loaded.`

HOT-tier loading: always Identity, Current Focus, OS Instructions from the personal hub; if the active vault is `type: project`, also its `00 Project Home.md` and `04 Roster.md`.

Basic Memory scoping: each vault has a `bm_project` field in `vaults.json` — pass `--project <bm_project>` to target it. Cross-vault search: personal hub first, then the active project vault; never silently merge — prefix results with `[<id>]`. Write routing follows the multi-vault rules in Write Targets above.

## Project Detection, Freshness, Communication

If CWD is under a known project root, search `02 Projects/<project-slug>` before answering substantively. Flag `Current Focus` past its `covers_week` before answering "what am I working on". Communicate direct, concise, no preamble; surface tradeoffs; ask when unsure; use `path:line` for file references.
