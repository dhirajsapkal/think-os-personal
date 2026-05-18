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

If the user confirms, resolve the Think OS repo path first — it lives in `~/.thinkos/install-manifest.json` under the `repo_path` field:

```bash
REPO_ROOT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.thinkos/install-manifest.json')))['repo_path'])" 2>/dev/null)"
```

Then run the install script:

```bash
bash "$REPO_ROOT/scripts/install-session-capture.sh"
```

If `$REPO_ROOT` is empty (manifest missing or doesn't carry `repo_path`), the install script lives in the Think OS export repo — ask the user where they cloned it, or check the vault's `90 System/OS Instructions.md` for a `repo_path:` hint. **Do not** look for the install script inside the vault — it's not there by design. The unresolved `*.plist.template` files you might see referenced from the vault in older installs are leaked infrastructure (fixed in v0.8.1); they are not the install entrypoint.

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
REPO_ROOT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.thinkos/install-manifest.json')))['repo_path'])" 2>/dev/null)"
bash "$REPO_ROOT/scripts/uninstall-session-capture.sh"
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

Show the registered allowed paths (vaults + tracked_projects) so the user can see what the filter accepts:

```bash
python3 -c "
import json, os
p = os.path.expanduser('~/.thinkos/vaults.json')
if not os.path.isfile(p):
    print('(no vaults.json)'); raise SystemExit
d = json.load(open(p))
print('Vaults:')
for v in d.get('vaults', []):
    print(f\"  {v.get('id','?')}: {v.get('path','?')}\")
tp = d.get('tracked_projects', [])
print(f'Tracked projects: {len(tp)}')
for t in tp:
    print(f\"  {t.get('label','(unlabeled)')}: {t.get('path','?')}\")
"
```

And the last few entries in the capture log:

```bash
VAULT="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
grep -c '^{' "$VAULT/90 System/Capture Log.md" 2>/dev/null || echo "0"
tail -5 "$VAULT/90 System/Capture Log.md" 2>/dev/null | grep '^{' || echo "(no capture log)"
```

Also surface any recent `filter-no-match` events so silent no-ops are visible:

```bash
grep -E "0 sessions matched|filter-no-match" ~/Library/Logs/ThinkOS/session-capture.err 2>/dev/null | tail -3 || true
```

Format the output for the user like:

```
Session capture: [registered / not registered]
Last run: <ISO timestamp or "never">
Allowed paths: <N vaults, M tracked projects>
  <list>
Recent captures:
  <last up to 5 capture-log lines, formatted as: YYYY-MM-DD HH:MM — <basename> (N files)>
Recent no-match events: <last up to 3, or "(none)">
```

---

## Subcommand: `now`

Run the capture script once immediately — useful for testing after install or after a coding session. Capture stderr too so filter warnings are visible:

```bash
REPO_ROOT="$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.thinkos/install-manifest.json')))['repo_path'])" 2>/dev/null)"
bash "$REPO_ROOT/scripts/thinkos-session-capture.sh" 2>&1
```

If the script exits with `0 sessions matched allowed paths`, the cwds your Claude Code sessions ran in aren't registered. Either add them to `tracked_projects` in `~/.thinkos/vaults.json`, or re-run with `--all-projects` to capture everything.

Confirm completion and show the last entries in the work log:

```bash
tail -10 "${THINKOS_HOME:-$HOME/ThinkOS/vault}/01 Now/Work Log.md" 2>/dev/null
```

---

## Tracked projects

The capture script's default filter accepts sessions whose `cwd` is under either a registered vault path or an entry in `tracked_projects` in `~/.thinkos/vaults.json`. If your code lives outside the vault (typical), add the project repos you want captured:

```json
{
  "version": 1,
  "vaults": [ /* ... */ ],
  "tracked_projects": [
    { "path": "~/code/my-project", "label": "My Project" }
  ]
}
```

Paths support `~`; subdirectories of a registered path are matched too. After editing, run `/thinkos-autosave now` to verify; the next scheduled launchd fire picks up the change automatically.

Use `--all-projects` (manual invocation only) to bypass the filter entirely.

## Common questions

- **"What exactly gets captured?"** File paths touched via Edit/Write tools, a count of unique files, the git HEAD short SHA if the project is a git repo. NOT file contents, NOT the conversation transcript.
- **"How do I see the log?"** Open `01 Now/Work Log.md` in your vault, or ask `/recent-log`.
- **"It didn't capture anything."** First check `/thinkos-autosave status` — if the allowed-paths list doesn't include the cwd you've been working in, add it to `tracked_projects` in `~/.thinkos/vaults.json` (see Tracked projects section above). Then run `/thinkos-autosave now`. If that still fails, check `~/Library/Logs/ThinkOS/session-capture.err` for the filter line and any errors.
- **"Can I change the frequency?"** Edit the plist at `~/Library/LaunchAgents/com.thinkos.session-capture.plist` — adjust `StartCalendarInterval` entries — then run `/thinkos-autosave off` and `/thinkos-autosave on` to reload.
