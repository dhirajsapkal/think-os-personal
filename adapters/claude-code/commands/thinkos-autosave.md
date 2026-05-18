---
description: Manage periodic background capture of Claude Code session activity
permalink: think-os/adapters/claude-code/commands/thinkos-autosave
---

Manages the session-capture background job that periodically scans recent Claude Code sessions and appends a work-log stub. Every 2 hours during work hours (8am-10pm), the job scans `~/.claude/projects/` for activity and writes brief bullets to `01 Now/Work Log.md`.

User invocation: `/thinkos-autosave [on|off|status|now]`

---

## Subcommand: `on`

Use AskUserQuestion before installing:

> Session capture will register a launchd job that runs every 2 hours (8am-10pm) and appends a short work-log entry based on which files you edited in Claude Code. It captures file paths and edit counts only — not session transcripts or file contents. Install it?

If the user confirms, run:

```bash
bash <repo-root>/scripts/install-session-capture.sh
```

Where `<repo-root>` is the Think OS export directory (resolved from the vault path or `~/.thinkos/install-manifest.json`).

After the script exits, confirm:

> Session capture is installed. It will run at 8, 10, 12, 14, 16, 18, 20, and 22:00 local time.
> Run `/thinkos-autosave now` to capture immediately and verify it's working.

If the install script is not found, tell the user:

> Could not find install-session-capture.sh. Make sure Think OS is installed (run /thinkos-setup first).

---

## Subcommand: `off`

Use AskUserQuestion before uninstalling:

> This will remove the session-capture launchd job. Your existing work-log entries and `90 System/Capture Log.md` are not deleted. Continue?

If the user confirms, run:

```bash
bash <repo-root>/scripts/uninstall-session-capture.sh
```

Confirm removal:

> Session capture uninstalled. Your existing work-log entries are unchanged.

---

## Subcommand: `status`

Show whether the job is registered and when it last ran:

```bash
launchctl list | grep thinkos.session-capture
```

Also show the last capture timestamp from the marker file:

```bash
cat ~/.thinkos/last-session-capture 2>/dev/null || echo "(never run)"
```

And the last few entries in the capture log:

```bash
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
grep -c '^{' "$VAULT/90 System/Capture Log.md" 2>/dev/null || echo "0"
tail -5 "$VAULT/90 System/Capture Log.md" 2>/dev/null | grep '^{' || echo "(no capture log)"
```

Format the output for the user like:

```
Session capture: [registered / not registered]
Last run: <ISO timestamp or "never">
Recent captures:
  <last up to 5 capture-log lines, one per line, formatted as: YYYY-MM-DD HH:MM — <basename> (N files)>
```

---

## Subcommand: `now`

Run the capture script once immediately — useful for testing after install or after a coding session:

```bash
bash <repo-root>/scripts/thinkos-session-capture.sh
```

Confirm completion and show the last line appended to the work log:

```bash
tail -10 "${THINKOS_HOME:-$HOME/ThinkOS/vault}/01 Now/Work Log.md" 2>/dev/null
```

---

## Common questions

- **"What exactly gets captured?"** File paths touched via Edit/Write tools, a count of unique files, the git HEAD short SHA if the project is a git repo. NOT file contents, NOT the conversation transcript.
- **"How do I see the log?"** Open `01 Now/Work Log.md` in your vault, or ask `/recent-log`.
- **"It didn't capture anything."** Run `/thinkos-autosave now` to test manually. Check `~/Library/Logs/ThinkOS/session-capture.log` for launchd errors.
- **"Can I change the frequency?"** Edit the plist at `~/Library/LaunchAgents/com.thinkos.session-capture.plist` — adjust `StartCalendarInterval` entries — then run `/thinkos-autosave off` and `/thinkos-autosave on` to reload.
