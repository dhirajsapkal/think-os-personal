# Shared-mode — hide `tier: sensitive` notes

> When the user is screen-sharing or handing the session to a collaborator, mask sensitive notes from the agent's reads. Writes are unaffected.

## Detection

Two signals, with explicit precedence:

1. **Env var `THINKOS_SHARED=1`** (highest precedence). Per-process; vanishes on new sessions. Good for ad-hoc terminal handoff.
2. **Flag file `~/.thinkos/shared-mode`** (canonical). Presence = on, absence = off. Single line of content: `on since <ISO>`. Toggled by `/thinkos-shared on|off`.
3. **Off** otherwise.

**Precedence:** env > file > off. If `THINKOS_SHARED=1` is set, shared-mode is on regardless of whether the file exists. If the env var is unset, the file decides.

Read both on session start; cache the result for the session. If neither signal is present, behave normally.

## Frontmatter spec

New frontmatter field on any note:

```yaml
tier: standard | sensitive
```

Default is `standard`. Omitted = `standard`. Older readers and older agent versions ignore the field — the rollout is fully additive.

## Read behavior under shared-mode

When shared-mode is on:

- **`mcp__basic-memory__search_notes`** — post-filter results: drop every hit whose frontmatter has `tier: sensitive` before showing to the user or using in synthesis.
- **`mcp__basic-memory__read_note`** on a `tier: sensitive` note — return the redaction message instead of the body:

  > `[redacted: this note is marked tier:sensitive; shared-mode is on. /thinkos-shared off to disable.]`

- **Writes are unaffected.** The agent can still propose-and-save into any tier (including sensitive) — the user can capture compensation context mid-shared-session without leaking it back into context. The write succeeds; subsequent reads in the same shared session will redact.

## Defaults

Files under `05 Profile/` whose title or top-level heading contains any of these keywords should be classified `tier: sensitive` by default:

- `comp`, `salary`, `compensation`, `bonus`, `raise`
- `HR`, `performance review`, `PIP`
- `health`, `medical`, `family`
- `personal` (when in a `05 Profile/` context)

The one-time classifier `scripts/thinkos-classify-tiers.sh` (shipped separately) proposes a list and asks the user to confirm. The agent never silently re-tiers a note.

## Drift / vitals interaction

- Drift nudges (see `50-drift-detection.md`) are silent when shared-mode is on.
- `/thinkos-vitals` still runs but redacts file paths under `05 Profile/` that match the sensitive defaults — replaces names with `[redacted profile note]` in shared output.
