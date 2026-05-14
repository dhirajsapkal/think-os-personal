---
description: Set up Think OS scheduled triggers (Phase 3 — automations)
permalink: think-os/adapters/claude-code/commands/thinkos-automate
---

Set up automated maintenance for the user's Think OS via local launchd jobs. This is Phase 3 — runs after Phase 1 (install) and Phase 2 (context seeding) are done.

## What this does

Installs **local launchd jobs** (via `bash scripts/install-launchd-job.sh <name>`) that keep the user's Think OS healthy without them remembering:

- Daily reindex (4am) — runs `basic-memory reindex` directly; no API tokens
- Weekly review (Sunday 8pm) — spawns `claude -p` to draft updated Current Focus for next week
- Quarterly archive (first Sunday of quarter) — spawns `claude -p` to rotate Work Log, prune stale projects
- Daily morning brief (7am Mon-Fri) — optional; spawns `claude -p` to write a markdown brief to the vault

Jobs run when the Mac is awake. If the Mac sleeps through a scheduled time, launchd fires the job on next wake (or skips that fire). These jobs write to the user's local personal-hub vault — that is why they must be local; remote triggers on Anthropic's infrastructure cannot write to `~/ThinkOS/vault/`.

## How to drive this

Read and follow `docs/phase-3-automations-playbook.md`. It contains the exact cron schedules, the prompts for each job, and the conversation flow.

Key UX points:

1. Confirm Phase 2 is complete first (`~/.thinkos/wizard-state.json` → `phase: complete`). If not, gently suggest they run `/thinkos-continue` first — but proceed if the user insists.

2. Offer each of the 4 automations one at a time with Y/N defaults. Show the cron schedule translated to English ("every Sunday at 8pm" not `0 20 * * 0`).

3. Cost transparency. Tell the user up front: "The daily reindex uses zero API tokens — it's a direct script call. The weekly review, quarterly archive, and morning brief each spawn a `claude -p` session when they fire; token usage depends on your vault size. Whether that's covered by your Claude subscription or charged as pay-as-you-go depends on your account."

4. Install each job via `bash scripts/install-launchd-job.sh <name>`. The exact prompt body for each is in the playbook.

5. After installing jobs, list them back to the user with their schedules. Mention how to list / remove later (`/thinkos-automate list`, `/thinkos-automate remove <name>`).

## Subcommand: `/thinkos-automate list`

Check `~/Library/LaunchAgents/` for `com.thinkos.*.plist` files and run `launchctl list | grep thinkos` to show load status. Show name, schedule (in English), and loaded/unloaded status.

## Subcommand: `/thinkos-automate remove <name>`

Confirm twice ("This will remove the <name> job — Think OS won't auto-<what it does> anymore. Continue?"), then run `launchctl unload ~/Library/LaunchAgents/com.thinkos.<name>.plist` and delete the plist.

## Common questions to expect

- **"Do I need to keep Claude Code open?"** Claude Code doesn't need to be open, but the Mac does need to be awake. These are local launchd jobs.
- **"What if a fire fails?"** launchd retries on the next scheduled interval. Persistent failures show up in `/thinkos-doctor`.
- **"Can I write my own?"** For jobs that write to your local vault: add a new plist + wrapper script. For jobs that don't write to the local vault (Slack alerts, project vault pushes): use the `schedule` skill or `CronCreate` for remote triggers.
- **"What about remote triggers?"** Remote triggers (via the `schedule` skill) are still available for use cases that fit — project vaults, sending notifications, anything that doesn't need to write to the local personal hub.
