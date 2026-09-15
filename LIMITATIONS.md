# Known limitations (current release)

## Platform

- **macOS only.** Scheduling uses launchd, the encrypted-tier design assumes APFS encrypted volumes, and passphrase storage assumes the macOS Keychain. Linux is unsupported in v1 (an `age`-based fallback is sketched in `docs/multi-vault-architecture.md` §11.3 but not implemented).
- **Claude Code only.** Cowork and Codex adapters live on the `roadmap/cowork-codex` branch — their plugin formats aren't stable enough to automate yet. Cherry-pick when ready.
- **Mobile / web reach.** Basic Memory is local-stdio. Reaching it from mobile or web-only tools requires a remote MCP, HTTPS+OAuth, or a tool-native connector.

## Dependencies

- **Requires `uv` and Python 3.9+** for Basic Memory and the session-capture filter.
- **Requires Basic Memory >= 0.13.x.** Older versions lack the tool surface the curated instructions depend on.
- **Phase 3 LLM-prompted jobs need non-interactive `claude -p`.** Whether scheduled `claude -p` runs work (and what they cost) depends on your Claude plan. Deterministic jobs (daily reindex, session capture) don't need it.

## Enforcement model

- **Shared-mode is agent-behavioral, not OS-enforced.** Hiding `tier: sensitive` notes happens inside the agent following instructions — it's a screen-share courtesy filter, not a cryptographic guarantee. Keep truly sensitive notes outside the vault or in a separate vault.
- **CLAUDE.md instructions are advisory.** The curated block gets roughly ~80% adherence, not 100% — the agent can miss a first-action read or a capture offer. Behaviors that must always fire need harness-level hooks, not instructions.

## Scope

- **Cross-machine sync** is first-class via `/thinkos-sync` (manual) or the opt-in launchd job (default 18:00 weekdays). For non-git sync strategies (Syncthing, iCloud), see `docs/cross-machine-sync.md`.
- **Auto-detect every project.** `02 Projects/Project Index.md` is maintained by hand with capture-on-mention assist. Use `bash scripts/thinkos-index.sh` to auto-scan local project folders; the `/thinkos-refresh` skill drives the in-agent version of the same flow.
