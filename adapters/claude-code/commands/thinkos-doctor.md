---
description: Run thinkos-doctor.sh to check Think OS install health
permalink: think-os/adapters/claude-code/commands/thinkos-doctor
---

Run the Think OS health-check script and surface any problems with the install.

## Step 1 — Run the script

```bash
bash scripts/thinkos-doctor.sh "$ARGUMENTS"
```

Pass any flags the user supplied in `$ARGUMENTS` directly (e.g. `--json`, `--products basic-memory,granola`).

If the script is not found, tell the user:

> `scripts/thinkos-doctor.sh` not found. Make sure you are running this from the Think OS repo root, or re-run Think OS setup with `/thinkos-setup`.

## Step 2 — Interpret the output

- **PASS** lines — no action needed.
- **WARN** lines — surface them with a one-line explanation of the likely cause.
- **FAIL** lines — surface them first, grouped by severity, with a suggested fix for each.

If `--json` was passed, emit the raw JSON without reformatting.

## Step 3 — Offer next steps (interactive)

If any WARN or FAIL items appeared, offer:

```
"Want me to attempt any of these fixes? I can only do safe read/write operations — destructive steps will require your confirmation."
```

Do not auto-apply fixes. Surface the proposed commands and wait for explicit approval.

## Flags reference

| Flag | Effect |
|------|--------|
| `--json` | Machine-readable output |
| `--products <list>` | Scope check to specific products (comma-separated) |
| `--verbose` | Include debug detail per check |
| `--quiet` | Only emit WARN/FAIL lines |

## Example invocations

- `/thinkos-doctor` — full health check
- `/thinkos-doctor --products basic-memory,granola` — scoped check
- `/thinkos-doctor --json` — machine-readable output for scripting

User message: $ARGUMENTS
