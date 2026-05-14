#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-state.sh — Read/write the Think OS onboarding state file
# =============================================================================
# Single source of truth for "where is the user in the setup flow?". Phase 1
# (the wizard) writes it at the end of a successful apply; Phase 2 (the
# context-seeding agent playbook) reads and updates it as the user progresses
# through each target file.
#
# State file: ~/.thinkos/wizard-state.json
#
# Subcommands:
#   init <args>         Create the initial state file from Phase 1 choices
#   path                Print the absolute path to the state file
#   show                Pretty-print the current state
#   get <key>           Print the value at a dotted path (e.g. files_seeded.identity)
#   set <key> <value>   Set a value at a dotted path; type-coerced (true/false/null/int else string)
#   mark-seeded <file>  Shortcut: files_seeded.<file> = true and bump updated_at
#   set-phase <name>    Shortcut: phase = <name> and bump updated_at
#   where-am-i          Human-readable description of current state
#   reset               Delete the state file (asks for confirmation)
#
# Phase enum:
#   awaiting_oauth_and_restart  Wizard finished apply; user has OAuth + restart to do
#   ready_for_seeding           OAuth/restart done; ready for Phase 2 content seeding
#   seeding                     Phase 2 in progress
#   complete                    All done
#
# All JSON operations go through python3 stdlib (always available on macOS).
# =============================================================================
set -uo pipefail

STATE_DIR="$HOME/.thinkos"
STATE_FILE="$STATE_DIR/wizard-state.json"

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-state.sh <subcommand> [args]

Subcommands:
  init --vault PATH --products LIST [--bundle PRESET] [--oauth-pending LIST]
  path
  show
  get <dotted-key>
  set <dotted-key> <value>
  mark-seeded <file-key>     (identity | current_focus | project_index | people | decisions)
  set-phase <phase>          (awaiting_oauth_and_restart | ready_for_seeding | seeding | complete)
  where-am-i
  reset
  -h, --help

Examples:
  scripts/thinkos-state.sh init --vault ~/ThinkOS/vault --products claude-code --bundle pm
  scripts/thinkos-state.sh get phase
  scripts/thinkos-state.sh set phase ready_for_seeding
  scripts/thinkos-state.sh mark-seeded identity
  scripts/thinkos-state.sh where-am-i
EOF
}

# -----------------------------------------------------------------------------
# Python helper — receives full args via stdin args, operates on STATE_FILE,
# writes back atomically via tempfile + rename.
# -----------------------------------------------------------------------------
_state_py() {
  STATE_FILE="$STATE_FILE" python3 - "$@" <<'PYEOF'
import json, os, sys, tempfile, datetime

state_file = os.environ["STATE_FILE"]

def load():
    if not os.path.exists(state_file):
        return None
    try:
        with open(state_file) as fh:
            return json.load(fh)
    except (json.JSONDecodeError, OSError) as e:
        print(f"thinkos-state: state file is unreadable: {e}", file=sys.stderr)
        sys.exit(2)

def save(state):
    state["updated_at"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    os.makedirs(os.path.dirname(state_file), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(state_file), prefix=".wizard-state-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(state, fh, indent=2, sort_keys=False)
            fh.write("\n")
        os.replace(tmp, state_file)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise

def coerce(val):
    if val == "true":  return True
    if val == "false": return False
    if val == "null":  return None
    try: return int(val)
    except ValueError: pass
    return val

def get_at(state, dotted):
    cur = state
    for k in dotted.split("."):
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return None
    return cur

def set_at(state, dotted, value):
    keys = dotted.split(".")
    cur = state
    for k in keys[:-1]:
        if not isinstance(cur.get(k), dict):
            cur[k] = {}
        cur = cur[k]
    cur[keys[-1]] = value

argv = sys.argv[1:]
sub = argv[0]

if sub == "init":
    # parse flags
    args = argv[1:]
    vault = ""
    products = []
    bundle = ""
    oauth_pending = []
    i = 0
    while i < len(args):
        if args[i] == "--vault":           vault = args[i+1]; i += 2
        elif args[i] == "--products":      products = [p for p in args[i+1].split(",") if p]; i += 2
        elif args[i] == "--bundle":        bundle = args[i+1]; i += 2
        elif args[i] == "--oauth-pending": oauth_pending = [p for p in args[i+1].split(",") if p]; i += 2
        else: i += 1

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state = {
        "version": 1,
        "created_at": now,
        "updated_at": now,
        "phase": "awaiting_oauth_and_restart",
        "vault": vault,
        "products": products,
        "bundle": bundle,
        "oauth_pending": oauth_pending,
        "files_seeded": {
            "identity": False,
            "current_focus": False,
            "project_index": False,
            "people": False,
            "decisions": False,
        },
        "sources_consented": {
            "filesystem": None,
            "granola": None,
            "calendar": None,
            "slack": None,
            "gmail": None,
            "drive": None,
            "notion": None,
            "linear": None,
            "atlassian": None,
        },
    }
    save(state)
    print(f"Initialized state at {state_file}")
    sys.exit(0)

state = load()
if state is None:
    print(f"thinkos-state: no state file at {state_file}. Run Phase 1 first (scripts/thinkos-setup.sh, or paste the install one-liner in Claude Code).", file=sys.stderr)
    sys.exit(1)

if sub == "path":
    print(state_file)
elif sub == "show":
    print(json.dumps(state, indent=2))
elif sub == "get":
    val = get_at(state, argv[1])
    if val is None: pass
    elif isinstance(val, (dict, list)): print(json.dumps(val))
    else: print(val)
elif sub == "set":
    set_at(state, argv[1], coerce(argv[2]))
    save(state)
elif sub == "mark-seeded":
    set_at(state, f"files_seeded.{argv[1]}", True)
    save(state)
elif sub == "set-phase":
    state["phase"] = argv[1]
    save(state)
elif sub == "where-am-i":
    phase = state.get("phase", "unknown")
    vault = state.get("vault", "?")
    products = ", ".join(state.get("products", []))
    bundle = state.get("bundle") or "none"
    oauth = state.get("oauth_pending", [])
    seeded = state.get("files_seeded", {})
    seeded_done = [k for k, v in seeded.items() if v]
    seeded_todo = [k for k, v in seeded.items() if not v]

    lines = [
        f"Phase:     {phase}",
        f"Vault:     {vault}",
        f"Products:  {products}",
        f"Bundle:    {bundle}",
    ]
    if phase == "awaiting_oauth_and_restart":
        lines.append("")
        lines.append("Next: complete OAuth for any pending connectors, then restart your")
        lines.append("agent app(s). After that, run `scripts/thinkos-continue.sh` or invoke")
        lines.append("the /thinkos-continue slash command.")
        if oauth:
            lines.append("")
            lines.append("OAuth still pending for: " + ", ".join(oauth))
    elif phase == "ready_for_seeding":
        lines.append("")
        lines.append("Next: Phase 2 content seeding. Run /thinkos-continue (in Claude Code")
        lines.append("or Cowork) and the agent will draft your HOT-tier files from your")
        lines.append("connected tools.")
    elif phase == "seeding":
        lines.append("")
        lines.append("In progress. Files completed: " + (", ".join(seeded_done) or "none yet"))
        lines.append("Files remaining: " + (", ".join(seeded_todo) or "none"))
    elif phase == "complete":
        lines.append("")
        lines.append("All done. Your Think OS is set up and seeded.")

    print("\n".join(lines))
elif sub == "reset":
    if len(argv) > 1 and argv[1] == "--yes":
        os.unlink(state_file)
        print(f"Removed {state_file}")
    else:
        print(f"Refusing to delete {state_file} without --yes confirmation.", file=sys.stderr)
        sys.exit(2)
else:
    print(f"Unknown subcommand: {sub}", file=sys.stderr)
    sys.exit(2)
PYEOF
}

if [[ $# -eq 0 ]]; then usage; exit 0; fi
case "$1" in
  -h|--help) usage; exit 0 ;;
  *) _state_py "$@" ;;
esac
