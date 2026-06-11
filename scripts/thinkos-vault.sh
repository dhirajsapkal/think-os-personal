#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-vault.sh — Think OS vault registry CLI
# =============================================================================
# Manages ~/.thinkos/vaults.json — the source of truth for all registered
# vaults (personal, project, reference). Used by the agent and other Think OS
# scripts to discover and route to vaults.
#
# Subcommands:
#   list                          Show all registered vaults
#   use <id>                      Sticky-override active vault for this session
#                                 (writes ~/.thinkos/active-vault)
#   create-project <name>         Create a new project vault (interactive)
#   clone <git-url>               Clone an existing project vault (interactive)
#   add-reference <path>          Register an existing folder as a reference
#   remove <id> --yes             Deregister a vault (does NOT delete files)
#   rename <old-id>               Rename a vault's id and/or label
#                                 (--id, --label, --yes)
#   migrate                       One-time v0-to-v1 migration
#                                 (--id, --label, --path)
#   -h, --help
#
# Storage: ~/.thinkos/vaults.json (per docs/multi-vault-architecture.md §2)
# Atomic writes via tempfile + rename. Python3 stdlib for JSON.
#
# Bash 3.2 compatible (macOS default). All JSON manipulation is in python3.
# =============================================================================
set -uo pipefail

THINKOS_DIR="$HOME/.thinkos"
REGISTRY="$THINKOS_DIR/vaults.json"
ACTIVE_FILE="$THINKOS_DIR/active-vault"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_TEAM_DIR="$REPO_ROOT/templates/team"

# Flags that subcommands may consume
YES=0
REMOTE_URL=""
MIGRATE_PATH=""
NEW_ID=""
NEW_LABEL=""
LABEL_SET=0

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-vault.sh <subcommand> [args]

Subcommands:
  list                          Show all registered vaults.
  use <id>                      Set the active vault for this session.
  create-project <name>         Create a new project vault. Walks you
                                through label, path, git remote, and BM
                                project name. Runs git + basic-memory
                                setup as needed.
  clone <git-url>               Clone an existing project vault, verify
                                it, register, and index in basic-memory.
  add-reference <path>          Register an existing folder as a
                                read-only reference vault.
  remove <id> --yes             Deregister a vault. Does NOT delete files.
                                Requires --yes to proceed.
  rename <old-id> [options]     Rename a vault's id and/or label.
                                Options:
                                  --id <new-id>       New id ([a-z0-9-]+).
                                  --label "<text>"    New display label.
                                  --yes               Skip confirmation.
                                Updates ~/.thinkos/active-vault if needed.
                                Does NOT touch path or bm_project.
  track <path>                  Track a project directory for session
                                capture: Claude sessions whose cwd is
                                under it get captured into the work log.
  untrack <path>                Stop tracking a project directory.
  migrate [options]             One-time migration: auto-register an
                                existing v0 single-vault setup. Idempotent.
                                Options:
                                  --id <id>           Register under this id
                                                      (default: personal).
                                  --label "<text>"    Display label
                                                      (default: from git
                                                      user.name).
                                  --path <path>      Explicit vault path.
  -h, --help                    Show this help.

Storage:
  Registry:     ~/.thinkos/vaults.json
  Active vault: ~/.thinkos/active-vault
EOF
}

rename_usage() {
  cat <<'EOF'
Usage: scripts/thinkos-vault.sh rename <old-id> [options]

Rename a vault's id and/or display label. At least one of --id or
--label must be provided.

Options:
  --id <new-id>       New id. Must be [a-z0-9-]+.
  --label "<text>"    New display label. Free-form.
  --yes               Skip the confirmation prompt.
  -h, --help          Show this help.

Notes:
  · Does NOT change the vault's path or bm_project.
  · If ~/.thinkos/active-vault points at <old-id>, it is updated to
    the new id.
EOF
}

migrate_usage() {
  cat <<'EOF'
Usage: scripts/thinkos-vault.sh migrate [options]

One-time migration: register an existing v0 single-vault setup in the
multi-vault registry. Idempotent — re-running with the same id exits
cleanly.

Options:
  --id <id>           Register under this id (default: personal).
                      Must be [a-z0-9-]+.
  --label "<text>"    Display label. Defaults to
                      "<git user.name>'s Think OS" (falls back to
                      the current OS username if git is unconfigured).
  --path <path>       Explicit vault path. Skips auto-detection.
  -h, --help          Show this help.
EOF
}

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# Python helper — operate on the registry. Inputs come via env vars and argv;
# JSON read/write is atomic. Returns the registry's data on stdout when asked.
# -----------------------------------------------------------------------------
_registry_py() {
  REGISTRY="$REGISTRY" python3 - "$@" <<'PYEOF'
import json, os, sys, tempfile, datetime

registry_path = os.environ["REGISTRY"]

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load():
    if not os.path.exists(registry_path):
        return {"version": 1, "vaults": []}
    try:
        with open(registry_path) as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError) as e:
        print("thinkos-vault: registry is unreadable: %s" % e, file=sys.stderr)
        sys.exit(2)
    if "vaults" not in data or not isinstance(data["vaults"], list):
        data["vaults"] = []
    if "version" not in data:
        data["version"] = 1
    return data

def save(data):
    os.makedirs(os.path.dirname(registry_path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(registry_path),
                                prefix=".vaults-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, indent=2, sort_keys=False)
            fh.write("\n")
        os.replace(tmp, registry_path)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise

def find_by_id(data, vid):
    for v in data["vaults"]:
        if v.get("id") == vid:
            return v
    return None

def find_by_path(data, path):
    # Normalize both sides
    target = os.path.abspath(os.path.expanduser(path))
    for v in data["vaults"]:
        p = v.get("path", "")
        if os.path.abspath(os.path.expanduser(p)) == target:
            return v
    return None

argv = sys.argv[1:]
op = argv[0]

if op == "list":
    data = load()
    print(json.dumps(data, indent=2))
    sys.exit(0)

elif op == "ids":
    data = load()
    for v in data["vaults"]:
        print(v.get("id", ""))
    sys.exit(0)

elif op == "exists-id":
    data = load()
    print("yes" if find_by_id(data, argv[1]) else "no")
    sys.exit(0)

elif op == "exists-path":
    data = load()
    print("yes" if find_by_path(data, argv[1]) else "no")
    sys.exit(0)

elif op == "field":
    # field <id> <key>
    data = load()
    v = find_by_id(data, argv[1])
    if v is None:
        sys.exit(1)
    val = v.get(argv[2])
    if val is None:
        sys.exit(0)
    if isinstance(val, (dict, list)):
        print(json.dumps(val))
    else:
        print(val)
    sys.exit(0)

elif op == "add":
    # add <json-blob>
    data = load()
    new = json.loads(argv[1])
    if "id" not in new:
        print("add: missing id", file=sys.stderr)
        sys.exit(2)
    if find_by_id(data, new["id"]):
        print("add: id already exists: %s" % new["id"], file=sys.stderr)
        sys.exit(3)
    new.setdefault("created_at", now_iso())
    data["vaults"].append(new)
    save(data)
    sys.exit(0)

elif op == "remove":
    data = load()
    vid = argv[1]
    before = len(data["vaults"])
    data["vaults"] = [v for v in data["vaults"] if v.get("id") != vid]
    if len(data["vaults"]) == before:
        print("remove: not found: %s" % vid, file=sys.stderr)
        sys.exit(1)
    save(data)
    sys.exit(0)

elif op == "update":
    # update <old-id> <json-patch>
    # Applies the keys in <json-patch> to the entry whose id == old-id.
    # If the patch contains "id", that becomes the new id (caller is
    # responsible for ensuring no collision).
    data = load()
    old_id = argv[1]
    patch = json.loads(argv[2])
    target = find_by_id(data, old_id)
    if target is None:
        print("update: not found: %s" % old_id, file=sys.stderr)
        sys.exit(1)
    for k, v in patch.items():
        target[k] = v
    save(data)
    sys.exit(0)

elif op == "list-rows":
    # Tab-separated rows for shell-side pretty-printing:
    # id \t type \t default \t bm_project \t path
    data = load()
    for v in data["vaults"]:
        print("\t".join([
            str(v.get("id", "")),
            str(v.get("type", "")),
            "yes" if v.get("default") else "",
            str(v.get("bm_project", "")),
            str(v.get("path", "")),
        ]))
    sys.exit(0)

elif op == "read-vault-json":
    # read-vault-json <path-to-vault.json>
    p = argv[1]
    try:
        with open(p) as fh:
            data = json.load(fh)
    except Exception as e:
        print("read-vault-json: %s" % e, file=sys.stderr)
        sys.exit(1)
    print(json.dumps(data))
    sys.exit(0)

else:
    print("registry-py: unknown op: %s" % op, file=sys.stderr)
    sys.exit(2)
PYEOF
}

# -----------------------------------------------------------------------------
# Validation helpers
# -----------------------------------------------------------------------------
valid_id() {
  # Bash 3.2 compatible regex check via grep
  printf '%s' "$1" | grep -qE '^[a-z0-9-]+$'
}

# -----------------------------------------------------------------------------
# `list` — pretty-print all registered vaults
# -----------------------------------------------------------------------------
cmd_list() {
  if [ ! -f "$REGISTRY" ]; then
    log "No vaults registered yet (no $REGISTRY)."
    log ""
    log "Get started with one of:"
    log "  scripts/thinkos-vault.sh migrate                # auto-register an existing v0 vault"
    log "  scripts/thinkos-vault.sh create-project <name>  # create a new project vault"
    log "  scripts/thinkos-vault.sh clone <git-url>        # join an existing team vault"
    return 0
  fi

  local rows
  rows="$(_registry_py list-rows 2>/dev/null || true)"
  if [ -z "$rows" ]; then
    log "Registry is empty: $REGISTRY"
    return 0
  fi

  # Active vault (override file if present, else default flag)
  local active_id=""
  if [ -f "$ACTIVE_FILE" ]; then
    active_id="$(cat "$ACTIVE_FILE" 2>/dev/null | head -1 | tr -d '[:space:]')"
  fi

  printf '%-20s  %-10s  %-7s  %-22s  %s\n' "ID" "TYPE" "DEFAULT" "BM PROJECT" "PATH"
  printf '%-20s  %-10s  %-7s  %-22s  %s\n' "--" "----" "-------" "----------" "----"
  while IFS=$'\t' read -r id type def bm path; do
    local row_marker=" "
    if [ "$id" = "$active_id" ]; then
      row_marker="*"
    fi
    printf '%s%-19s  %-10s  %-7s  %-22s  %s\n' "$row_marker" "$id" "$type" "$def" "$bm" "$path"
  done < <(printf '%s\n' "$rows")

  log ""
  if [ -n "$active_id" ]; then
    log "* = active vault (sticky override): $active_id"
  else
    log "No sticky active-vault override. Default vault is in use unless CWD or --vault overrides."
  fi
}

# -----------------------------------------------------------------------------
# `use <id>` — write the sticky override file
# -----------------------------------------------------------------------------
cmd_use() {
  local vid="$1"
  if [ -z "$vid" ]; then
    err "use: missing <id>"
    return 2
  fi

  mkdir -p "$THINKOS_DIR"
  # Ensure registry exists (auto-create empty if not)
  if [ ! -f "$REGISTRY" ]; then
    _registry_py add '{"id":"__placeholder__"}' >/dev/null 2>&1 || true
    # Remove placeholder if we created one
    _registry_py remove "__placeholder__" >/dev/null 2>&1 || true
  fi

  local exists
  exists="$(_registry_py exists-id "$vid")"
  if [ "$exists" != "yes" ]; then
    err "use: no such vault id: $vid"
    err ""
    err "Registered vault ids:"
    local ids
    ids="$(_registry_py ids 2>/dev/null)"
    if [ -z "$ids" ]; then
      err "  (none — run create-project, clone, or migrate first)"
    else
      printf '%s\n' "$ids" | sed 's/^/  /' >&2
    fi
    return 1
  fi

  printf '%s\n' "$vid" > "$ACTIVE_FILE"
  log "Active vault set to: $vid"
  log "(written to $ACTIVE_FILE — agents read this on session start)"
}

# -----------------------------------------------------------------------------
# `create-project <name>` — interactive create
# -----------------------------------------------------------------------------
cmd_create_project() {
  local name="$1"
  if [ -z "$name" ]; then
    err "create-project: missing <name>"
    return 2
  fi
  if ! valid_id "$name"; then
    err "create-project: invalid name '$name'. Use lowercase letters, digits, hyphens only ([a-z0-9-]+)."
    return 2
  fi

  mkdir -p "$THINKOS_DIR"

  # Defaults
  local default_id="$name"
  local default_label
  default_label="$(printf '%s' "$name" | tr '-' ' ') Team OS"
  local default_path="$HOME/ThinkOS/projects/$name"
  local default_bm="$name-os"

  # Prompts
  log ""
  log "Creating project vault '$name'."
  log ""
  local vid label path bm remote
  if [ "$YES" -eq 1 ]; then
    vid="$default_id"
    label="$default_label"
    path="$default_path"
    bm="$default_bm"
    remote="$REMOTE_URL"
  else
    printf '  Display label [%s]: ' "$default_label"
    read -r label || label=""
    label="${label:-$default_label}"

    printf '  Vault id (used in commands like `thinkos vault use <id>`) [%s]: ' "$default_id"
    read -r vid || vid=""
    vid="${vid:-$default_id}"
    if ! valid_id "$vid"; then
      err "create-project: invalid id '$vid'. Use lowercase letters, digits, hyphens only ([a-z0-9-]+)."
      return 2
    fi

    printf '  Vault path [%s]: ' "$default_path"
    read -r path || path=""
    path="${path:-$default_path}"
    # Expand ~
    case "$path" in
      "~"|"~/"*) path="$HOME${path#~}" ;;
    esac

    printf '  Basic Memory project name [%s]: ' "$default_bm"
    read -r bm || bm=""
    bm="${bm:-$default_bm}"

    if [ -n "$REMOTE_URL" ]; then
      remote="$REMOTE_URL"
      log "  Git remote (from --remote): $remote"
    else
      printf '  Git remote URL (optional, ENTER to skip): '
      read -r remote || remote=""
    fi
  fi

  # Reject if the chosen id is already taken
  if [ -f "$REGISTRY" ]; then
    local exists
    exists="$(_registry_py exists-id "$vid")"
    if [ "$exists" = "yes" ]; then
      err "create-project: a vault with id '$vid' is already registered."
      err "Pick a different id, or run: scripts/thinkos-vault.sh remove $vid --yes"
      return 1
    fi
  fi

  # Path conflict check
  if [ -e "$path" ] && [ "$(ls -A "$path" 2>/dev/null)" ]; then
    err "create-project: destination path exists and is non-empty: $path"
    err "Pick a different path, or remove the existing one first."
    return 1
  fi

  # Template availability
  if [ ! -d "$TEMPLATE_TEAM_DIR" ]; then
    err "create-project: project-vault templates not found at:"
    err "  $TEMPLATE_TEAM_DIR"
    err "This Think OS install is missing templates/team/. Re-export or update."
    return 1
  fi

  # Git checks — always for init; auth only if remote given
  log ""
  log "Checking git install + identity..."
  if ! bash "$SCRIPT_DIR/thinkos-git.sh" check-or-install; then
    return 1
  fi
  if [ -n "$remote" ]; then
    log ""
    log "Checking GitHub auth (remote provided)..."
    if ! bash "$SCRIPT_DIR/thinkos-git.sh" check-auth; then
      return 1
    fi
  fi

  # Create + copy templates
  log ""
  log "Creating vault directory: $path"
  mkdir -p "$path"
  log "Copying templates from $TEMPLATE_TEAM_DIR ..."
  # Copy contents including dotfiles. Use a portable approach.
  (cd "$TEMPLATE_TEAM_DIR" && tar cf - .) | (cd "$path" && tar xf -) || {
    err "Template copy failed."
    return 1
  }

  # Substitute all tokens in every copied template file recursively.
  # Tokens: {{PROJECT_NAME}}, {{PROJECT_LABEL}}, {{BM_PROJECT_NAME}}, {{UID}},
  #         {{CREATED_AT}}, {{TEAM_LEAD}}, {{TEAM_LEAD_NAME}}, {{TZ}}, {{EXPORT_REPO_URL}}
  log "Substituting template tokens..."
  local created_at_val
  created_at_val="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  local uid_val
  uid_val="$(python3 -c 'import uuid; print(str(uuid.uuid4()))')"
  VAULT_COPY_PATH="$path" \
  VAULT_ID_ENV="$vid" \
  VAULT_LABEL_ENV="$label" \
  VAULT_BM_ENV="$bm" \
  VAULT_CREATED_AT="$created_at_val" \
  VAULT_UID="$uid_val" \
  python3 - <<'PYEOF'
import os, sys
from pathlib import Path

vault_path  = os.environ["VAULT_COPY_PATH"]
project_name  = os.environ["VAULT_ID_ENV"]
project_label = os.environ["VAULT_LABEL_ENV"]
bm_project    = os.environ["VAULT_BM_ENV"]
created_at    = os.environ["VAULT_CREATED_AT"]
uid           = os.environ["VAULT_UID"]

# TEAM_LEAD, TEAM_LEAD_NAME, TZ, EXPORT_REPO_URL: use empty/defaults if not set
team_lead      = os.environ.get("VAULT_TEAM_LEAD", "")
team_lead_name = os.environ.get("VAULT_TEAM_LEAD_NAME", "")
tz             = os.environ.get("VAULT_TZ", "UTC")
export_repo_url = os.environ.get("VAULT_EXPORT_REPO_URL", "")

TOKEN_MAP = {
    "{{PROJECT_NAME}}":  project_name,
    "{{PROJECT_LABEL}}": project_label,
    "{{BM_PROJECT_NAME}}": bm_project,
    "{{UID}}":           uid,
    "{{CREATED_AT}}":    created_at,
    "{{TEAM_LEAD}}":     team_lead,
    "{{TEAM_LEAD_NAME}}": team_lead_name,
    "{{TZ}}":            tz,
    "{{EXPORT_REPO_URL}}": export_repo_url,
}

TEXT_EXTS = {".md", ".json", ".yaml", ".yml", ".txt", ".toml", ".cfg",
             ".ini", ".sh", ".template", ""}  # "" = no extension

for p in Path(vault_path).rglob("*"):
    if not p.is_file():
        continue
    if p.suffix not in TEXT_EXTS:
        continue
    try:
        content = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    new_content = content
    for token, value in TOKEN_MAP.items():
        new_content = new_content.replace(token, value)
    if new_content != content:
        p.write_text(new_content, encoding="utf-8")

# Rename CODEOWNERS.template → CODEOWNERS in the live vault (if present)
codeowners_tpl = Path(vault_path) / "CODEOWNERS.template"
if codeowners_tpl.exists():
    codeowners_tpl.rename(Path(vault_path) / "CODEOWNERS")
PYEOF

  # Stamp .thinkos/vault.json with this vault's metadata
  mkdir -p "$path/.thinkos"
  VAULT_PATH="$path" \
  VAULT_ID="$vid" \
  VAULT_LABEL="$label" \
  VAULT_BM="$bm" \
  python3 - <<'PYEOF'
import os, json, datetime, tempfile
p = os.path.join(os.environ["VAULT_PATH"], ".thinkos", "vault.json")
existing = {}
if os.path.exists(p):
    try:
        with open(p) as fh:
            existing = json.load(fh)
    except Exception:
        existing = {}
existing.update({
    "version": 1,
    "type": "project",
    "id": os.environ["VAULT_ID"],
    "label": os.environ["VAULT_LABEL"],
    "bm_project": os.environ["VAULT_BM"],
    "created_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
})
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p), prefix=".vault-", suffix=".tmp")
try:
    with os.fdopen(fd, "w") as fh:
        json.dump(existing, fh, indent=2, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, p)
    os.chmod(p, 0o600)
except Exception:
    os.unlink(tmp)
    raise
PYEOF

  # git init / first commit
  log ""
  log "Initializing git repo..."
  ( cd "$path" && git init -b main >/dev/null 2>&1 || git init >/dev/null )
  ( cd "$path" && git add . && git commit -m "Initial commit (Think OS project vault)" >/dev/null )

  if [ -n "$remote" ]; then
    log "Setting remote origin: $remote"
    ( cd "$path" && git remote add origin "$remote" )
    log "Pushing initial commit..."
    if ! ( cd "$path" && git push -u origin main ); then
      err "git push failed. The vault is created locally; fix the remote and push manually:"
      err "  cd $path && git push -u origin main"
    fi
  fi

  # Register in the vault registry
  log ""
  log "Registering vault in $REGISTRY ..."
  local entry
  entry="$(VAULT_ID="$vid" VAULT_LABEL="$label" VAULT_PATH_ENV="$path" \
           VAULT_BM="$bm" VAULT_REMOTE="$remote" python3 - <<'PYEOF'
import os, json
entry = {
    "id": os.environ["VAULT_ID"],
    "type": "project",
    "label": os.environ["VAULT_LABEL"],
    "path": os.environ["VAULT_PATH_ENV"],
    "bm_project": os.environ["VAULT_BM"],
}
remote = os.environ.get("VAULT_REMOTE", "")
if remote:
    entry["git_remote"] = remote
print(json.dumps(entry))
PYEOF
)"
  _registry_py add "$entry"

  # Basic Memory project + reindex
  if command -v basic-memory >/dev/null 2>&1; then
    log "Registering Basic Memory project '$bm'..."
    if basic-memory project ls --name "$bm" >/dev/null 2>&1; then
      log "Basic Memory project '$bm' already exists; skipping add."
    else
      basic-memory project add "$bm" "$path" --local || {
        err "basic-memory project add failed. You can run it manually later."
      }
    fi
    log "Reindexing Basic Memory project '$bm'..."
    basic-memory reindex --project "$bm" || {
      err "basic-memory reindex failed. You can run it manually later."
    }
  else
    log "basic-memory not found on PATH; skipping project add + reindex."
    log "Install with: uv tool install basic-memory"
    log "Then run:    basic-memory project add $bm $path --local && basic-memory reindex --project $bm"
  fi

  log ""
  log "Project vault '$vid' created."
  log "  Path:        $path"
  log "  Label:       $label"
  log "  BM project:  $bm"
  if [ -n "$remote" ]; then
    log "  Git remote:  $remote"
    log ""
    log "Invite teammates with:"
    log "  scripts/thinkos-vault.sh clone $remote"
  fi
}

# -----------------------------------------------------------------------------
# `clone <git-url>` — clone, verify, register
# -----------------------------------------------------------------------------
cmd_clone() {
  local url="$1"
  if [ -z "$url" ]; then
    err "clone: missing <git-url>"
    return 2
  fi

  mkdir -p "$THINKOS_DIR"

  # Derive a sensible default directory name from the URL
  local derived
  derived="$(printf '%s' "$url" | sed -E 's|.*[/:]([^/]+)\.git$|\1|; s|.*[/:]([^/]+)$|\1|')"
  [ -z "$derived" ] && derived="cloned-vault"
  local default_path="$HOME/ThinkOS/projects/$derived"

  local path
  if [ "$YES" -eq 1 ]; then
    path="$default_path"
  else
    printf '  Local path for the clone [%s]: ' "$default_path"
    read -r path || path=""
    path="${path:-$default_path}"
    case "$path" in
      "~"|"~/"*) path="$HOME${path#~}" ;;
    esac
  fi

  if [ -e "$path" ] && [ "$(ls -A "$path" 2>/dev/null)" ]; then
    err "clone: destination path exists and is non-empty: $path"
    return 1
  fi

  # Git checks
  log ""
  log "Checking git install + auth..."
  if ! bash "$SCRIPT_DIR/thinkos-git.sh" check-or-install; then
    return 1
  fi
  if ! bash "$SCRIPT_DIR/thinkos-git.sh" check-auth; then
    return 1
  fi

  log ""
  log "Cloning $url → $path ..."
  git clone "$url" "$path" || {
    err "git clone failed."
    return 1
  }

  # Verify it's a Think OS project vault
  local vault_json="$path/.thinkos/vault.json"
  local vtype="" vid="" label="" bm=""
  if [ -f "$vault_json" ]; then
    local meta
    meta="$(_registry_py read-vault-json "$vault_json" 2>/dev/null || true)"
    if [ -n "$meta" ]; then
      vtype="$(printf '%s' "$meta" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("type",""))')"
      vid="$(printf '%s' "$meta"   | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("id",""))')"
      label="$(printf '%s' "$meta" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("label",""))')"
      bm="$(printf '%s' "$meta"    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("bm_project",""))')"
    fi
  fi

  if [ -z "$vtype" ] || [ "$vtype" != "project" ]; then
    log ""
    log "This clone does not look like a Think OS project vault."
    log "  (no .thinkos/vault.json with type=project)"
    log ""
    local ans
    if [ "$YES" -eq 1 ]; then
      ans="y"
    else
      printf '  Register it as a read-only reference vault instead? [Y/n]: '
      read -r ans || ans=""
    fi
    if [ -z "$ans" ] || [ "${ans#[Yy]}" != "$ans" ]; then
      # Use the derived name as id (must be valid). Otherwise prompt.
      local ref_id="$derived"
      if ! valid_id "$ref_id"; then
        printf '  Reference vault id [a-z0-9-]+: '
        read -r ref_id || ref_id=""
      fi
      _add_reference_entry "$ref_id" "$path" "${label:-$derived}" "${bm:-$ref_id}"
      log "Registered as reference vault: $ref_id"
      return 0
    else
      log "Aborted. The clone is on disk at $path but not registered."
      return 1
    fi
  fi

  # Choose id: prefer the one from vault.json, fall back to derived
  local final_id="${vid:-$derived}"
  if ! valid_id "$final_id"; then
    err "Vault id from .thinkos/vault.json is invalid: '$final_id'"
    return 1
  fi
  # Avoid id collisions
  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-id "$final_id")" = "yes" ]; then
    err "A vault with id '$final_id' is already registered."
    err "Remove it first or rename in the cloned .thinkos/vault.json:"
    err "  scripts/thinkos-vault.sh remove $final_id --yes"
    return 1
  fi

  local final_label="${label:-$final_id}"
  local final_bm="${bm:-$final_id-os}"

  log ""
  log "Registering project vault in $REGISTRY ..."
  local entry
  entry="$(VAULT_ID="$final_id" VAULT_LABEL="$final_label" \
           VAULT_PATH_ENV="$path" VAULT_BM="$final_bm" \
           VAULT_REMOTE="$url" python3 - <<'PYEOF'
import os, json
entry = {
    "id": os.environ["VAULT_ID"],
    "type": "project",
    "label": os.environ["VAULT_LABEL"],
    "path": os.environ["VAULT_PATH_ENV"],
    "bm_project": os.environ["VAULT_BM"],
    "git_remote": os.environ["VAULT_REMOTE"],
}
print(json.dumps(entry))
PYEOF
)"
  _registry_py add "$entry"

  # BM register + reindex
  if command -v basic-memory >/dev/null 2>&1; then
    log "Registering Basic Memory project '$final_bm'..."
    if basic-memory project ls --name "$final_bm" >/dev/null 2>&1; then
      log "Basic Memory project '$final_bm' already exists; skipping add."
    else
      basic-memory project add "$final_bm" "$path" --local || {
        err "basic-memory project add failed. You can run it manually later."
      }
    fi
    log "Reindexing Basic Memory project '$final_bm'..."
    basic-memory reindex --project "$final_bm" || {
      err "basic-memory reindex failed. You can run it manually later."
    }
  else
    log "basic-memory not found on PATH; skipping project add + reindex."
  fi

  log ""
  log "Cloned and registered: $final_id ($final_label)"
  log "  Path:        $path"
  log "  BM project:  $final_bm"
}

# -----------------------------------------------------------------------------
# `add-reference <path>` — register an existing folder as read-only reference
# -----------------------------------------------------------------------------
_add_reference_entry() {
  local ref_id="$1" ref_path="$2" ref_label="$3" ref_bm="$4"
  local entry
  entry="$(VAULT_ID="$ref_id" VAULT_LABEL="$ref_label" \
           VAULT_PATH_ENV="$ref_path" VAULT_BM="$ref_bm" \
           python3 - <<'PYEOF'
import os, json
entry = {
    "id": os.environ["VAULT_ID"],
    "type": "reference",
    "label": os.environ["VAULT_LABEL"],
    "path": os.environ["VAULT_PATH_ENV"],
    "bm_project": os.environ["VAULT_BM"],
    "read_only": True,
}
print(json.dumps(entry))
PYEOF
)"
  _registry_py add "$entry"
}

cmd_add_reference() {
  local path="$1"
  if [ -z "$path" ]; then
    err "add-reference: missing <path>"
    return 2
  fi
  case "$path" in
    "~"|"~/"*) path="$HOME${path#~}" ;;
  esac
  if [ ! -d "$path" ]; then
    err "add-reference: not a directory: $path"
    return 1
  fi
  # Absolute path
  path="$(cd "$path" && pwd)"

  mkdir -p "$THINKOS_DIR"

  # Derive id from basename, sanitized
  local base
  base="$(basename "$path" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
  [ -z "$base" ] && base="reference"
  local default_id="$base"
  local default_label
  default_label="$(basename "$path")"
  local default_bm="$base"

  local ref_id label bm
  if [ "$YES" -eq 1 ]; then
    ref_id="$default_id"
    label="$default_label"
    bm="$default_bm"
  else
    printf '  Reference vault id [%s]: ' "$default_id"
    read -r ref_id || ref_id=""
    ref_id="${ref_id:-$default_id}"
    if ! valid_id "$ref_id"; then
      err "add-reference: invalid id '$ref_id' (need [a-z0-9-]+)."
      return 2
    fi

    printf '  Display label [%s]: ' "$default_label"
    read -r label || label=""
    label="${label:-$default_label}"

    printf '  Basic Memory project name [%s]: ' "$default_bm"
    read -r bm || bm=""
    bm="${bm:-$default_bm}"
  fi

  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-id "$ref_id")" = "yes" ]; then
    err "add-reference: id '$ref_id' is already registered."
    return 1
  fi

  _add_reference_entry "$ref_id" "$path" "$label" "$bm"
  log "Registered reference vault: $ref_id"
  log "  Path:   $path"
  log "  Label:  $label"
  log "  BM:     $bm"
  log ""
  log "Note: reference vaults are intent-only read-only — Think OS will not"
  log "write to this path, but nothing on the filesystem enforces it."
}

# -----------------------------------------------------------------------------
# `remove <id>` — deregister; requires --yes
# -----------------------------------------------------------------------------
cmd_remove() {
  local vid="$1"
  if [ -z "$vid" ]; then
    err "remove: missing <id>"
    return 2
  fi
  if [ "$YES" -ne 1 ]; then
    err "remove: refusing to deregister '$vid' without --yes."
    err ""
    err "This will remove the vault from $REGISTRY."
    err "It will NOT delete any files on disk — only the registry entry."
    err ""
    err "If you're sure, re-run with --yes:"
    err "  scripts/thinkos-vault.sh remove $vid --yes"
    return 2
  fi

  if [ ! -f "$REGISTRY" ]; then
    err "remove: no registry exists at $REGISTRY."
    return 1
  fi
  if [ "$(_registry_py exists-id "$vid")" != "yes" ]; then
    err "remove: no such vault id: $vid"
    return 1
  fi

  local path
  path="$(_registry_py field "$vid" path 2>/dev/null)"

  _registry_py remove "$vid"

  # Clear the sticky active-vault override if it pointed here
  if [ -f "$ACTIVE_FILE" ]; then
    local cur
    cur="$(cat "$ACTIVE_FILE" 2>/dev/null | head -1 | tr -d '[:space:]')"
    if [ "$cur" = "$vid" ]; then
      rm -f "$ACTIVE_FILE"
      log "Cleared active-vault override (was pointing at $vid)."
    fi
  fi

  log "Deregistered: $vid"
  if [ -n "$path" ]; then
    log "Files remain on disk at: $path"
    log "Delete them manually if you no longer need them."
  fi
}

# -----------------------------------------------------------------------------
# `rename <old-id>` — change a vault's id and/or label
# -----------------------------------------------------------------------------
cmd_rename() {
  local old_id="$1"
  if [ -z "$old_id" ]; then
    err "rename: missing <old-id>"
    rename_usage >&2
    return 2
  fi

  if [ ! -f "$REGISTRY" ]; then
    err "rename: no registry exists at $REGISTRY."
    return 1
  fi

  if [ "$(_registry_py exists-id "$old_id")" != "yes" ]; then
    err "rename: no such vault id: $old_id"
    err ""
    err "Registered vault ids:"
    local ids
    ids="$(_registry_py ids 2>/dev/null)"
    if [ -n "$ids" ]; then
      printf '%s\n' "$ids" | sed 's/^/  /' >&2
    fi
    return 1
  fi

  # At least one of --id or --label must be set
  if [ -z "$NEW_ID" ] && [ "$LABEL_SET" -ne 1 ]; then
    err "rename: nothing to do. Provide --id <new-id> and/or --label \"<text>\"."
    rename_usage >&2
    return 2
  fi

  # Validate new id if provided
  if [ -n "$NEW_ID" ]; then
    if ! valid_id "$NEW_ID"; then
      err "rename: invalid --id '$NEW_ID'. Use lowercase letters, digits, hyphens only ([a-z0-9-]+)."
      return 2
    fi
    if [ "$NEW_ID" != "$old_id" ] && [ "$(_registry_py exists-id "$NEW_ID")" = "yes" ]; then
      err "rename: id '$NEW_ID' is already registered."
      return 1
    fi
  fi

  # Build a description of the change for confirmation + final summary
  local old_label
  old_label="$(_registry_py field "$old_id" label 2>/dev/null || true)"

  local effective_new_id="${NEW_ID:-$old_id}"
  local effective_new_label
  if [ "$LABEL_SET" -eq 1 ]; then
    effective_new_label="$NEW_LABEL"
  else
    effective_new_label="$old_label"
  fi

  # Confirmation prompt (skip with --yes)
  if [ "$YES" -ne 1 ]; then
    log ""
    log "Proposed rename:"
    if [ "$effective_new_id" != "$old_id" ]; then
      log "  id:    $old_id → $effective_new_id"
    else
      log "  id:    $old_id (unchanged)"
    fi
    if [ "$LABEL_SET" -eq 1 ]; then
      log "  label: '${old_label}' → '${effective_new_label}'"
    else
      log "  label: '${old_label}' (unchanged)"
    fi
    log ""
    local ans
    printf '  Proceed? [y/N]: '
    read -r ans || ans=""
    case "$ans" in
      [Yy]*) ;;
      *) log "Aborted."; return 1 ;;
    esac
  fi

  # Build the JSON patch
  local patch
  patch="$(NEW_ID_ENV="$effective_new_id" \
           NEW_LABEL_ENV="$effective_new_label" \
           SET_ID="$([ -n "$NEW_ID" ] && echo 1 || echo 0)" \
           SET_LABEL="$LABEL_SET" \
           python3 - <<'PYEOF'
import os, json
patch = {}
if os.environ.get("SET_ID") == "1":
    patch["id"] = os.environ["NEW_ID_ENV"]
if os.environ.get("SET_LABEL") == "1":
    patch["label"] = os.environ["NEW_LABEL_ENV"]
print(json.dumps(patch))
PYEOF
)"

  _registry_py update "$old_id" "$patch" || {
    err "rename: registry update failed."
    return 1
  }

  # Update active-vault pointer if it matched the old id
  if [ -f "$ACTIVE_FILE" ] && [ -n "$NEW_ID" ] && [ "$NEW_ID" != "$old_id" ]; then
    local cur
    cur="$(cat "$ACTIVE_FILE" 2>/dev/null | head -1 | tr -d '[:space:]')"
    if [ "$cur" = "$old_id" ]; then
      printf '%s\n' "$NEW_ID" > "$ACTIVE_FILE"
      log "Updated active-vault pointer: $old_id → $NEW_ID"
    fi
  fi

  # Summary
  log ""
  if [ -n "$NEW_ID" ] && [ "$NEW_ID" != "$old_id" ] && [ "$LABEL_SET" -eq 1 ]; then
    log "Renamed: $old_id → $effective_new_id; label: '$old_label' → '$effective_new_label'"
  elif [ -n "$NEW_ID" ] && [ "$NEW_ID" != "$old_id" ]; then
    log "Renamed: $old_id → $effective_new_id"
  elif [ "$LABEL_SET" -eq 1 ]; then
    log "Renamed label on '$old_id': '$old_label' → '$effective_new_label'"
  else
    log "No effective change."
  fi
  log ""
  log "Note: path and bm_project were not touched."
}

# -----------------------------------------------------------------------------
# `migrate` — auto-register an existing v0 single-vault setup as 'personal'
# Accepts:  --path PATH   explicit vault path (skip auto-detection)
# Auto-detect order:
#   1. $THINKOS_HOME env var
#   2. ~/ThinkOS/vault (legacy default)
#   3. basic-memory project list --json (finds project whose path has Think OS markers)
# -----------------------------------------------------------------------------

# _bm_detect_vault: probe basic-memory for a Think OS vault path.
# Prints two lines: <bm-project-name>\n<vault-path>  on success, nothing on failure.
_bm_detect_vault() {
  # Requires basic-memory on PATH
  command -v basic-memory >/dev/null 2>&1 || return 1

  local bm_json
  bm_json="$(basic-memory project list --json 2>/dev/null)" || return 1
  [ -z "$bm_json" ] && return 1

  # Use Python to parse JSON and probe for marker files.
  # Pass JSON via env var to avoid heredoc/pipe stdin conflict.
  # Marker files (cheap, non-recursive):
  #   <root>/Identity.md
  #   <root>/identity.md
  #   <root>/current-focus.md
  #   <root>/05 Profile/Identity.md
  #   <root>/01 Now/Current Focus.md
  # Preference order: name contains "claude-os" or "think-os" first,
  #   then path contains "Think" or "Claude OS" or "ThinkOS",
  #   then first match found.
  BM_JSON="$bm_json" python3 - <<'PYEOF'
import json, os, sys

raw = os.environ.get("BM_JSON", "").strip()
try:
    data = json.loads(raw)
except Exception:
    sys.exit(1)

projects = data.get("projects", [])
if not projects:
    sys.exit(1)

MARKERS = [
    "Identity.md",
    "identity.md",
    "current-focus.md",
    os.path.join("05 Profile", "Identity.md"),
    os.path.join("01 Now", "Current Focus.md"),
]

def expand(p):
    if p.startswith("~/"):
        return os.path.join(os.path.expanduser("~"), p[2:])
    return os.path.expanduser(p)

def has_marker(path):
    root = expand(path)
    for m in MARKERS:
        if os.path.isfile(os.path.join(root, m)):
            return True
    return False

candidates = [(p["name"], p["local_path"]) for p in projects
              if p.get("local_path") and has_marker(p["local_path"])]

if not candidates:
    sys.exit(1)

def score(item):
    name, path = item
    n = name.lower()
    p = path.lower()
    # Prefer names/paths that look most like a Think OS personal vault
    s = 0
    if "claude-os" in n or "think-os" in n:
        s += 10
    if "think" in p or "claude os" in p or "thinkos" in p:
        s += 5
    return s

candidates.sort(key=score, reverse=True)
best_name, best_path = candidates[0]
# Print name and expanded path, one per line
print(best_name)
print(expand(best_path))
if len(candidates) > 1:
    others = ", ".join(n for n, _ in candidates[1:])
    print("WARN: multiple candidates: " + others, file=sys.stderr)
PYEOF
}

cmd_track() {
  local raw="$1"
  if [ -z "$raw" ]; then
    err "track: missing <path>"
    err "Usage: scripts/thinkos-vault.sh track <path>"
    return 2
  fi
  case "$raw" in
    "~"|"~/"*) raw="$HOME${raw#~}" ;;
  esac
  if [ ! -d "$raw" ]; then
    err "track: '$raw' does not exist or is not a directory."
    return 1
  fi
  local abs
  abs="$(cd "$raw" && pwd)"
  if [ ! -f "$REGISTRY" ]; then
    err "track: no registry at $REGISTRY. Run scripts/thinkos-vault.sh migrate first."
    return 1
  fi
  python3 - "$REGISTRY" "$abs" <<'PYEOF'
import datetime, json, os, sys, tempfile
reg, path = sys.argv[1], sys.argv[2]
d = json.load(open(reg))
tps = d.setdefault("tracked_projects", [])
if any(isinstance(t, dict) and t.get("path") == path for t in tps):
    print("track: already tracking " + path)
    sys.exit(0)
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
tps.append({"path": path, "added_at": now})
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(reg))
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
os.replace(tmp, reg)
print("track: now tracking " + path + " — Claude sessions under it will be captured")
PYEOF
}

cmd_untrack() {
  local raw="$1"
  if [ -z "$raw" ]; then
    err "untrack: missing <path>"
    err "Usage: scripts/thinkos-vault.sh untrack <path>"
    return 2
  fi
  case "$raw" in
    "~"|"~/"*) raw="$HOME${raw#~}" ;;
  esac
  if [ ! -f "$REGISTRY" ]; then
    err "untrack: no registry at $REGISTRY."
    return 1
  fi
  python3 - "$REGISTRY" "$raw" <<'PYEOF'
import json, os, sys, tempfile
reg, path = sys.argv[1], sys.argv[2]
path = os.path.realpath(os.path.expanduser(path))
d = json.load(open(reg))
tps = d.get("tracked_projects", [])
kept = [t for t in tps if not (isinstance(t, dict) and os.path.realpath(os.path.expanduser(t.get("path", ""))) == path)]
if len(kept) == len(tps):
    print("untrack: " + path + " was not tracked")
    sys.exit(0)
d["tracked_projects"] = kept
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(reg))
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
os.replace(tmp, reg)
print("untrack: stopped tracking " + path)
PYEOF
}

cmd_migrate() {
  mkdir -p "$THINKOS_DIR"

  # Resolve the id to register under (default: personal)
  local target_id="${NEW_ID:-personal}"
  if ! valid_id "$target_id"; then
    err "migrate: invalid --id '$target_id'. Use lowercase letters, digits, hyphens only ([a-z0-9-]+)."
    return 2
  fi

  # Idempotency: if the chosen id is already registered, skip early
  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-id "$target_id")" = "yes" ]; then
    log "migrate: '$target_id' is already registered. Nothing to do."
    return 0
  fi

  local v0=""
  local bm=""
  local detect_source=""

  # --- (0) Explicit --path override ---
  if [ -n "${MIGRATE_PATH:-}" ]; then
    case "$MIGRATE_PATH" in
      "~"|"~/"*) MIGRATE_PATH="$HOME${MIGRATE_PATH#~}" ;;
    esac
    if [ ! -d "$MIGRATE_PATH" ]; then
      err "migrate: --path '$MIGRATE_PATH' does not exist or is not a directory."
      return 1
    fi
    v0="$(cd "$MIGRATE_PATH" && pwd)"
    detect_source="--path flag"

  # --- (1) $THINKOS_HOME env var ---
  elif [ -n "${THINKOS_HOME:-}" ] && [ -d "$THINKOS_HOME" ]; then
    v0="$(cd "$THINKOS_HOME" && pwd)"
    detect_source="\$THINKOS_HOME"

  # --- (2) Legacy default path ---
  elif [ -d "$HOME/ThinkOS/vault" ]; then
    v0="$(cd "$HOME/ThinkOS/vault" && pwd)"
    detect_source="~/ThinkOS/vault"

  # --- (3) basic-memory project list ---
  else
    local bm_out
    local bm_warn_tmp
    bm_warn_tmp="$(mktemp)"
    bm_out="$(_bm_detect_vault 2>"$bm_warn_tmp")" || true
    if [ -n "$bm_out" ]; then
      bm="$(printf '%s\n' "$bm_out" | sed -n '1p')"
      v0="$(printf '%s\n' "$bm_out" | sed -n '2p')"
      detect_source="basic-memory project '$bm'"
      # Surface any multi-candidate warning
      local warn_msg
      warn_msg="$(cat "$bm_warn_tmp" 2>/dev/null || true)"
      if [ -n "$warn_msg" ]; then
        log "migrate: $warn_msg"
        log "  Using: $bm ($v0)"
      fi
    fi
    rm -f "$bm_warn_tmp"
  fi

  # --- Nothing found ---
  if [ -z "$v0" ]; then
    err "migrate: no vault found."
    err "  Checked: \$THINKOS_HOME, ~/ThinkOS/vault, and basic-memory project list."
    err ""
    err "  To fix, either:"
    err "    export THINKOS_HOME=/path/to/your/vault"
    err "    scripts/thinkos-vault.sh migrate --path /path/to/your/vault"
    return 1
  fi

  # Idempotency: if some vault already points at this path, skip
  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-path "$v0")" = "yes" ]; then
    log "migrate: a vault already points at $v0. Nothing to do."
    return 0
  fi

  # Derive label: --label wins; else "<git user.name>'s Think OS";
  # fall back to current OS username if git unconfigured.
  local label="$NEW_LABEL"
  if [ -z "$label" ]; then
    local owner
    owner="$(git config user.name 2>/dev/null || true)"
    if [ -z "$owner" ]; then
      owner="$(id -un 2>/dev/null || whoami 2>/dev/null || echo user)"
    fi
    label="${owner}'s Think OS"
  fi

  # Derive BM project name: use the one detected from basic-memory, or derive
  # from the directory name (sanitized), or fall back to "think-os"
  if [ -z "$bm" ]; then
    local dir_name
    dir_name="$(basename "$v0")"
    bm="$(printf '%s' "$dir_name" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
    [ -z "$bm" ] && bm="think-os"
  fi

  log "Migrating v0 vault → multi-vault registry"
  log "  Detected via:       $detect_source"
  log "  Path:               $v0"
  log "  Registering as id:  $target_id"
  log "  Label:              $label"
  log "  BM project:         $bm"

  local entry
  entry="$(VAULT_ID="$target_id" VAULT_LABEL="$label" VAULT_PATH_ENV="$v0" VAULT_BM="$bm" python3 - <<'PYEOF'
import os, json
entry = {
    "id": os.environ["VAULT_ID"],
    "type": "personal",
    "label": os.environ["VAULT_LABEL"],
    "path": os.environ["VAULT_PATH_ENV"],
    "bm_project": os.environ["VAULT_BM"],
    "default": True,
}
print(json.dumps(entry))
PYEOF
)"
  _registry_py add "$entry"

  log ""
  log "Registered your existing vault as '$target_id'. Ready to add project vaults."
  log "Next:"
  log "  scripts/thinkos-vault.sh list"
  log "  scripts/thinkos-vault.sh create-project <name>"
  log "  scripts/thinkos-vault.sh clone <git-url>"
}

# -----------------------------------------------------------------------------
# Arg parsing
# -----------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  usage
  exit 0
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
esac

SUB="$1"
shift

# Pick the right help text for -h/--help based on the current subcommand.
sub_help() {
  case "$SUB" in
    rename)  rename_usage ;;
    migrate) migrate_usage ;;
    *)       usage ;;
  esac
}

# Collect positional + recognized flags. Subcommand-specific positional args
# are passed through in order.
POS=""
NPOS=0
P1=""
P2=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes)
      YES=1
      shift
      ;;
    --remote)
      REMOTE_URL="${2:-}"
      if [ -z "$REMOTE_URL" ]; then
        err "--remote requires a URL"
        exit 2
      fi
      shift 2
      ;;
    --path)
      MIGRATE_PATH="${2:-}"
      if [ -z "$MIGRATE_PATH" ]; then
        err "--path requires a PATH argument"
        exit 2
      fi
      shift 2
      ;;
    --id)
      NEW_ID="${2:-}"
      if [ -z "$NEW_ID" ]; then
        err "--id requires a value"
        exit 2
      fi
      shift 2
      ;;
    --label)
      # Allow empty string explicitly; require the arg to be present.
      if [ $# -lt 2 ]; then
        err "--label requires a value"
        exit 2
      fi
      NEW_LABEL="$2"
      LABEL_SET=1
      shift 2
      ;;
    -h|--help)
      sub_help
      exit 0
      ;;
    --*)
      err "Unknown flag: $1"
      sub_help >&2
      exit 2
      ;;
    *)
      NPOS=$((NPOS + 1))
      if [ $NPOS -eq 1 ]; then
        P1="$1"
      elif [ $NPOS -eq 2 ]; then
        P2="$1"
      else
        err "Unexpected extra argument: $1"
        exit 2
      fi
      shift
      ;;
  esac
done

case "$SUB" in
  list)            cmd_list ;;
  use)             cmd_use "$P1" ;;
  create-project)  cmd_create_project "$P1" ;;
  clone)           cmd_clone "$P1" ;;
  add-reference)   cmd_add_reference "$P1" ;;
  remove)          cmd_remove "$P1" ;;
  rename)          cmd_rename "$P1" ;;
  track)           cmd_track "$P1" ;;
  untrack)         cmd_untrack "$P1" ;;
  migrate)         cmd_migrate ;;
  *)
    err "Unknown subcommand: $SUB"
    usage >&2
    exit 2
    ;;
esac
