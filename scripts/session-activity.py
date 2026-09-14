#!/usr/bin/env python3
# =============================================================================
# scripts/session-activity.py — timestamp-accurate Claude Code activity
# =============================================================================
# Reads ~/.claude/projects/**/*.jsonl and reports, per (working directory, local
# date): when work actually happened, for how long, and which files were edited.
#
# Why this exists: the earlier capture selected session FILES by mtime and then
# counted every edit in the whole file. A single session file can span many days,
# so every run re-reported the same edits, and any touch of the file — an app
# launch, a sync, a metadata rewrite — replayed the entire history as "today's
# work". That produced phantom activity on days when nothing happened.
#
# This reads the per-entry `timestamp` on each JSONL line and only counts events
# inside the requested window. Output is JSON, one object per (cwd, date).
#
# Active time = sum of gaps between consecutive events where the gap is <=
# --idle-gap minutes, plus --tail minutes per contiguous block (work continues
# briefly after the last recorded event). Gaps longer than --idle-gap are
# treated as "away" and are not counted. This under-counts thinking time with no
# tool calls — it is deliberately conservative, because it feeds a timesheet.
#
# Usage:
#   session-activity.py --since 2026-09-14            # from a date
#   session-activity.py --since-epoch 1789390000      # from a unix ts
#   session-activity.py --from 2026-09-08 --to 2026-09-12
#   session-activity.py --week 2026-09-14             # Mon–Sun of that week
#   session-activity.py --since 2026-09-01 --format text
# =============================================================================

import argparse
import datetime as dt
import json
import os
import sys

PROJECTS_DIR = os.path.expanduser("~/.claude/projects")
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}


def parse_ts(raw):
    """ISO8601 (with Z or offset) -> aware datetime, or None."""
    if not raw or not isinstance(raw, str):
        return None
    try:
        return dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None


def iter_events(path, lo, hi):
    """Yield (timestamp, cwd, branch, edited_paths, is_edit) for entries whose
    own timestamp falls inside [lo, hi]. Never trusts file mtime."""
    last_cwd = None
    last_branch = None
    try:
        fh = open(path, "r", errors="replace")
    except OSError:
        return
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            # cwd/gitBranch appear on most but not all lines; carry forward.
            if obj.get("cwd"):
                last_cwd = obj["cwd"]
            # "HEAD" shows up for detached checkouts and non-repo dirs — it
            # carries no information, so don't record it as a branch.
            if obj.get("gitBranch") and obj["gitBranch"] != "HEAD":
                last_branch = obj["gitBranch"]

            ts = parse_ts(obj.get("timestamp"))
            if ts is None:
                continue
            if ts < lo or ts > hi:
                continue

            edited = set()
            msg = obj.get("message")
            content = msg.get("content") if isinstance(msg, dict) else None
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict) or block.get("type") != "tool_use":
                        continue
                    if block.get("name") not in EDIT_TOOLS:
                        continue
                    inp = block.get("input") or {}
                    fp = inp.get("file_path") or inp.get("path")
                    if fp:
                        edited.add(fp)
                    for edit in (inp.get("edits") or []):
                        if isinstance(edit, dict):
                            ep = edit.get("file_path") or edit.get("path")
                            if ep:
                                edited.add(ep)

            yield ts, last_cwd, last_branch, edited, bool(edited)


def active_minutes(stamps, idle_gap, tail):
    """Sum gaps <= idle_gap; add `tail` per contiguous block."""
    if not stamps:
        return 0.0
    stamps = sorted(stamps)
    total = 0.0
    blocks = 1
    for prev, cur in zip(stamps, stamps[1:]):
        gap = (cur - prev).total_seconds() / 60.0
        if gap <= idle_gap:
            total += gap
        else:
            blocks += 1
    return round(total + blocks * tail, 1)


def collect(lo, hi, idle_gap, tail, min_minutes, projects_dir=PROJECTS_DIR):
    buckets = {}
    if not os.path.isdir(projects_dir):
        return []
    for root, _dirs, files in os.walk(projects_dir):
        for fname in files:
            if not fname.endswith(".jsonl"):
                continue
            path = os.path.join(root, fname)
            for ts, cwd, branch, edited, is_edit in iter_events(path, lo, hi):
                if not cwd:
                    continue
                day = ts.astimezone().date().isoformat()
                key = (cwd, day)
                b = buckets.setdefault(key, {
                    "cwd": cwd, "date": day, "stamps": [], "files": set(),
                    "edits": 0, "events": 0, "branch": branch, "sessions": set(),
                })
                b["stamps"].append(ts)
                b["events"] += 1
                b["files"].update(edited)
                if is_edit:
                    b["edits"] += 1
                if branch:
                    b["branch"] = branch
                b["sessions"].add(path)

    out = []
    for b in buckets.values():
        mins = active_minutes(b["stamps"], idle_gap, tail)
        if mins < min_minutes:
            continue
        stamps = sorted(b["stamps"])
        out.append({
            "cwd": b["cwd"],
            "project": os.path.basename(b["cwd"].rstrip("/")) or b["cwd"],
            "date": b["date"],
            "first": stamps[0].astimezone().strftime("%H:%M"),
            "last": stamps[-1].astimezone().strftime("%H:%M"),
            "active_minutes": mins,
            "active_hours": round(mins / 60.0, 2),
            "events": b["events"],
            "edit_calls": b["edits"],
            "files": sorted(b["files"]),
            "file_count": len(b["files"]),
            "branch": b["branch"],
            "session_files": len(b["sessions"]),
        })
    out.sort(key=lambda r: (r["date"], r["first"]))
    return out


def main():
    ap = argparse.ArgumentParser(
        description="Timestamp-accurate Claude Code activity, per project and day.",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--since", metavar="YYYY-MM-DD")
    g.add_argument("--since-epoch", type=int)
    g.add_argument("--week", metavar="YYYY-MM-DD", help="Mon–Sun containing this date")
    ap.add_argument("--from", dest="date_from", metavar="YYYY-MM-DD")
    ap.add_argument("--to", dest="date_to", metavar="YYYY-MM-DD")
    ap.add_argument("--idle-gap", type=float, default=15.0,
                    help="minutes of silence that ends a work block (default 15)")
    ap.add_argument("--tail", type=float, default=2.0,
                    help="minutes credited after each block's last event (default 2)")
    ap.add_argument("--min-minutes", type=float, default=5.0,
                    help="drop buckets shorter than this (default 5)")
    ap.add_argument("--format", choices=["json", "text"], default="json")
    ap.add_argument("--projects-dir", default=PROJECTS_DIR)
    args = ap.parse_args()

    if not any([args.since, args.since_epoch, args.week, args.date_from, args.date_to]):
        ap.error("give a window: --since / --since-epoch / --week, or --from/--to")

    tz = dt.datetime.now().astimezone().tzinfo
    if args.date_from and not (args.since or args.since_epoch or args.week):
        lo = dt.datetime.combine(dt.date.fromisoformat(args.date_from), dt.time.min, tz)
        hi = dt.datetime.now(tz)
    elif args.week:
        anchor = dt.date.fromisoformat(args.week)
        start = anchor - dt.timedelta(days=anchor.weekday())
        lo = dt.datetime.combine(start, dt.time.min, tz)
        hi = lo + dt.timedelta(days=7)
    elif args.since_epoch is not None:
        lo = dt.datetime.fromtimestamp(args.since_epoch, tz)
        hi = dt.datetime.now(tz)
    else:
        lo = dt.datetime.combine(dt.date.fromisoformat(args.since), dt.time.min, tz)
        hi = dt.datetime.now(tz)
    if args.date_from:
        lo = dt.datetime.combine(dt.date.fromisoformat(args.date_from), dt.time.min, tz)
    if args.date_to:
        hi = dt.datetime.combine(dt.date.fromisoformat(args.date_to), dt.time.max, tz)

    rows = collect(lo, hi, args.idle_gap, args.tail, args.min_minutes, args.projects_dir)

    if args.format == "json":
        print(json.dumps({
            "from": lo.isoformat(), "to": hi.isoformat(),
            "idle_gap_minutes": args.idle_gap,
            "total_active_hours": round(sum(r["active_hours"] for r in rows), 2),
            "buckets": rows,
        }, indent=2))
        return

    if not rows:
        print(f"\nNo recorded activity between {lo.date()} and {hi.date()}.\n")
        return
    print(f"\nClaude Code activity · {lo.date()} → {hi.date()}"
          f"  (idle gap {args.idle_gap:.0f}m)\n")
    cur = None
    for r in rows:
        if r["date"] != cur:
            cur = r["date"]
            weekday = dt.date.fromisoformat(cur).strftime("%a")
            print(f"  {weekday} {cur}")
        files = ""
        if r["file_count"]:
            shown = ", ".join(os.path.basename(f) for f in r["files"][:3])
            more = f" +{r['file_count'] - 3}" if r["file_count"] > 3 else ""
            files = f"   [{shown}{more}]"
        print(f"    {r['first']}–{r['last']}  {r['active_hours']:5.2f}h  "
              f"{r['project']}  ({r['edit_calls']} edits, {r['file_count']} files)"
              f"{files}")
    total = sum(r["active_hours"] for r in rows)
    by_proj = {}
    for r in rows:
        by_proj[r["project"]] = by_proj.get(r["project"], 0) + r["active_hours"]
    print(f"\n  By project:")
    for proj, hours in sorted(by_proj.items(), key=lambda kv: -kv[1]):
        print(f"    {hours:6.2f}h  {proj}")
    print(f"    {'-' * 30}\n    {total:6.2f}h  TOTAL ACTIVE\n")


if __name__ == "__main__":
    main()
