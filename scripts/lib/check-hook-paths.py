#!/usr/bin/env python3
"""Find hooks and agents writing to a vault that is not the active one.

Three hooks and two agent definitions were found writing to the pre-v0.8
predecessor vault for four months. Nothing surfaced it, because a hook that
writes to the wrong place does not error — it succeeds, somewhere useless.

Two findings, by severity:
  dead-paths     the path does not exist. Writes fail silently every time, or
                 recreate the orphan. Always wrong.
  foreign-vault  the path exists but is outside the active vault. Legitimate
                 for a reference vault, suspect otherwise.

Emits tab-separated `name<TAB>status<TAB>detail` for thinkos-doctor.sh.
Lives as a file rather than an inline heredoc: `bash -n` does not validate
heredoc contents, so a stray backtick or quote in embedded Python silently
kills every check downstream while still passing a syntax check.

Usage: check-hook-paths.py [vault-path]
"""

import glob
import os
import re
import sys

# A path worth judging: absolute or ~-rooted, and named like vault content.
#
# Two patterns, because vault paths routinely contain spaces ("Claude OS Setup",
# "01 Now"). A bare whitespace-delimited match truncates at the first space and
# then fails the VAULTISH test — which is exactly how the first version of this
# checker reported "ok" on a path it had been pointed straight at.
QUOTED_RE = re.compile(r"""["'](((?:~|/Users/)[^"']*))["']""")
BARE_RE = re.compile(r"""(?:~|/Users/[^/\s"'`]+)/[^\s"'`)}\]]*""")


def candidate_paths(text):
    """Paths inside quotes (may contain spaces) plus bare unquoted ones."""
    found = {m.group(1) for m in QUOTED_RE.finditer(text)}
    found |= set(BARE_RE.findall(text))
    return found
VAULTISH = re.compile(
    r"work-log|current-focus|identity\.md|people\.md|decisions\.md|learnings\.md|"
    r"business-brain|active-projects|project.index|\.last-touched|ThinkOS|OS Setup|vault",
    re.I,
)
# Paths that are legitimately outside the vault.
ALLOW = re.compile(r"/\.claude/|/\.thinkos/|/code/think-os/|/Library/Logs/|/tmp/")


def main() -> int:
    vault = os.path.realpath(
        sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/ThinkOS/vault")
    )

    targets = []
    for pattern in ("~/.claude/hooks/*.sh", "~/.claude/agents/*.md"):
        targets += glob.glob(os.path.expanduser(pattern))

    dead, foreign = set(), set()
    for path in targets:
        try:
            text = open(path, errors="replace").read()
        except OSError:
            continue
        name = os.path.basename(path)
        for raw in candidate_paths(text):
            if not VAULTISH.search(raw) or ALLOW.search(raw):
                continue
            expanded = os.path.expanduser(raw)
            if os.path.realpath(expanded).startswith(vault):
                continue
            (dead if not os.path.exists(expanded) else foreign).add((name, raw))

    if dead:
        listed = "; ".join(f"{n} → {p}" for n, p in sorted(dead)[:4])
        print(
            f"hooks:dead-paths\tfail\t{len(dead)} hook/agent reference(s) point at a path "
            f"that does not exist — writes there fail silently and reads return nothing: {listed}"
        )
    else:
        print("hooks:dead-paths\tok\tno hook or agent references a missing vault path")

    if foreign:
        listed = "; ".join(f"{n} → {p}" for n, p in sorted(foreign)[:4])
        print(
            f"hooks:foreign-vault\twarn\t{len(foreign)} hook/agent reference(s) resolve outside "
            f"the active vault ({vault}) — fine for a reference vault, otherwise they are "
            f"writing where nothing reads: {listed}"
        )
    else:
        print(
            "hooks:foreign-vault\tok\tevery hook and agent vault path resolves inside the active vault"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
