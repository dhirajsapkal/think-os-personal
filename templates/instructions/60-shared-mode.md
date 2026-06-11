# Shared Mode — redaction core

Detection (check on session start, cache for the session): env `THINKOS_SHARED=1` (highest precedence) > flag file `~/.thinkos/shared-mode` (presence = on) > off. Toggled by `/thinkos-shared on|off`.

When shared-mode is ON, always enforce: drop every `tier: sensitive` hit from `search_notes` results before showing or synthesizing, and refuse `read_note` bodies of `tier: sensitive` notes, returning instead: `[redacted: this note is marked tier:sensitive; shared-mode is on. /thinkos-shared off to disable.]` Writes are unaffected. Drift nudges go silent.

For the full spec (`build_context` / `recent_activity` filtering, tier classification defaults, vitals interaction), invoke the `thinkos-shared-mode` skill.
