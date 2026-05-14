---
title: Continuous Capture — Session Capture
description: How Think OS automatically logs Claude Code activity to your work log
---

# Continuous Capture: Session Capture

## The problem it solves

Your vault goes stale because capture is manual. At the end of a long coding session, writing a work-log entry is the last thing you want to do. Session capture removes that friction: every 2 hours during work hours, it scans what you did in Claude Code and appends a brief entry to your work log automatically. By the end of the day, you have a timestamped picture of where your time went — without doing anything.

## What gets captured

- **Which directories you worked in** (the `cwd` of each Claude Code session)
- **How many files you edited** (count of unique paths touched via Edit/Write tools)
- **The git HEAD short SHA** at time of capture, if the directory is a git repo

What is explicitly NOT captured:
- File contents
- Session transcripts or conversation text
- Anything you typed in the conversation
- Environment variables, secrets, or credentials

The capture script reads `.jsonl` session logs from `~/.claude/projects/` but only extracts tool-use metadata — specifically `Edit`, `Write`, and `MultiEdit` tool call inputs to find file paths. It does not read or transmit any other session data.

## Where it goes

Entries are appended to `01 Now/Work Log.md` in your vault under a date header:

```markdown
## 2026-05-14

### 14:00 — think-os-alpha
- Edited 12 files in `/Users/you/Documents/Think/think-os-alpha`
- 2 sessions in this directory
- HEAD: `abc1234`

### 14:00 — my-other-project
- Active in `/Users/you/dev/my-other-project` (no file edits recorded)
```

A secondary ledger — the vault note "Capture Log" at `90 System/Capture Log.md` — records one JSON entry per cwd per run, in the format:

```json
{"ts":"2026-05-14T14:30:00Z","source":"session","detail":{"cwd":"/path","files_touched":6,"commit":"abc1234","session_count":2},"output":"01 Now/Work Log.md","mode":"append","bytes":234}
```

## How often it runs

The launchd job fires at these local-time hours on any day the machine is awake:

```
8:00  10:00  12:00  14:00  16:00  18:00  20:00  22:00
```

It only processes sessions modified since the last run (tracked by `~/.thinkos/last-session-capture`), so multiple fires without new activity produce no duplicate entries.

## How to enable / disable

Enable via Claude Code:
```
/thinkos-autosave on
```

Disable:
```
/thinkos-autosave off
```

Check status and last capture time:
```
/thinkos-autosave status
```

Run immediately (useful for testing):
```
/thinkos-autosave now
```

Or use the scripts directly:
```bash
bash scripts/install-session-capture.sh
bash scripts/uninstall-session-capture.sh
bash scripts/thinkos-session-capture.sh --dry-run
```

## Troubleshooting

**Nothing appears in the work log**

1. Run `bash scripts/thinkos-session-capture.sh --dry-run` to see what it would capture.
2. Check whether `~/.claude/projects/` exists and contains `.jsonl` files.
3. Check the launchd log: `cat ~/Library/Logs/ThinkOS/session-capture.log`
4. Verify the job is registered: `launchctl list | grep thinkos.session-capture`

**The job is listed but shows a non-zero exit code**

Look at `~/Library/Logs/ThinkOS/session-capture.log` for the error. Common causes:
- `python3` not on PATH when launched by launchd (check `/usr/bin/python3` exists)
- Vault directory does not exist yet (run `/thinkos-setup` first)

**Changing the schedule**

Edit `~/Library/LaunchAgents/com.thinkos.session-capture.plist`, adjust the `StartCalendarInterval` entries, then reload:

```bash
bash scripts/uninstall-session-capture.sh
bash scripts/install-session-capture.sh
```

**Disabling capture entirely without uninstalling**

Delete the marker file to reset the dedup window, or just run the uninstall script. Your existing work-log entries are never deleted.

## Privacy notes

Session capture is entirely local. No data leaves your machine. The capture script:
- Makes no network calls
- Calls no LLM APIs
- Reads only metadata from session files (tool names and file path arguments)
- Writes only to your local vault and `~/.thinkos/`

The launchd job runs as your user account with your normal file permissions. No elevated privileges are required or requested.
