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
#   migrate                       One-time v0-to-v1 migration
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
  migrate                       One-time migration: auto-register an
                                existing v0 single-vault setup as the
                                personal hub. Idempotent.
  -h, --help                    Show this help.

Storage:
  Registry:     ~/.thinkos/vaults.json
  Active vault: ~/.thinkos/active-vault
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

  printf '%-20s  %-10s  %-8s  %-22s  %s\n' "ID" "TYPE" "DEFAULT" "BM PROJECT" "PATH"
  printf '%-20s  %-10s  %-8s  %-22s  %s\n' "--" "----" "-------" "----------" "----"
  printf '%s\n' "$rows" | while IFS=$'\t' read -r id type def bm path; do
    local marker=" "
    if [ "$id" = "$active_id" ]; then
      marker="*"
    fi
    printf '%s%-19s  %-10s  %-8s  %-22s  %s\n' "$marker" "$id" "$type" "$def" "$bm" "$path"
  done

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

  # Reject if id already taken
  if [ -f "$REGISTRY" ]; then
    local exists
    exists="$(_registry_py exists-id "$name")"
    if [ "$exists" = "yes" ]; then
      err "create-project: a vault with id '$name' is already registered."
      err "Pick a different name, or run: scripts/thinkos-vault.sh remove $name --yes"
      return 1
    fi
  fi

  # Defaults
  local default_label
  default_label="$(printf '%s' "$name" | tr '-' ' ') Team OS"
  local default_path="$HOME/ThinkOS/projects/$name"
  local default_bm="$name-os"

  # Prompts
  log ""
  log "Creating project vault '$name'."
  log ""
  local label path bm remote
  if [ "$YES" -eq 1 ]; then
    label="$default_label"
    path="$default_path"
    bm="$default_bm"
    remote="$REMOTE_URL"
  else
    printf '  Display label [%s]: ' "$default_label"
    read -r label || label=""
    label="${label:-$default_label}"

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

  # Stamp .thinkos/vault.json with this vault's metadata
  mkdir -p "$path/.thinkos"
  VAULT_PATH="$path" \
  VAULT_ID="$name" \
  VAULT_LABEL="$label" \
  VAULT_BM="$bm" \
  python3 - <<'PYEOF'
import os, json, datetime
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
with open(p, "w") as fh:
    json.dump(existing, fh, indent=2, sort_keys=False)
    fh.write("\n")
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
  entry="$(VAULT_ID="$name" VAULT_LABEL="$label" VAULT_PATH_ENV="$path" \
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
  log "Project vault '$name' created."
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
# `migrate` — auto-register an existing v0 single-vault setup as 'personal'
# -----------------------------------------------------------------------------
cmd_migrate() {
  mkdir -p "$THINKOS_DIR"

  # Locate the v0 vault
  local v0=""
  if [ -n "${THINKOS_HOME:-}" ] && [ -d "$THINKOS_HOME" ]; then
    v0="$THINKOS_HOME"
  elif [ -d "$HOME/ThinkOS/vault" ]; then
    v0="$HOME/ThinkOS/vault"
  fi

  if [ -z "$v0" ]; then
    log "migrate: no v0 vault found."
    log "  Checked: \$THINKOS_HOME (env) and ~/ThinkOS/vault."
    log "  Nothing to do."
    return 0
  fi

  # Idempotency: if a 'personal' id is already registered, skip
  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-id personal)" = "yes" ]; then
    log "migrate: 'personal' is already registered. Nothing to do."
    return 0
  fi

  # Idempotency: if some vault already points at this path, skip
  if [ -f "$REGISTRY" ] && [ "$(_registry_py exists-path "$v0")" = "yes" ]; then
    log "migrate: a vault already points at $v0. Nothing to do."
    return 0
  fi

  local username
  username="$(id -un 2>/dev/null || whoami 2>/dev/null || echo user)"
  local label="${username}'s Think OS"
  local bm="think-os"

  log "Migrating v0 vault → multi-vault registry"
  log "  Path:        $v0"
  log "  Registering as id:  personal"
  log "  Label:       $label"
  log "  BM project:  $bm  (kept from v0 default)"

  local entry
  entry="$(VAULT_LABEL="$label" VAULT_PATH_ENV="$v0" VAULT_BM="$bm" python3 - <<'PYEOF'
import os, json
entry = {
    "id": "personal",
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
  log "Registered your existing vault as 'personal'. Ready to add project vaults."
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
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      err "Unknown flag: $1"
      usage >&2
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
  migrate)         cmd_migrate ;;
  *)
    err "Unknown subcommand: $SUB"
    usage >&2
    exit 2
    ;;
esac
