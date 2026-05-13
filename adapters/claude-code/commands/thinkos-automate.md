---
description: Set up Think OS scheduled triggers (Phase 3 — automations)
permalink: think-os/adapters/claude-code/commands/thinkos-automate
---

Set up automated maintenance for the user's Think OS via Claude Code's scheduled triggers. This is Phase 3 — runs after Phase 1 (install) and Phase 2 (context seeding) are done.

## What this does

Creates **remote scheduled triggers** (via the `schedule` skill / `CronCreate` tool) that keep the user's Think OS healthy without them remembering:

- Daily reindex (4am) — keeps Basic Memory's index fresh after external edits
- Weekly review (Sunday 8pm) — drafts updated Current Focus for next week
- Quarterly archive (first Sunday of quarter) — rotates Work Log, prunes stale projects
- Daily morning brief (7am Mon-Fri) — optional; writes a markdown brief to the vault

Remote triggers run on Anthropic's infrastructure. The user does NOT need to keep Claude Code or any app open.

## How to drive this

Read and follow `docs/phase-3-automations-playbook.md`. It contains the exact cron schedules, the prompts to register for each trigger, and the conversation flow.

Key UX points:

1. Confirm Phase 2 is complete first (`~/.thinkos/wizard-state.json` → `phase: complete`). If not, gently suggest they run `/thinkos-continue` first — but proceed if the user insists.

2. Offer each of the 4 automations one at a time with Y/N defaults. Show the cron schedule translated to English ("every Sunday at 8pm" not `0 20 * * 0`).

3. Cost transparency. Tell the user up front: "These triggers use Anthropic API tokens each time they fire. Total estimated cost across all four: ~$5-15/month depending on usage."

4. Use the `schedule` skill (preferred) or `CronCreate` tool directly to create each trigger. The exact prompt body for each is in the playbook.

5. After creating triggers, list them back to the user with their schedules. Mention how to list / remove later (`/thinkos-automate list`, `/thinkos-automate remove <name>`).

## Subcommand: `/thinkos-automate list`

If the user invokes with `list`, enumerate active triggers via `CronList`. Show name, schedule (in English), last fire time, last status.

## Subcommand: `/thinkos-automate remove <name>`

Confirm twice ("This will remove the <name> trigger — Think OS won't auto-<what it does> anymore. Continue?"), then call `CronDelete`.

## Common questions to expect

- **"Do I need to keep Claude Code open?"** No. Triggers run on Anthropic's infrastructure.
- **"What if a fire fails?"** The next scheduled run will retry. Persistent failures show up in `/thinkos-doctor`.
- **"Can I write my own?"** Yes — `schedule` skill or `CronCreate` directly. Anything you can prompt an agent to do, you can schedule.
- **"Difference vs Cowork scheduled tasks?"** Cowork's require the app to be open and running on your machine. Claude Code's run in the cloud. The Claude Code path is more reliable for "set and forget" maintenance.
