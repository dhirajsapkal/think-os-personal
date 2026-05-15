---
type: design-doc
tags:
- agents
- token-efficiency
permalink: think-os/docs/cost-of-context-heuristic
---

# Cost-of-Context Heuristic

The Think OS first-action protocol mandates two MCP reads (`identity`, `current focus`) before any substantive answer. That's the right default for personal-context questions but the wrong default for project-local factual questions — the user pays a two-MCP tax to get told "how does this function work?"

This doc explains the skip rule added to `templates/instructions/00-think-os-priority.md` in v0.5, with worked examples.

## The rule (verbatim from `00-think-os-priority.md`)

> - **Project-local generic question.** If ALL of the following are true, skip the mandatory reads and answer directly:
>   - CWD is a registered project (matches a path in `vaults.json` with `type: project`), AND
>   - the question does not mention any of: "I", "me", "my", "we", "our", a person's proper name, the words "identity"/"focus"/"decisions"/"learnings"/"vault"/"focus"/"week"/"last week", AND
>   - the question is a how-to / factual / single-file pattern ("how does this function work?", "what does this script do?", "where is X defined?", "fix this typo").
>   - When ANY criterion is uncertain, read. Conservative bias: false negatives (skipping when context would have helped) are recoverable; false positives (skipping in personal contexts) are not.

The three conditions are AND-joined. All three must hold to skip. The fourth bullet is the bias: when uncertain, read.

## 5 skip examples (rule fires, no MCP reads)

1. **CWD = `~/code/think-os-alpha` (registered project); user asks "how does `thinkos-update.sh` resolve the manifest path?"** — project-local + factual + no personal pronouns. Skip.
2. **CWD = `~/code/acme-redesign` (registered project); user asks "where is the `Button` component defined?"** — factual single-file pattern. Skip.
3. **CWD = `~/code/think-os-alpha`; user asks "fix the typo in `scripts/thinkos-doctor.sh:42`."** — single-file edit, no personal context. Skip.
4. **CWD = `~/code/acme-redesign`; user asks "what does `npm run build` do in this repo?"** — factual / how-to. Skip.
5. **CWD = `~/code/think-os-alpha`; user asks "list every command in `adapters/claude-code/commands/`."** — factual enumeration, no personal context. Skip.

## 5 read examples (rule does NOT fire, MCP reads required)

1. **CWD = `~/code/think-os-alpha`; user asks "what am I working on this week?"** — mentions "I" + "this week." Read.
2. **CWD = `~/code/think-os-alpha`; user asks "what's our convention for naming new slash commands?"** — mentions "our." Read (Decisions may have an answer).
3. **CWD = `~/code/think-os-alpha`; user asks "what did Jordan say about the manifest format?"** — mentions a person's name. Read.
4. **CWD = `~/Desktop/scratch` (not a registered project); user asks "how does this function work?"** — CWD is not a registered project. Read.
5. **CWD = `~/code/think-os-alpha`; user asks "remind me why we picked YAML over TOML for the manifest."** — mentions "we" + asks about a past decision. Read.

## Why this rule and not a more aggressive one

A more aggressive rule (e.g., "any one of those criteria → skip") would catch more cases — at the cost of false positives. False positives are expensive:

- Skipping personal context on a personal question means the agent gives a generic answer when a specific one was available. The user notices, asks again, costs another turn.
- Skipping personal context on what *looks* project-local but is actually about working style means the agent contradicts the user's documented Identity. Trust erodes faster than from any other failure.

False negatives (reading when the skip rule should have fired) are cheap — just a slightly slower response. Hence the conservative bias.

## How to evolve

If the maintainer measures that 30%+ of skipped cases are clearly fine (no follow-up question, no contradiction with Identity), the rule can be relaxed:

- Drop the proper-noun check first (it's the most conservative).
- Then drop the "we/our" check (collaborative work is often project-local).
- Last, broaden the question-shape check (multi-file factual questions can also skip).

Walking it back is harder. Add criteria back if false positives surface.

## Interaction with other exceptions

The existing exceptions still apply:

- Trivial syntax / one-off shell commands → skip regardless of CWD.
- Generic factual questions where personal context is irrelevant → skip regardless of CWD.
- User says "skip context" / "no context" → skip.
- Continuing a thread in the same session → context already loaded, skip the re-read.

The new project-local rule is additive — it covers the case where the existing exceptions are too narrow.
