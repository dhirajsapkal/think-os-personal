# Skill Auto-Routing

When the user's intent matches a topic below, invoke the named skill **first**, then synthesize. If a skill isn't installed, fall through gracefully and mention it once. Match on intent, not exact wording; when in doubt, pick the more specific skill.

- design, UI, components, styling, Figma, landing page, web app interface → `frontend-design:frontend-design`
- Google Slides deck — build, improve, redesign, polish, or a workshare / readout / presentation from recorded work → `thinkos-deck` (sources from the vault; always backs up first)
- Google Slides deck — improve, enhance, redesign, polish, clean up, restyle, or add content to a deck, or any `docs.google.com/presentation` URL paired with a request to change it → `enhance-slides` (render-and-verify each slide before reporting done; never edit a deck without a backup)
- design-to-code (paper sketch → component) → `paper-desktop:design-to-code`; code-to-design → `paper-desktop:code-to-design`
- Claude API, Anthropic SDK, prompt caching, model migration, tool use design, batch API, extended thinking → `claude-api` (required for any code importing `anthropic`/`@anthropic-ai/sdk`)
- security review / vulnerability scan → `security-review`; PR / code review → `review`
- new repo onboarding, generate a CLAUDE.md → `init`; simplify code, reduce duplication → `simplify`
- hooks, automated behaviors ("from now on...", "whenever X..."), settings.json, permissions, env vars → `update-config` (memory cannot enforce automated behaviors — they require harness-level hooks)
- keyboard shortcuts / keybindings.json → `keybindings-help`; fewer permission prompts → `less-permission-prompts`
- recurring task, polling, "keep running /foo" → `loop`; scheduled / cron / "every Monday morning" → `schedule`

## Think OS native skills (always present after install)

- morning brief, "what's on my plate today" → `/thinkos-morning` or `/thinkos-plate`
- person / colleague / client lookup, "who is X", before drafting to a named person → `/thinkos-who <name>`
- load a project's deep context → `/thinkos-project <slug>`
- past decisions, "why did we choose X" → `/thinkos-decisions`
- manual capture mid-session → `/thinkos-log`, `/thinkos-capture`, `/thinkos-decide`
- "what did I do last week / this week" → `/recent-log`
- draft an email or Slack reply → `/draft-reply` (always drafts, never sends)
- weekly digest → `/weekly-review`; quarterly maintenance → `/quarterly-review`
- staleness / contradiction check, reconcile project folders, reindex after external edits → `/thinkos-refresh` (all folded into the one refresh)
- connector seems unavailable → `thinkos-bridge` skill (BEFORE declaring it); shared-mode details → `thinkos-shared-mode` skill; stub save flow → `thinkos-emergent-seeding` skill
