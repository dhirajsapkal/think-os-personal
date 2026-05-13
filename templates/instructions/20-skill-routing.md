# Skill Auto-Routing

When the user mentions one of the topics below, invoke the named skill **first** rather than answering from scratch. Each skill is a curated playbook that has more domain knowledge than a freshly-prompted model. Synthesize after the skill loads its guidance.

If a listed skill is not installed in the user's environment, fall through gracefully — answer from general capability and (once) mention that the skill is available to install for higher-quality output next time.

## Routing table

- **design, UI, components, styling, Figma, landing page, marketing site, web app interface**: invoke `frontend-design:frontend-design` skill first, then synthesize. Produces production-grade frontend that avoids generic AI aesthetics.
- **paper sketch to code, design-to-code, turn this mock into a component**: invoke `paper-desktop:design-to-code` skill. Uses the project's existing tokens/conventions.
- **code to design, generate a Paper design from this codebase**: invoke `paper-desktop:code-to-design` skill.
- **Claude API, Anthropic SDK, prompt caching, model migration (Opus/Sonnet/Haiku version bumps), tool use design, batch API, extended thinking**: invoke `claude-api` skill. Required for any code importing `anthropic`/`@anthropic-ai/sdk`.
- **security review, vulnerability scan, audit this diff for security issues**: invoke `security-review` skill before commenting.
- **PR review, code review, review this diff**: invoke `review` skill.
- **new repo onboarding, generate a CLAUDE.md, document this codebase for agents**: invoke `init` skill.
- **simplify this code, reduce duplication, quality pass**: invoke `simplify` skill.
- **configure hooks, automated behaviors ("from now on...", "whenever X...", "after every commit..."), settings.json, permissions, env vars**: invoke `update-config` skill. Memory alone cannot enforce automated behaviors — they require harness-level hooks.
- **keyboard shortcuts, rebinding keys, keybindings.json**: invoke `keybindings-help` skill.
- **fewer permission prompts, allowlist common commands**: invoke `less-permission-prompts` skill.
- **recurring task, "check X every 5 minutes", polling, "keep running /foo"**: invoke `loop` skill.
- **scheduled / cron / remote agent triggers, "run this every Monday morning"**: invoke `schedule` skill.

## Think OS native skills (always present after install)

These ship with Think OS itself and are always installed alongside the curated instructions:

- **morning brief, daily kickoff, "what's on my plate today"**: `/morning`, `/plate`.
- **specific person / colleague / client lookup before drafting**: `/who <name>`.
- **load a project's deep context**: `/project <slug>`.
- **past decisions, "why did we choose X"**: `/decisions`.
- **manual capture: log a thought, decision, or learning mid-session**: `/log`, `/capture`, `/decide`.
- **what did I do last week / this week**: `/recent-log`.
- **draft an email or Slack reply**: `/draft-reply` (always drafts, never sends).
- **weekly digest, Sunday-evening rollup**: `/weekly-review`.
- **quarterly maintenance, archive rotation, prune stale**: `/quarterly-review`.
- **sanity-check the OS for staleness or contradictions**: `/validate-os`.
- **walk project folders and reconcile against the index**: `/index-projects`.

## Routing principle

Match on intent, not exact wording. "Build me a landing page for X" and "I need a hero section" both route to `frontend-design`. "Can you check what we decided about auth" routes to `/decisions`. When in doubt between two skills, pick the more specific one; fall back to the general if it errors.
