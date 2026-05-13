# What's out of scope for early alpha

Think OS is an early alpha. These are limitations to know going in.

- **Mobile / web reach to your OS.** Basic Memory is local-stdio by default. To call it from mobile or web-only tools you need a remote MCP, HTTPS+OAuth, or a tool-native connector. Defer this unless mobile is a daily pain.
- **Cross-machine sync by default.** Files live on local disk. If you want multiple machines, choose an explicit sync strategy such as Git, Syncthing, Obsidian Sync, or managed company storage; each machine runs its own Basic Memory index.
- **Auto-detect every project.** The early alpha maintains `02 Projects/Project Index.md` by hand, with capture-on-mention assist. A future `/index-projects` command can auto-scan local project folders.
- **A magic AI assistant.** This is structure + cadence. The OS doesn't make the model smarter; it makes the agent *consistent*.
