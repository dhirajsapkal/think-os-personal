#!/usr/bin/env bash
# =============================================================================
# scripts/lib/uid.sh — ULID generator and frontmatter UID injection
# =============================================================================
# Sourceable library. Provides:
#
#   uid_generate
#     Print a fresh ULID (26-char Crockford base32, time-sortable) to stdout.
#     Uses python3 stdlib only — no external deps.
#
#   uid_frontmatter_inject <markdown-file>
#     If the file's YAML frontmatter does not contain a `uid:` key, add one
#     with a freshly generated ULID. If frontmatter is absent entirely,
#     create one. Idempotent: a no-op if `uid:` is already present.
#
# This library is intentionally side-effect free at source time — it only
# defines functions. Other scripts source it and call the functions on
# demand.
#
# Conventions:
# - macOS-only is fine; we rely on python3 (always present on macOS 12+).
# - Bash 3.2 compatible (no associative arrays, no `${var^^}`).
# =============================================================================

# -----------------------------------------------------------------------------
# uid_generate — print a single ULID to stdout
# -----------------------------------------------------------------------------
uid_generate() {
  python3 - <<'PYEOF'
import os, time, sys

# Crockford base32 alphabet (no I, L, O, U)
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

def encode(value, length):
    out = []
    for _ in range(length):
        out.append(ALPHABET[value & 0x1F])
        value >>= 5
    return "".join(reversed(out))

# 48 bits of millisecond timestamp + 80 bits of randomness = 128 bits total,
# encoded as 26 Crockford base32 chars (10 time + 16 random).
ts_ms = int(time.time() * 1000) & ((1 << 48) - 1)
rand = int.from_bytes(os.urandom(10), "big")

time_part = encode(ts_ms, 10)
rand_part = encode(rand, 16)

sys.stdout.write(time_part + rand_part + "\n")
PYEOF
}

# -----------------------------------------------------------------------------
# uid_frontmatter_inject <markdown-file>
# -----------------------------------------------------------------------------
# Idempotent. If the file already has `uid:` in its frontmatter, leave it.
# If it has frontmatter but no uid, add `uid: <new>` as the last key.
# If it has no frontmatter, prepend one with just `uid: <new>`.
uid_frontmatter_inject() {
  local file="$1"
  if [ -z "$file" ]; then
    echo "uid_frontmatter_inject: missing file argument" >&2
    return 2
  fi
  if [ ! -f "$file" ]; then
    echo "uid_frontmatter_inject: not a file: $file" >&2
    return 2
  fi

  local new_uid
  new_uid="$(uid_generate)"

  FILE="$file" NEW_UID="$new_uid" python3 - <<'PYEOF'
import os, sys, tempfile

path = os.environ["FILE"]
new_uid = os.environ["NEW_UID"].strip()

with open(path, "r", encoding="utf-8") as fh:
    content = fh.read()

# Detect frontmatter: file must start with a line that is exactly '---'
# followed by lines until a closing '---' on its own line.
lines = content.splitlines(keepends=True)

def write_atomic(new_content):
    dirn = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=dirn, prefix=".uid-inject-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(new_content)
        os.replace(tmp, path)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise

has_fm = len(lines) > 0 and lines[0].rstrip("\n").rstrip("\r") == "---"

if has_fm:
    close_idx = None
    for i in range(1, len(lines)):
        stripped = lines[i].rstrip("\n").rstrip("\r")
        if stripped == "---":
            close_idx = i
            break
    if close_idx is None:
        # Malformed frontmatter (no close). Treat as no frontmatter and
        # prepend a fresh one above existing content.
        new_content = "---\nuid: %s\n---\n\n%s" % (new_uid, content)
        write_atomic(new_content)
        sys.exit(0)

    fm_body = lines[1:close_idx]
    # Check for existing uid: key (top-level, simple key form)
    for ln in fm_body:
        # match a line beginning with optional whitespace 'uid' and a colon.
        # Top-level keys won't be indented; we only treat indent==0 as top-level.
        s = ln.rstrip("\n").rstrip("\r")
        if s.startswith("uid:") or s.startswith("uid :"):
            # Already present — no-op.
            sys.exit(0)

    # Insert uid: <new_uid> just before the closing ---.
    insertion = "uid: %s\n" % new_uid
    new_lines = lines[:close_idx] + [insertion] + lines[close_idx:]
    write_atomic("".join(new_lines))
    sys.exit(0)
else:
    # No frontmatter — prepend one. Preserve original content verbatim.
    sep = "" if content.startswith("\n") or content == "" else "\n"
    new_content = "---\nuid: %s\n---\n%s%s" % (new_uid, sep, content)
    write_atomic(new_content)
    sys.exit(0)
PYEOF
}
