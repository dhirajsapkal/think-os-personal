# Cross-Machine Sync

Think OS v0.6 makes vault sync first-class via the `/thinkos-sync` slash command and an opt-in launchd job. This doc covers the UX, conflict handling rules, the launchd schedule, and notes for multi-machine setups.

---

## UX of `/thinkos-sync`

`/thinkos-sync` wraps `scripts/thinkos-git.sh sync-vault` with a three-step flow:

1. **Stage and commit** any local changes to the vault. Auto-message: `chore(vault): sync YYYY-MM-DD HH:MM`. Override with `--message "your message"`.
2. **Pull with rebase** (`git pull --rebase`) to incorporate changes from the remote.
3. **Push** the result back to the remote.

If the vault is already clean and the remote has no new commits, the command exits silently with "Vault is up to date."

### Manual invocation

```
/thinkos-sync                         # sync personal hub, auto-message
/thinkos-sync --dry-run               # preview without executing
/thinkos-sync --message "pre-travel"  # custom commit message
/thinkos-sync --vault ~/path/to/vault # target a specific vault
```

Or directly from the shell:

```bash
bash scripts/thinkos-git.sh sync-vault
bash scripts/thinkos-git.sh sync-vault --dry-run
bash scripts/thinkos-git.sh sync-vault --vault ~/ThinkOS/vault --message "end of sprint"
```

### Automated invocation (opt-in launchd job)

The launchd job registered by `install-sync-job.sh` calls `sync-vault` on the configured vault path. It runs unattended — any output lands in the log files listed below. Conflicts in the unattended path cause the job to exit non-zero; check the logs if something looks wrong after waking a machine.

---

## Conflict handling — never auto-resolve

This is a hard contract in Think OS: **the sync script never auto-resolves merge conflicts.**

When `git pull --rebase` encounters a conflict, the script:

1. Prints the conflicted file list verbatim (from `git diff --name-only --diff-filter=U`).
2. Prints the full `git status` output so you can see the exact state.
3. Exits with code 1 and prints two recovery paths:

**Path A — resolve and re-sync:**
Edit the conflicted files, find and resolve the `<<<<<<<` / `=======` / `>>>>>>>` markers, save the files, then run `/thinkos-sync` again.

**Path B — abort:**
```bash
git -C <vault-path> rebase --abort
```
This resets the vault to its pre-sync state. Your local uncommitted changes will still be staged; the remote's changes are not applied.

**Why no auto-resolve?** Vault notes contain personal context — identity, decisions, learnings. An automated merge of two diverging Personal Notes files could silently produce garbled context that future sessions read as ground truth. A human review is always worth the 30 seconds.

---

## Opt-in launchd job

### Install

```bash
bash scripts/install-sync-job.sh
```

With a custom vault path (if auto-resolution doesn't find the right one):

```bash
bash scripts/install-sync-job.sh --vault ~/ThinkOS/vault
```

Preview what would be installed without writing anything:

```bash
bash scripts/install-sync-job.sh --dry-run
```

### Default schedule

**Mon–Fri at 18:00 local time.** One sync per workday, at end-of-day. This matches the existing Think OS "one launchd fire per day per cadence" pattern (daily-reindex at 4am, weekly-review on Sunday 8pm).

Rationale for end-of-day over more frequent cadences (considered in Q5):
- Minimizes unnecessary git traffic during the workday when the vault is in flux.
- Predictable: you can rely on "machines are in sync by 6pm" as a working assumption.
- Power users who need tighter sync can edit the plist directly.

### How to customize the schedule

1. Open `~/Library/LaunchAgents/com.thinkos.sync.plist`.
2. Edit the `StartCalendarInterval` array. Each `<dict>` in the array is one fire time. launchd keys: `Weekday` (0=Sun, 1=Mon … 6=Sat), `Hour` (0–23), `Minute` (0–59).
3. Reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.thinkos.sync.plist
launchctl load -w ~/Library/LaunchAgents/com.thinkos.sync.plist
```

Example — fire at 10am AND 6pm on weekdays:

```xml
<array>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
  <!-- repeat for Weekday 2–5 -->
</array>
```

### Logs

| File | Content |
|---|---|
| `~/Library/Logs/ThinkOS/sync.log` | stdout from each sync run |
| `~/Library/Logs/ThinkOS/sync.err` | stderr (conflicts, push rejections, git errors) |

### Uninstall

```bash
bash scripts/uninstall-sync-job.sh
```

Logs and vault contents are not removed.

### Verify the job is registered

```bash
launchctl list | grep com.thinkos.sync
```

---

## Multi-machine notes

### Git remote is the shared medium

Each machine pulls from and pushes to the same git remote. The vault is a git repository — typically a private GitHub/GitLab repo. Commits from machine A appear on machine B after the next sync.

### Each machine runs its own Basic Memory index

Basic Memory indexes your vault locally (it's a local-stdio server). When machine B pulls new commits from the remote, the new files are on disk but not yet indexed. **On the next Think OS session on machine B, the agent calls Basic Memory normally — Basic Memory reads the vault on disk and reflects the pulled-in notes automatically** (no explicit reindex is needed in most cases).

If Basic Memory's index appears stale after a pull (e.g. you search for a note you just synced from another machine and it doesn't appear), run:

```
/thinkos-reindex
```

This triggers a full re-scan of the vault folder, after which searches and reads reflect the synced state.

### Non-git sync strategies

If git is not right for your setup, these alternatives work at the filesystem level. Think OS has no special integration with them — they sync files; Basic Memory reads files.

| Strategy | Notes |
|---|---|
| **iCloud Drive** | Place the vault in `~/Library/Mobile Documents/…`. Sync is automatic but opaque; conflicts result in duplicate files (e.g. `note (1).md`). Monitor for duplicates. |
| **Syncthing** | Open-source, peer-to-peer. More control over conflict handling (versioning folder). No cloud dependency. |
| **Obsidian Sync** | First-party sync for Obsidian vaults. Conflict handling is built in. Requires an Obsidian Sync subscription. |

For all non-git strategies: Basic Memory reads whatever is on disk, so conflicts that produce duplicate files may create duplicate Basic Memory entities. Periodic `/thinkos-vitals` runs will flag unexpected file growth.

---

## Design note — why separate from `thinkos-doctor`

`/thinkos-vitals` and `/thinkos-sync` are both v0.6 surfaces, but they serve different concerns:

- **Doctor** — install/setup state: is git installed, is Basic Memory running, are the managed files in place?
- **Sync** — vault content state: commit, pull, push the actual notes.
- **Vitals** — vault health state: staleness, line budgets, broken links, ledger volume.

Mixing sync or vitals into doctor would dilute its "is the OS itself healthy?" signal and add vault-awareness to a script that's supposed to be cheap and setup-focused.
