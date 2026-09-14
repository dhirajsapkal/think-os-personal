#!/usr/bin/env python3
# =============================================================================
# scripts/harvest-timesheet.py — deterministic Harvest week converger
# =============================================================================
# Takes a PLAN (weekly hours per project/task) and makes the Harvest week match
# it. Idempotent: re-running with the same plan is a no-op. Safe: never touches
# entries that are already submitted or approved.
#
# This script does no reasoning and no guessing. The plan comes from a human, or
# from an agent that read whatever your team plans capacity in. Keeping the two
# apart means a bug in the reasoning can never silently rewrite a week — you see
# the diff first.
#
# Setup (once):
#   1. Create a Personal Access Token at https://id.getharvest.com/developers
#   2. Write ~/.thinkos/secrets/harvest.env (chmod 600):
#        HARVEST_ACCOUNT_ID=...
#        HARVEST_USER_ID=...          # optional; defaults to the token's owner
#        HARVEST_SUBDOMAIN=...        # optional; used to print the submit link
#        HARVEST_UA="YourApp (you@example.com)"
#        HARVEST_TOKEN=...
#   3. Run `harvest-timesheet.py catalog --init` to discover the project/task
#      pairs you are assigned to and write ~/.thinkos/harvest-catalog.json.
#      Edit that file to rename slugs, set `fill`, and mark which slugs roll up
#      into the `ledger` total you want reported.
#
# Usage:
#   harvest-timesheet.py catalog [--init]
#   harvest-timesheet.py status   [--week YYYY-MM-DD]
#   harvest-timesheet.py propose  [--week ...] --alloc SLUG=HOURS[@DATE] ...
#   harvest-timesheet.py plan     [--week ...] < plan.json    # dry-run diff
#   harvest-timesheet.py apply    [--week ...] < plan.json    # write it
#   harvest-timesheet.py ledger-report [--from ...] [--to ...]
#
# NOTE: Harvest exposes no submit-for-approval endpoint. This fills the week;
# submitting stays a manual step, which is appropriate — it is an attestation.
#
# Exit codes: 0 ok / 1 error / 2 plan does not balance / 3 nothing to do
# =============================================================================

import argparse
import re
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ENV_PATH = os.path.expanduser("~/.thinkos/secrets/harvest.env")
API = "https://api.harvestapp.com/v2"
LOCKED = {"submitted", "approved"}

CATALOG_PATH = os.path.expanduser("~/.thinkos/harvest-catalog.json")

# Populated from CATALOG_PATH at startup. Shape:
#   slug -> (project_id, task_id, label)
CATALOG = {}
# Slugs booked as whole days (8h) rather than spread across the week.
DAY_KEYS = set()
# Slugs whose hours roll up into the `ledger-report` total.
LEDGER = set()
CAPACITY = 40.0
FILL_SLUG = None


def load_catalog(required=True):
    """Read ~/.thinkos/harvest-catalog.json into the module globals."""
    global CATALOG, DAY_KEYS, LEDGER, CAPACITY, FILL_SLUG
    if not os.path.exists(CATALOG_PATH):
        if required:
            sys.exit(f"no catalog at {CATALOG_PATH}\n"
                     f"run: {os.path.basename(sys.argv[0])} catalog --init")
        return
    try:
        cfg = json.load(open(CATALOG_PATH))
    except (OSError, json.JSONDecodeError) as exc:
        sys.exit(f"could not read {CATALOG_PATH}: {exc}")
    CATALOG = {
        slug: (e["project_id"], e["task_id"], e.get("label", slug))
        for slug, e in cfg.get("catalog", {}).items()
    }
    DAY_KEYS = set(cfg.get("day_slugs", []))
    LEDGER = set(cfg.get("ledger", []))
    CAPACITY = float(cfg.get("capacity", 40.0))
    FILL_SLUG = cfg.get("fill")


def slugify(project_name, task_name, taken):
    """Build a short, stable, human-editable slug from two Harvest names."""
    def squash(text, words):
        parts = re.findall(r"[a-z0-9]+", text.lower())
        drop = {"the", "and", "of", "for", "a", "an", "to"}
        parts = [p for p in parts if p not in drop] or ["x"]
        return "-".join(parts[:words])
    base = f"{squash(project_name, 2)}-{squash(task_name, 2)}"
    slug, n = base, 2
    while slug in taken:
        slug, n = f"{base}-{n}", n + 1
    return slug


# ----------------------------------------------------------------- env + http

def load_env():
    if not os.path.exists(ENV_PATH):
        sys.exit(f"missing {ENV_PATH} — see setup notes")
    env = {}
    with open(ENV_PATH) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"')
    for required in ("HARVEST_TOKEN", "HARVEST_ACCOUNT_ID", "HARVEST_USER_ID", "HARVEST_UA"):
        if required not in env:
            sys.exit(f"{ENV_PATH} is missing {required}")
    return env


def call(env, method, path, body=None, params=None):
    url = f"{API}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {env['HARVEST_TOKEN']}")
    req.add_header("Harvest-Account-Id", env["HARVEST_ACCOUNT_ID"])
    req.add_header("User-Agent", env["HARVEST_UA"])  # mandatory; 400 without it
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        sys.exit(f"HTTP {exc.code} on {method} {path}: {exc.read().decode()[:400]}")


# -------------------------------------------------------------------- helpers

def monday_of(date):
    return date - dt.timedelta(days=date.weekday())


def workdays(week_start):
    return [week_start + dt.timedelta(days=i) for i in range(5)]


def fetch_week(env, week_start):
    end = week_start + dt.timedelta(days=6)
    out, page = [], 1
    while True:
        got = call(env, "GET", "/time_entries", params={
            "user_id": env["HARVEST_USER_ID"],
            "from": week_start.isoformat(),
            "to": end.isoformat(),
            "per_page": 100,
            "page": page,
        })
        out.extend(got.get("time_entries", []))
        if page >= got.get("total_pages", 1):
            return out
        page += 1


def spread(total, days):
    """Split `total` hours across `days` dates in 0.25h steps, front-loading
    any remainder so the week still sums exactly to `total`."""
    if not days or total <= 0:
        return {}
    quarters = int(round(total * 4))
    base, extra = divmod(quarters, len(days))
    return {
        d.isoformat(): (base + (1 if i < extra else 0)) / 4
        for i, d in enumerate(days)
        if base + (1 if i < extra else 0) > 0
    }


def spread_around(total, days, load, day_cap=8.0):
    """Split `total` across `days` in 0.25h steps, respecting hours already
    placed on each day (`load`) so no day exceeds `day_cap`. Falls back to an
    even spread if the pinned hours leave no room."""
    if not days or total <= 0:
        return {}
    quarters = int(round(total * 4))
    room = {d.isoformat(): max(0, int(round((day_cap - load.get(d.isoformat(), 0.0)) * 4)))
            for d in days}
    if sum(room.values()) < quarters:  # over capacity — spread evenly, let the
        return spread(total, days)     # imbalance check downstream complain
    out = {}
    # Round-robin a quarter-hour at a time onto whichever day has the most room.
    while quarters > 0:
        day = max(room, key=lambda d: (room[d], -list(room).index(d)))
        if room[day] <= 0:
            break
        out[day] = out.get(day, 0.0) + 0.25
        room[day] -= 1
        quarters -= 1
    return {d: h for d, h in sorted(out.items()) if h > 0}


def plan_to_targets(plan, week_start):
    """Flatten a plan into {(project_id, task_id, date): hours}.

    Allocations carrying `per_day` are placed first (meetings land on the day
    they happened); the rest fill the remaining room in each working day."""
    targets = {}
    off = set(plan.get("holidays", [])) | set(plan.get("time_off", {}))

    for day in plan.get("holidays", []):
        pid, tid, _ = CATALOG["holiday"]
        targets[(pid, tid, day)] = 8.0
    for day, kind in plan.get("time_off", {}).items():
        pid, tid, _ = CATALOG.get(kind, CATALOG["pto"])
        targets[(pid, tid, day)] = 8.0

    open_days = [d for d in workdays(week_start) if d.isoformat() not in off]
    allocs = [a for a in plan.get("allocations", []) if a.get("hours", 0) > 0]

    load = {}
    for alloc in (a for a in allocs if a.get("per_day")):
        pid, tid = alloc["project_id"], alloc["task_id"]
        for day, hours in alloc["per_day"].items():
            targets[(pid, tid, day)] = targets.get((pid, tid, day), 0) + hours
            load[day] = load.get(day, 0.0) + hours

    for alloc in (a for a in allocs if not a.get("per_day")):
        pid, tid = alloc["project_id"], alloc["task_id"]
        placed = spread_around(alloc["hours"], open_days, load)
        for day, hours in placed.items():
            targets[(pid, tid, day)] = targets.get((pid, tid, day), 0) + hours
            load[day] = load.get(day, 0.0) + hours
    return targets


def diff(existing, targets):
    """Return (creates, updates, deletes, locked)."""
    current = {}
    locked = []
    for e in existing:
        key = (e["project"]["id"], e["task"]["id"], e["spent_date"])
        if (e.get("approval_status") or "").lower() in LOCKED:
            locked.append(e)
        current.setdefault(key, []).append(e)

    creates, updates, deletes = [], [], []
    for key, hours in targets.items():
        rows = current.get(key, [])
        if not rows:
            creates.append((key, hours))
            continue
        keep, dupes = rows[0], rows[1:]
        if abs(keep["hours"] - hours) > 0.001:
            updates.append((keep, hours))
        deletes.extend(dupes)
    for key, rows in current.items():
        if key not in targets:
            deletes.extend(rows)
    return creates, updates, deletes, locked


def label(pid, tid):
    for _, (p, t, name) in CATALOG.items():
        if (p, t) == (pid, tid):
            return name
    return f"project {pid} / task {tid}"


# --------------------------------------------------------------------- render

def show_week(entries, week_start):
    if not entries:
        print(f"  (no entries for week of {week_start})")
        return
    total = sum(e["hours"] for e in entries)
    by_pair = {}
    for e in entries:
        key = (e["project"]["name"], e["task"]["name"], (e.get("approval_status") or "-"))
        by_pair[key] = by_pair.get(key, 0) + e["hours"]
    for (proj, task, status), hours in sorted(by_pair.items(), key=lambda kv: -kv[1]):
        print(f"  {hours:6.2f}h  {proj} / {task}   [{status}]")
    print(f"  {'-' * 60}\n  {total:6.2f}h  TOTAL")


def is_locked(entry):
    return (entry.get("approval_status") or "").lower() in LOCKED


def show_diff(creates, updates, deletes, locked):
    """Print the diff. Operations blocked by an approval lock are shown as
    SKIP, never as work that will happen. Returns True if anything is actually
    actionable."""
    if locked:
        print(f"\n  🔒 {len(locked)} entr{'y' if len(locked)==1 else 'ies'} in this week "
              f"are already submitted/approved and cannot be modified.")
    if not (creates or updates or deletes):
        print("\n  ✅ Harvest already matches the plan — nothing to do.")
        return False

    locked_keys = {(e["project"]["id"], e["task"]["id"], e["spent_date"]) for e in locked}
    actionable = 0
    print()
    for (pid, tid, day), hours in sorted(creates, key=lambda c: c[0][2]):
        if (pid, tid, day) in locked_keys:
            print(f"  · SKIP    {day}  {hours:5.2f}h  {label(pid, tid)}  (week locked)")
        else:
            print(f"  + CREATE  {day}  {hours:5.2f}h  {label(pid, tid)}")
            actionable += 1
    for entry, hours in sorted(updates, key=lambda u: u[0]["spent_date"]):
        tag = label(entry["project"]["id"], entry["task"]["id"])
        if is_locked(entry):
            print(f"  · SKIP    {entry['spent_date']}  {entry['hours']:.2f}h → {hours:.2f}h  "
                  f"{tag}  ({entry['approval_status']})")
        else:
            print(f"  ~ UPDATE  {entry['spent_date']}  {entry['hours']:.2f}h → {hours:.2f}h  {tag}")
            actionable += 1
    for entry in sorted(deletes, key=lambda e: e["spent_date"]):
        tag = label(entry["project"]["id"], entry["task"]["id"])
        if is_locked(entry):
            print(f"  · SKIP    {entry['spent_date']}  {entry['hours']:5.2f}h  "
                  f"{tag}  ({entry['approval_status']})")
        else:
            print(f"  - DELETE  {entry['spent_date']}  {entry['hours']:5.2f}h  {tag}")
            actionable += 1

    if actionable == 0:
        print("\n  ✅ Every change is blocked by an approval lock — nothing to do.")
        return False
    return True


# ----------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Converge a Harvest week onto a plan.")
    ap.add_argument("action", choices=["status", "propose", "plan", "apply",
                                       "catalog", "ledger-report"])
    ap.add_argument("--week", help="any date in the target week (default: this week)")
    ap.add_argument("--init", action="store_true",
                    help="catalog: discover your project/task pairs from Harvest "
                         "and write a starter catalog file")
    ap.add_argument("--from", dest="date_from", help="ledger-report: start date (YYYY-MM-DD)")
    ap.add_argument("--to", dest="date_to", help="ledger-report: end date (YYYY-MM-DD)")
    ap.add_argument("--allow-imbalance", action="store_true",
                    help="apply even if the plan does not sum to capacity")
    ap.add_argument("--alloc", action="append", default=[], metavar="SLUG=HOURS",
                    help="propose: hours for a catalog slug, e.g. --alloc thinkos=8 "
                         "(repeatable). Run `catalog` to list slugs.")
    ap.add_argument("--fill", default=None, metavar="SLUG",
                    help="propose: slug that absorbs the remainder "
                         "(default: the catalog's `fill`)")
    ap.add_argument("--holiday-on", action="append", default=[],
                    help="propose: YYYY-MM-DD that is a company holiday")
    ap.add_argument("--off", action="append", default=[], metavar="YYYY-MM-DD=SLUG",
                    help="propose: a day off, e.g. --off 2026-09-18=pto (repeatable)")
    args = ap.parse_args()

    env = load_env()
    load_catalog(required=not (args.action == "catalog" and args.init))

    if args.action == "catalog" and args.init:
        if os.path.exists(CATALOG_PATH):
            sys.exit(f"{CATALOG_PATH} already exists — edit it, or move it aside "
                     f"to regenerate.")
        me = call(env, "GET", "/users/me")
        capacity = round((me.get("weekly_capacity") or 144000) / 3600, 2)
        entries, page = {}, 1
        while True:
            got = call(env, "GET", "/users/me/project_assignments",
                       params={"per_page": 100, "page": page})
            for pa in got.get("project_assignments", []):
                proj = pa.get("project", {})
                for ta in pa.get("task_assignments", []):
                    task = ta.get("task", {})
                    if not proj.get("id") or not task.get("id"):
                        continue
                    slug = slugify(proj.get("name", "project"),
                                   task.get("name", "task"), entries)
                    entries[slug] = {
                        "project_id": proj["id"],
                        "task_id": task["id"],
                        "label": f"{proj.get('name','?')} / {task.get('name','?')}",
                        "billable": bool(ta.get("billable")),
                    }
            if page >= got.get("total_pages", 1):
                break
            page += 1

        cfg = {
            "_comment": "Generated by `harvest-timesheet.py catalog --init`. "
                        "Rename slugs freely — they are yours. Set `fill` to the "
                        "slug that should absorb leftover capacity, list whole-day "
                        "slugs (time off, holidays) in `day_slugs`, and list any "
                        "slugs you want totalled by `ledger-report` in `ledger`.",
            "capacity": capacity,
            "fill": None,
            "day_slugs": [],
            "ledger": [],
            "catalog": dict(sorted(entries.items())),
        }
        os.makedirs(os.path.dirname(CATALOG_PATH), exist_ok=True)
        with open(CATALOG_PATH, "w") as fh:
            json.dump(cfg, fh, indent=2)
        os.chmod(CATALOG_PATH, 0o600)
        print(f"\nWrote {CATALOG_PATH}")
        print(f"  {len(entries)} project/task pair(s) discovered, "
              f"weekly capacity {capacity:g}h")
        print(f"\nNext: open it and set `fill`, `day_slugs`, and `ledger`.\n")
        return

    if args.action == "catalog":
        if not CATALOG:
            sys.exit(f"catalog at {CATALOG_PATH} is empty — run `catalog --init`")
        print("\nHarvest project/task slugs\n")
        width = max(len(k) for k in CATALOG)
        for key, (pid, tid, name) in CATALOG.items():
            mark = " ·ledger" if key in LEDGER else ""
            print(f"  {key:<{width}}  {name}{mark}")
        print(f"\n  {len(LEDGER)} slug(s) marked ·ledger roll up in ledger-report.\n")
        return

    anchor = dt.date.fromisoformat(args.week) if args.week else dt.date.today()
    week_start = monday_of(anchor)
    capacity = CAPACITY

    if args.action == "status":
        print(f"\nHarvest — week of {week_start} (Mon–Sun)\n")
        show_week(fetch_week(env, week_start), week_start)
        return

    if args.action == "ledger-report":
        # Provenance report: how much time went into the ledger slugs.
        start = args.date_from or f"{dt.date.today().year}-01-01"
        end = args.date_to or dt.date.today().isoformat()
        pairs = {(CATALOG[k][0], CATALOG[k][1]) for k in LEDGER if k in CATALOG}
        rows, page = [], 1
        while True:
            got = call(env, "GET", "/time_entries", params={
                "user_id": env["HARVEST_USER_ID"], "from": start, "to": end,
                "per_page": 100, "page": page,
            })
            rows.extend(got.get("time_entries", []))
            if page >= got.get("total_pages", 1):
                break
            page += 1

        hits = [e for e in rows if (e["project"]["id"], e["task"]["id"]) in pairs]
        print(f"\nLedger — {start} → {end}\n")
        if not hits:
            print("  No hours logged to any ledger slug in this range.\n")
            other = sum(e["hours"] for e in rows)
            print(f"  (for scale: {other:.2f}h logged overall in the same period)\n")
            return
        by_task, first, last = {}, {}, {}
        for e in hits:
            name = f"{e['project']['name']} / {e['task']['name']}"
            by_task[name] = by_task.get(name, 0) + e["hours"]
            first[name] = min(first.get(name, e["spent_date"]), e["spent_date"])
            last[name] = max(last.get(name, e["spent_date"]), e["spent_date"])
        width = max(len(n) for n in by_task)
        for name, hours in sorted(by_task.items(), key=lambda kv: -kv[1]):
            print(f"  {hours:7.2f}h  {name:<{width}}   {first[name]} → {last[name]}")
        total = sum(by_task.values())
        overall = sum(e["hours"] for e in rows)
        print(f"  {'-' * (width + 32)}")
        print(f"  {total:7.2f}h  TOTAL"
              f"   ({total / overall * 100:.1f}% of {overall:.0f}h logged)\n")
        return

    if args.action == "propose":
        requested = []
        pinned = []  # (slug, hours, date) — landed on the day they happened
        for raw in args.alloc:
            if "=" not in raw:
                sys.exit(f"--alloc expects SLUG=HOURS[@DATE], got {raw!r}")
            slug, _, rest = raw.partition("=")
            slug = slug.strip()
            if slug not in CATALOG:
                sys.exit(f"unknown slug {slug!r} — run `catalog` to list them")
            if slug in DAY_KEYS:
                sys.exit(f"{slug!r} is per-day; use --off YYYY-MM-DD={slug}")
            hours, _, day = rest.partition("@")
            try:
                hours = float(hours)
            except ValueError:
                sys.exit(f"--alloc {raw!r}: {hours!r} is not a number")
            if day:
                try:
                    dt.date.fromisoformat(day.strip())
                except ValueError:
                    sys.exit(f"--alloc {raw!r}: {day!r} is not a YYYY-MM-DD date")
                pinned.append((slug, hours, day.strip()))
            else:
                requested.append((slug, hours))

        time_off = {}
        for raw in args.off:
            day, _, slug = raw.partition("=")
            slug = (slug or "pto").strip()
            if slug not in DAY_KEYS or slug == "holiday":
                sys.exit(f"--off slug must be one of pto/sick/donor, got {slug!r}")
            dt.date.fromisoformat(day.strip())  # validate
            time_off[day.strip()] = slug

        merged = {}
        for slug, hours in requested:
            merged[slug] = merged.get(slug, 0.0) + hours

        pinned_total = sum(h for _, h, _ in pinned)
        booked = (sum(merged.values()) + pinned_total
                  + 8 * (len(args.holiday_on) + len(time_off)))
        gap = capacity - booked
        if gap > 0:
            fill = args.fill or FILL_SLUG
            if not fill:
                sys.exit("nothing to absorb the remainder — pass --fill SLUG or "
                         f"set \"fill\" in {CATALOG_PATH}")
            if fill not in CATALOG:
                sys.exit(f"unknown --fill slug {fill!r}")
            merged[fill] = merged.get(fill, 0.0) + gap
            print(f"# balanced to capacity: +{gap:.2f}h → {CATALOG[fill][2]}",
                  file=sys.stderr)

        allocations = []
        # Pinned first: meetings land on the day they actually happened.
        by_pin = {}
        for slug, hours, day in pinned:
            by_pin.setdefault(slug, {})
            by_pin[slug][day] = by_pin[slug].get(day, 0.0) + hours
        for slug, per_day in by_pin.items():
            pid, tid, name = CATALOG[slug]
            allocations.append({
                "project_id": pid, "task_id": tid, "slug": slug, "label": name,
                "hours": round(sum(per_day.values()), 2),
                "per_day": {d: round(h, 2) for d, h in sorted(per_day.items())},
            })
        for slug, hours in merged.items():
            pid, tid, name = CATALOG[slug]
            allocations.append({"project_id": pid, "task_id": tid,
                                "hours": round(hours, 2), "slug": slug, "label": name})

        led_hours = sum(a["hours"] for a in allocations if a.get("slug") in LEDGER)
        if led_hours:
            print(f"# ledger slugs this week: {led_hours:.2f}h", file=sys.stderr)

        print(json.dumps({
            "week_start": week_start.isoformat(),
            "capacity": capacity,
            "holidays": args.holiday_on,
            "time_off": time_off,
            "allocations": allocations,
        }, indent=2))
        return

    plan = json.load(sys.stdin)
    if plan.get("week_start") and plan["week_start"] != week_start.isoformat():
        week_start = monday_of(dt.date.fromisoformat(plan["week_start"]))

    targets = plan_to_targets(plan, week_start)
    booked = sum(targets.values())
    existing = fetch_week(env, week_start)
    creates, updates, deletes, locked = diff(existing, targets)

    print(f"\nHarvest — week of {week_start}\n\nCURRENT:")
    show_week(existing, week_start)
    print(f"\nPLANNED: {booked:.2f}h against {capacity:.0f}h capacity")
    changed = show_diff(creates, updates, deletes, locked)

    if abs(booked - capacity) > 0.001:
        msg = (f"\n  ⚠️  plan totals {booked:.2f}h, capacity is {capacity:.0f}h "
               f"({booked - capacity:+.2f}h)")
        if args.action == "apply" and not args.allow_imbalance:
            print(msg + "\n  refusing to apply — pass --allow-imbalance if intended.")
            sys.exit(2)
        print(msg)

    if args.action == "plan":
        print("\n  (dry run — nothing written. Re-run with `apply` to commit.)")
        return
    if not changed:
        sys.exit(3)

    locked_keys = {(e["project"]["id"], e["task"]["id"], e["spent_date"]) for e in locked}
    written = 0
    for (pid, tid, day), hours in creates:
        if (pid, tid, day) in locked_keys:
            continue
        call(env, "POST", "/time_entries", body={
            "user_id": int(env["HARVEST_USER_ID"]), "project_id": pid,
            "task_id": tid, "spent_date": day, "hours": hours,
            "notes": plan.get("notes", ""),
        })
        written += 1
    for entry, hours in updates:
        if (entry.get("approval_status") or "").lower() in LOCKED:
            continue
        call(env, "PATCH", f"/time_entries/{entry['id']}", body={"hours": hours})
        written += 1
    for entry in deletes:
        if (entry.get("approval_status") or "").lower() in LOCKED:
            continue
        call(env, "DELETE", f"/time_entries/{entry['id']}")
        written += 1

    print(f"\n  ✅ {written} change(s) written.")
    print(f"\nRESULT:")
    show_week(fetch_week(env, week_start), week_start)
    print(f"\n  ⚠️  Harvest has no submit-for-approval API. Submit manually:")
    print(f"  https://{env.get('HARVEST_SUBDOMAIN','')}.harvestapp.com"
          f"/time/week/{week_start.year}/{week_start.month}/{week_start.day}")


if __name__ == "__main__":
    main()
