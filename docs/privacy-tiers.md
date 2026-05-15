---
type: design-doc
tags:
- privacy
- agents
permalink: think-os/docs/privacy-tiers
---

# Privacy Tiers + Shared Mode

Long-form spec for the `tier:` frontmatter field and the shared-mode flag. The curated rule lives at `templates/instructions/60-shared-mode.md`; the toggle command at `adapters/claude-code/commands/thinkos-shared.md`.

## The two-tier model

Every Basic Memory note can carry a `tier:` field in its frontmatter:

```yaml
tier: standard | sensitive
```

- **`standard`** (default; omitted = standard). All notes behave the same as today — readable by the agent in any session.
- **`sensitive`** — hidden from agent reads when shared-mode is on. Writes are unaffected.

The field is **additive**. Older readers and older agent versions ignore it. A v0.4 agent reading a note tagged `tier: sensitive` will read it normally; only a v0.5+ agent running in shared-mode will mask it. The rollout is fully backward-compatible.

## Shared-mode flag

Shared-mode is enabled by either of two signals:

1. **Env var `THINKOS_SHARED=1`** (highest precedence). Per-process; vanishes on new sessions.
2. **Flag file `~/.thinkos/shared-mode`**. Presence = on, absence = off. Single line: `on since <ISO>`. Persists across sessions until toggled off.

Precedence: env > file > off. The toggle command `/thinkos-shared on|off` manages the file. The env var is the escape hatch for ad-hoc terminal sessions where the user wants shared behavior without touching the file.

The agent reads both signals on session start and caches the result for the session.

## What shared-mode changes

When shared-mode is on:

- **`mcp__basic-memory__search_notes`** post-filters its results: any hit whose frontmatter contains `tier: sensitive` is dropped before the agent uses it for synthesis or shows it to the user.
- **`mcp__basic-memory__read_note`** on a `tier: sensitive` note returns the redaction message instead of the body:

  > `[redacted: this note is marked tier:sensitive; shared-mode is on. /thinkos-shared off to disable.]`

- **Writes are unaffected.** The agent can still `edit_note` / `write_note` into any tier — including sensitive — during a shared session. The captured content lands in the vault; subsequent reads in the same session redact.
- **Drift nudges** (`50-drift-detection.md`) are silent.
- **`/thinkos-vitals`** runs but redacts file paths under `05 Profile/` that match sensitive defaults; replaces names with `[redacted profile note]` in shared output.

## Recommended sensitive defaults

Files under `05 Profile/` whose title or top-level heading contains any of these keywords are recommended candidates for `tier: sensitive`:

- `comp`, `salary`, `compensation`, `bonus`, `raise`
- `HR`, `performance review`, `PIP`
- `health`, `medical`, `family`
- `personal` (when in a `05 Profile/` context)

The shipped classifier `scripts/thinkos-classify-tiers.sh` (added in a later wave) proposes a list and asks the user to confirm. The agent never silently re-tiers a note.

## Onboarding existing notes

Users with existing vaults can opt in to tiers:

1. Run `scripts/thinkos-classify-tiers.sh` to scan `05 Profile/` and propose candidates.
2. Review the list; confirm each candidate (or skip).
3. The script writes `tier: sensitive` into the frontmatter of confirmed notes.

Users who don't run the classifier are unaffected. All their notes default to `standard`; shared-mode has nothing to mask.

## Worked examples

**Example 1: screen-share with a manager.**
User toggles `/thinkos-shared on` before the call. During the call they ask "what's my current focus?" The agent reads Current Focus normally (standard tier). They ask "remind me what we agreed about my comp last quarter." The agent attempts to read `05 Profile/Compensation Notes.md` (tagged `tier: sensitive`) and returns the redaction message instead. User toggles `/thinkos-shared off` after the call.

**Example 2: handing the keyboard to a teammate.**
User sets `export THINKOS_SHARED=1` in the shared terminal and walks away. Teammate runs `/thinkos-whoami`; the agent answers from Identity (standard) but masks any `tier: sensitive` references. When the teammate hands the keyboard back, the user `unset THINKOS_SHARED` to restore normal behavior. The flag file was never written, so no cleanup is needed.

**Example 3: drafting sensitive content during a shared session.**
User is in shared-mode and wants to log a quick note about a private conversation. They run `/thinkos-capture "decided to take the offer at <competitor> if comp negotiation fails"`. The capture succeeds — writes are unaffected. The note lands in the vault tagged `tier: sensitive` (the agent classifies it via the keyword check). A subsequent read in the same shared session would redact it.

## Limitations

- Tiers are **frontmatter-level**, not paragraph-level. A note is either standard or sensitive — there's no per-section masking.
- The redaction message is **observable**. If the user is screen-sharing and asks about a sensitive note, the collaborator sees "redacted: this note is marked tier:sensitive." That's intentional — the agent doesn't pretend the note doesn't exist; it just doesn't show the contents.
- **Search-result drops are not announced.** If shared-mode causes a search to return fewer results than it would have, the agent does not tell the user "I masked some results." That would itself leak the existence of sensitive notes. Trade-off accepted.
