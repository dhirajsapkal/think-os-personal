# Out of scope (current release)

- **Claude Code only.** Cowork and Codex adapters live on the `roadmap/cowork-codex` branch — their plugin formats aren't stable enough to automate yet. Cherry-pick when ready.
- **Mobile / web reach.** Basic Memory is local-stdio. Reaching it from mobile or web-only tools requires a remote MCP, HTTPS+OAuth, or a tool-native connector.
- **Cross-machine sync** is now first-class via `/thinkos-sync` (manual) or the opt-in launchd job (default 18:00 weekdays). For non-git sync strategies (Syncthing, iCloud), see `docs/cross-machine-sync.md`.
- **Auto-detect every project.** `02 Projects/Project Index.md` is maintained by hand with capture-on-mention assist. Use `bash scripts/thinkos-index.sh` to auto-scan local project folders; the `/index-projects` skill drives the in-agent version of the same flow.
