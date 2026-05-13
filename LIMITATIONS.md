# Out of scope (v0.3)

- **Claude Code only.** Cowork and Codex adapters are deferred. Their install APIs aren't stable enough to automate yet.
- **Mobile / web reach.** Basic Memory is local-stdio. Reaching it from mobile or web-only tools requires a remote MCP, HTTPS+OAuth, or a tool-native connector.
- **Cross-machine sync.** Files live on local disk. For multiple machines, choose an explicit sync strategy (Git, Syncthing, Obsidian Sync, or managed company storage); each machine runs its own Basic Memory index.
- **Auto-detect every project.** `02 Projects/Project Index.md` is maintained by hand with capture-on-mention assist. Use `/thinkos-index-projects` (when available) to auto-scan local project folders.
