#!/usr/bin/env bash
# =============================================================================
# scripts/thinkos-index.sh — Filesystem + git + manifest indexer for Phase 2
# =============================================================================
# Walks one or more user-selected folders and writes deterministic project
# metadata to <vault>/.index/projects.json. This is the cheap, scriptable
# half of Phase 2 — Phase 2's agent playbook reads this JSON and synthesizes
# Project Index drafts from it (instead of paging through MCP calls).
#
# Usage:
#   scripts/thinkos-index.sh <folder> [<folder> ...]
#
# Options:
#   --vault PATH        Vault path (default: $THINKOS_HOME or ~/ThinkOS/vault)
#   --depth N           How deep to recurse into each folder (default: 2)
#   --refresh           Overwrite existing .index/projects.json
#   --json              Emit results to stdout as JSON (also writes to disk)
#   -h, --help          Show help
#
# Example:
#   scripts/thinkos-index.sh ~/Documents/Think ~/code
#   scripts/thinkos-index.sh --vault ~/ThinkOS/test-vault ~/code
# =============================================================================
set -uo pipefail

VAULT_PATH="${THINKOS_HOME:-$HOME/ThinkOS/vault}"
DEPTH=2
REFRESH=0
EMIT_JSON=0
FOLDERS=()

usage() {
  cat <<'EOF'
Usage: scripts/thinkos-index.sh <folder> [<folder> ...]

Walks user-selected folders and writes project metadata to
<vault>/.index/projects.json. Cheap, deterministic, no MCP calls.

Options:
  --vault PATH        Vault path (default: $THINKOS_HOME or ~/ThinkOS/vault)
  --depth N           Recursion depth into each folder (default: 2)
  --refresh           Overwrite existing .index/projects.json
  --json              Also emit JSON to stdout
  -h, --help          Show this help

A subfolder is treated as a project candidate when it contains any of:
  .git/, package.json, pyproject.toml, Cargo.toml, go.mod, requirements.txt,
  README.md, or 5+ markdown files.

For each candidate, the indexer records: path, slug, tech stack guess,
README first paragraph, last git commit (date + message), top 5 git
collaborators (last 180d), and last modified time of any non-hidden file.

Example:
  scripts/thinkos-index.sh ~/Documents/Think ~/code
  scripts/thinkos-index.sh --vault ~/ThinkOS/test-vault ~/code/myrepo
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --refresh) REFRESH=1; shift ;;
    --json) EMIT_JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) FOLDERS+=("$1"); shift ;;
  esac
done

if [[ "${#FOLDERS[@]}" -eq 0 ]]; then
  printf 'thinkos-index: at least one folder argument is required.\n\n' >&2
  usage >&2
  exit 2
fi

# Expand leading ~ in folder args
for i in "${!FOLDERS[@]}"; do
  FOLDERS[$i]="${FOLDERS[$i]/#\~/$HOME}"
done

# Verify folders exist
for f in "${FOLDERS[@]}"; do
  if [[ ! -d "$f" ]]; then
    printf 'thinkos-index: folder does not exist: %s\n' "$f" >&2
    exit 1
  fi
done

INDEX_DIR="$VAULT_PATH/.index"
OUTPUT="$INDEX_DIR/projects.json"

if [[ -f "$OUTPUT" && "$REFRESH" -eq 0 ]]; then
  printf 'thinkos-index: %s already exists. Pass --refresh to overwrite.\n' "$OUTPUT" >&2
  exit 1
fi

mkdir -p "$INDEX_DIR"

# =============================================================================
# Heavy lifting via Python — easier JSON + regex than pure bash, but no
# third-party deps. stdlib only (json, os, re, subprocess, datetime).
# =============================================================================
INDEX_PY=$(cat <<'PYEOF'
import json, os, re, subprocess, sys, datetime
from pathlib import Path

depth = int(sys.argv[1])
output_path = sys.argv[2]
folders = sys.argv[3:]

MANIFEST_FILES = {
    'package.json': 'node',
    'pyproject.toml': 'python',
    'requirements.txt': 'python',
    'Cargo.toml': 'rust',
    'go.mod': 'go',
    'Gemfile': 'ruby',
    'composer.json': 'php',
    'pom.xml': 'java',
    'build.gradle': 'java',
    'build.gradle.kts': 'kotlin',
}

def is_candidate(path: Path) -> bool:
    if not path.is_dir():
        return False
    if (path / '.git').exists():
        return True
    if any((path / m).exists() for m in MANIFEST_FILES):
        return True
    if (path / 'README.md').exists() or (path / 'README.mdx').exists():
        return True
    # 5+ markdown files at the top level
    try:
        md_count = sum(1 for f in path.iterdir() if f.is_file() and f.suffix.lower() in {'.md', '.mdx'})
        if md_count >= 5:
            return True
    except (PermissionError, OSError):
        return False
    return False

def tech_stack(path: Path) -> str:
    for manifest, tech in MANIFEST_FILES.items():
        if (path / manifest).exists():
            return tech
    if (path / '.git').exists():
        return 'unknown (git repo, no manifest)'
    return 'docs/notes'

def readme_first_paragraph(path: Path) -> str:
    for name in ('README.md', 'README.mdx', 'README'):
        readme = path / name
        if readme.is_file():
            try:
                text = readme.read_text(errors='replace')
            except (PermissionError, OSError):
                return ''
            # Skip frontmatter
            if text.startswith('---'):
                end = text.find('---', 3)
                if end != -1:
                    text = text[end + 3:]
            # Find first paragraph after any headers
            for paragraph in re.split(r'\n\s*\n', text.strip()):
                p = paragraph.strip()
                if p.startswith('#'):
                    p = re.sub(r'^#+\s*', '', p)
                if p and not p.startswith('!['):
                    return p[:240]
            return ''
    return ''

def git_info(path: Path) -> dict:
    if not (path / '.git').exists():
        return {}
    info = {}
    try:
        last = subprocess.run(
            ['git', '-C', str(path), 'log', '-1', '--pretty=format:%ci|%s'],
            capture_output=True, text=True, timeout=5,
        )
        if last.returncode == 0 and last.stdout.strip():
            parts = last.stdout.strip().split('|', 1)
            if len(parts) == 2:
                info['last_commit_date'] = parts[0].split()[0]
                info['last_commit_subject'] = parts[1][:120]
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    try:
        authors = subprocess.run(
            ['git', '-C', str(path), 'log',
             '--since=180.days', '--pretty=format:%an'],
            capture_output=True, text=True, timeout=5,
        )
        if authors.returncode == 0 and authors.stdout.strip():
            # dedup preserving frequency rank
            counts: dict[str, int] = {}
            for line in authors.stdout.splitlines():
                name = line.strip()
                if name:
                    counts[name] = counts.get(name, 0) + 1
            ranked = sorted(counts.items(), key=lambda x: -x[1])
            info['collaborators'] = [name for name, _ in ranked[:5]]
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    return info

def mtime_iso(path: Path) -> str:
    """Most recent mtime among non-hidden files at top level."""
    latest = 0.0
    try:
        for f in path.iterdir():
            if f.name.startswith('.'):
                continue
            if f.is_file():
                try:
                    mt = f.stat().st_mtime
                    if mt > latest:
                        latest = mt
                except (PermissionError, OSError):
                    continue
    except (PermissionError, OSError):
        pass
    if latest == 0.0:
        return ''
    return datetime.datetime.fromtimestamp(latest).strftime('%Y-%m-%d')

def slugify(name: str) -> str:
    s = re.sub(r'[^a-zA-Z0-9-]+', '-', name).strip('-').lower()
    return s or 'unnamed'

def walk(root: Path, max_depth: int, current_depth: int = 0):
    """Yield candidate project paths up to max_depth."""
    if current_depth > max_depth:
        return
    if not root.is_dir():
        return
    # Don't descend into common noise
    if root.name in {'node_modules', '.venv', 'venv', '__pycache__', '.git',
                     'dist', 'build', 'target', '.next', '.nuxt'}:
        return
    if is_candidate(root) and current_depth > 0:
        yield root
        # Don't descend into a project once found (avoid nested noise)
        return
    try:
        children = list(root.iterdir())
    except (PermissionError, OSError):
        return
    for child in sorted(children):
        if child.is_dir() and not child.name.startswith('.'):
            yield from walk(child, max_depth, current_depth + 1)

projects = []
for folder_str in folders:
    if not folder_str:
        continue
    root = Path(folder_str)
    for candidate in walk(root, depth):
        entry = {
            'path': str(candidate),
            'name': candidate.name,
            'slug': slugify(candidate.name),
            'source_root': str(root),
            'tech_stack': tech_stack(candidate),
            'readme_first_paragraph': readme_first_paragraph(candidate),
            'last_modified': mtime_iso(candidate),
        }
        entry.update(git_info(candidate))
        projects.append(entry)

# Sort by last_commit_date (descending), then last_modified, then name
def sort_key(e):
    return (e.get('last_commit_date') or e.get('last_modified') or '', e['name'])
projects.sort(key=sort_key, reverse=True)

output = {
    'version': 1,
    'generated_at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'source_folders': folders,
    'depth': depth,
    'project_count': len(projects),
    'projects': projects,
}

with open(output_path, 'w') as fh:
    json.dump(output, fh, indent=2)
    fh.write('\n')

# Summary to stderr (stays out of stdout JSON if --json was requested)
print(f"Indexed {len(projects)} project candidates from {len(folders)} root folder(s).", file=sys.stderr)
for p in projects[:10]:
    print(f"  · {p['path']}  [{p['tech_stack']}]", file=sys.stderr)
if len(projects) > 10:
    print(f"  · ... and {len(projects) - 10} more", file=sys.stderr)
PYEOF
)

if [[ "$EMIT_JSON" -eq 1 ]]; then
  python3 -c "$INDEX_PY" "$DEPTH" "$OUTPUT" "${FOLDERS[@]}"
  cat "$OUTPUT"
else
  python3 -c "$INDEX_PY" "$DEPTH" "$OUTPUT" "${FOLDERS[@]}"
fi

printf '\nWrote: %s\n' "$OUTPUT"
