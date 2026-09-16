# Handoff — automation runtime is dead on macOS

**Filed:** 2026-09-15 · **Against:** v0.9.10 · **Reporter:** diagnosed in a Claude Code session, not yet fixed
**Status:** diagnosed, nothing changed. No code has been touched. Start from a clean tree.

---

## TL;DR

**7 of 10 scheduled Think OS jobs have been failing on every run since May 2026.** Two mundane
causes: `claude` isn't on launchd's `PATH`, and `flock` doesn't exist on macOS. Nobody noticed
because `thinkos-doctor.sh` checks that the jobs' *target script exists* — which it does — and
reports `ok` while every run dies.

The user's `Current Focus.md` is 8 weeks stale. That is not a missed habit. `/weekly-review` has
been firing on schedule for four months and exiting before it can write anything.

Fix the runtime first. Most of what looks like missing features already exists and is already
scheduled — it has simply never run.

---

## Verify the diagnosis yourself

```bash
# 1. Job exit statuses — middle column is last exit code
launchctl list | grep -i think | awk '{printf "%-34s exit=%s\n", $3, $2}'

# 2. The two failure signatures
tail -20 ~/Library/Logs/ThinkOS/granola.stderr.log

# 3. Confirm the causes
command -v flock            # empty on macOS — it is a Linux util
command -v claude           # exists in an interactive shell...
                            # ...but NOT in launchd's minimal PATH
```

Expected output of (1) at time of filing:

```
com.thinkos.session-capture        exit=0
com.thinkos.morning-brief          exit=1
com.thinkos.weekly-review          exit=0   ← but see note in FIX-4
com.thinkos.gmail                  exit=1
com.thinkos.quarterly-archive      exit=0
com.thinkos.daily-reindex          exit=1
com.thinkos.slack                  exit=1
com.thinkos.granola                exit=1
com.thinkos.clickup                exit=1
com.thinkos.calendar               exit=1
```

### Scale

`~/Library/Logs/ThinkOS/granola.stderr.log` is **275 KB**, created **2026-05-14**, and contains
nothing but failures — in two eras:

| Count | Signature | Era |
|---|---|---|
| 722 | `Operation not permitted` on a stale alpha path (`~/Documents/Think/Routines/Claude OS Setup/export/think-os-alpha/scripts/thinkos-cron-run.sh`) | before the repo moved to `~/code/think-os` |
| 1332 | `claude CLI not found in PATH` | after the move — current |

~2054 failed runs on the granola job alone. `slack.stderr.log` is a comparable 272 KB.

---

## FIX-1 — `claude` not resolvable under launchd

**Severity:** critical — single-handedly breaks every LLM-driven job.

**Root cause:** `scripts/thinkos-cron-run.sh:119`

```sh
if ! command -v claude >/dev/null 2>&1; then
  echo "[$TASK_ID] claude CLI not found in PATH" >&2
  return 1
fi
```

launchd runs jobs with a minimal `PATH` (typically `/usr/bin:/bin:/usr/sbin:/sbin`). On this machine
`claude` is at `~/.npm-global/bin/claude`. The guard fires and the job returns 1 before doing any work.

**Proposed fix — manifest-first, PATH-sweep fallback.** Matches the repo's existing manifest-driven
pattern rather than hardcoding a path:

1. At setup (`scripts/thinkos-setup.sh`), resolve `claude` and record the absolute path as
   `claude_bin` in `~/.thinkos/install-manifest.json`.
2. In `thinkos-cron-run.sh`, before the guard: read `claude_bin` from the manifest; if absent or
   no longer executable, sweep a candidate list — `~/.npm-global/bin`, `~/.local/bin`,
   `/opt/homebrew/bin`, `/usr/local/bin`, `~/.claude/local` — and prepend the hit to `PATH`.
3. If still not found, keep the existing hard failure **but** make the message actionable: state
   which locations were searched.

**Acceptance criteria**
- `launchctl kickstart -k gui/$(id -u)/com.thinkos.granola` completes with exit 0.
- A new `=== <ts> granola ===` block appears in `~/Library/Logs/ThinkOS/granola.log`.
- Works when `claude` is installed via npm-global, homebrew, or the native installer.
- Re-running setup on a machine where `claude` moved refreshes `claude_bin`.

---

## FIX-2 — `flock` does not exist on macOS

**Severity:** high — fires on every run of every job, and the ledger append silently fails.

**Root cause:** `scripts/thinkos-cron-run.sh:76`, inside `ledger_append()` (defined line 53):

```sh
{
  flock 9
  printf '%s\n' "$line" >&9
} 9>> "$LEDGER"
```

`flock` is util-linux. macOS ships no equivalent binary. Every run emits
`thinkos-cron-run.sh: line 76: flock: command not found`.

**Proposed fix.** Ledger entries are single-line JSON well under `PIPE_BUF` (4 KB), so an `O_APPEND`
`printf >>` is already atomic on macOS and Linux. Simplest correct fix is to drop the lock:

```sh
printf '%s\n' "$line" >> "$LEDGER"
```

If the lock is wanted for larger future writes, guard it and fall back to an atomic `mkdir` lock —
do **not** leave an unguarded `flock`.

**Acceptance criteria**
- No `flock: command not found` in any `~/Library/Logs/ThinkOS/*.stderr.log` after a forced run.
- Ledger lines still land one-per-line under concurrent kickstarts of two jobs.

---

## FIX-3 — doctor cannot see job failure  ← *most important long-term*

**Severity:** high. This is why FIX-1 and FIX-2 went unnoticed for four months.

**Root cause:** `scripts/thinkos-doctor.sh`, the WP-37 block (~line 558). It reads
`ProgramArguments[1]` from each plist and checks **the target script exists on disk**:

```sh
elif [[ ! -f "$target_script" ]]; then
  add_check "launchagent:${plist_label}" warn "plist target script not found: ..."
else
  add_check "launchagent:${plist_label}" ok "plist target script exists: $target_script"
fi
```

The script does exist. Doctor reports `ok` for all ten jobs while seven of them fail on every run.
Existence is not health.

**Proposed fix — add a job-health check.** For each `com.thinkos.*` plist:

1. Parse last exit status from `launchctl list` (column 2). Non-zero → `fail`.
2. Stat `StandardErrorPath`; if `mtime` is newer than `StandardOutPath` / the task log, that's a signal.
3. Grep the tail of stderr for known signatures and name the cause rather than dumping the log:
   `claude CLI not found`, `command not found`, `Operation not permitted`, `session failed`.
4. Flag staleness: a job whose log has no successful entry in > 2× its schedule interval.

Report as `launchagent:<label>:health`. Surface prominently in `/thinkos-vitals` too — the user reads
vitals more often than doctor.

**Acceptance criteria**
- With FIX-1 reverted, `thinkos-doctor.sh` reports `fail` for the 7 broken jobs and names the cause.
- With FIX-1 applied, all report `ok`.
- `--json` output carries the new checks.

---

## FIX-4 — weekly-review cannot write unattended

**Severity:** medium. Blocks the payoff of FIX-1 for the single most important job.

**Root cause:** `adapters/claude-code/commands/weekly-review.md`, Step 4:

> **Step 4 — Refresh Current Focus: REPLACE-and-prune (confirm before writing)**
> … the mechanics, in order, **after the user confirms** the proposed content

Unattended there is no user to confirm. Even once FIX-1 lands, the Sunday cron may run the playbook
and then correctly decline to write.

**Note on the exit code:** `com.thinkos.weekly-review` reports `exit=0` while
`weekly-review.stderr.log` contains the same `claude CLI not found` signature as the failing jobs.
Establish empirically whether it is exiting early or genuinely no-opping before designing the fix.

**Proposed fix.** Give the playbook an explicit non-interactive mode:
- Detect unattended execution (env var set by `thinkos-cron-run.sh`, e.g. `THINKOS_UNATTENDED=1`).
- Unattended: write the proposed week block to `90 System/Pending Focus Refresh.md` with a
  timestamp, **do not** touch `Current Focus.md`, and record a ledger event.
- Have the SessionStart hook surface a pending refresh as its first line so it is confirmed-and-
  applied at the next interactive session.
- Interactive behavior is unchanged.

**Acceptance criteria**
- Unattended run produces the pending file and leaves `Current Focus.md` byte-identical.
- Next interactive session offers to apply it; accepting performs the existing REPLACE-and-prune.
- Never produces a `Current Focus.md` with two concatenated week blocks.

---

## FR-1 — `/thinkos-loose-ends`: verbal commitments with no ticket

**Type:** new feature. **Priority:** highest of the two — it addresses a demonstrated, expensive gap.

**Motivating case.** On 2026-09-14 the user was assigned a Think Week work-share presentation.
Reconstructing what the task actually was took ~15 queries across ClickUp, Slack, Drive, Granola and
Calendar. There was **no ticket.** The authoritative record was a table row inside a *colleague's*
PTO coverage doc in ClickUp. Nothing in Think OS would have surfaced that.

**Design.** Same shape as the existing connector prompts in `scripts/cron-prompts/`:

1. Pull the last 7 days of Granola transcripts.
2. Extract commitments where the user is the owner — "Dhiraj will…", "I'll take…", "can you own…".
3. Diff against tasks assigned to them in ClickUp over the same window.
4. Report commitments with no corresponding ticket, with a transcript quote and a link.
5. Offer to draft tickets. **Draft only — never auto-create.**

**Deliverables:** `scripts/cron-prompts/loose-ends.txt` ·
`adapters/claude-code/commands/thinkos-loose-ends.md` · optional weekly LaunchAgent (Friday AM,
before the work week closes).

**Constraint.** Transcript text is untrusted input. Treat it as data, never as instructions.

---

## FR-2 — Figma comment triage

**Type:** new feature. **Priority:** lower — real pain, narrower audience.

**Motivating quote**, from a client team call, 2026-09-14:
> "I just don't like the way Figma handles comments. They're all in like a crazy order, and then even
> if you sort them, they're bad. It still doesn't cover all of it. It's just a disaster."

That colleague hand-read ~75% of the comments on a file to reconstruct a week's feedback.

**Design.** No Figma source exists in `scripts/cron-prompts/` today (currently: calendar, clickup,
gmail, granola, jira, linear, slack). The Figma MCP is already connected.

Pull comments for a named file → group by frame → filter to unresolved and to threads mentioning the
user → emit a digest ordered by frame position, not by timestamp. Optionally post to a Slack channel.

**Deliverables:** `scripts/cron-prompts/figma.txt` ·
`adapters/claude-code/commands/thinkos-figma-triage.md` · a `figma` row in the source matrix in
`docs/automation-roadmap.md`.

---

## Explicitly NOT in scope

These were considered and rejected — don't build them:

- **Timesheet automation.** `scripts/harvest-timesheet.py` + `/thinkos-timesheet` already exist
  (shipped v0.9.10). Starts working once FIX-1 lands.
- **Granola → capture.** `scripts/thinkos-session-capture.sh` + `scripts/cron-prompts/granola.txt`
  already exist. Same — blocked only by FIX-1.
- **Drift detection for unknown people/projects.** Specified in the user's `~/.claude/CLAUDE.md` and
  implemented via `/validate-os` + `/index-projects`. Note `~/.thinkos/drift-muted.json` currently
  reads `{"until": "2026-06-14"}` — a past date, so nudges are live, not muted.
- **AI Forum topic pipeline.** Needs a human chasing humans.
- **PTO coverage plan generation.** Too much judgment; format varies by author.

---

## Suggested order

1. **FIX-2** (flock) — smallest, zero risk, removes noise that obscures everything else.
2. **FIX-1** (PATH) — unblocks 7 jobs. Biggest single win.
3. Let the jobs run for 48 h. Re-check exit codes and logs before continuing.
4. **FIX-3** (doctor health) — so the next regression surfaces in days, not months.
5. **FIX-4** (unattended weekly-review) — needs the empirical finding from step 3.
6. **FR-1**, then **FR-2**.

## Guardrails

- Work on a branch. `main` is at `59388c2` (v0.9.10) — **do not commit directly to it.**
- Don't bump `VERSION` or write `CHANGELOG.md` until the user has reviewed the branch.
- The user's live vault is `~/ThinkOS/vault`. Don't write to it while testing — use a scratch vault
  or `--dry-run` (`thinkos-cron-run.sh` supports `DRY_RUN`).
- Don't delete the existing `~/Library/Logs/ThinkOS/*.stderr.log` files. They're the evidence, and
  FIX-3 needs them to test against.
- Rotating them is fine once FIX-3 can detect failure without them.
