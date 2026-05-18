---
type: setup-guide
tags:
- setup
- install
- basic-memory
- mcp
- obsidian
permalink: think-os/setup-basic-memory
---

# Setup — Basic Memory MCP + Obsidian

One-time setup to make your personal context OS reachable from any desktop agent session (and any other MCP-aware agentic tool), and editable from a real markdown editor.

Agent-assisted setup can run the safe parts for you:

```bash
scripts/thinkos-setup.sh --install-basic-memory --yes
scripts/thinkos-doctor.sh --deep
```

**Time**: ~15 minutes for Basic Memory · +10 minutes for Obsidian (optional)
**Prereqs**: Homebrew on macOS (Linux / Windows users — adapt as needed)

**Variable used throughout**: `{{OS_HOME}}` = the folder where your live OS files live. Recommended local-only path: `~/ThinkOS/vault/`, but pick anything. Wherever you choose, put the populated templates from `templates/` there before starting Part 1.

---

## Part 1 — Install Basic Memory (~10 min)

[Basic Memory](https://github.com/basicmachines-co/basic-memory) is an MCP server that exposes your markdown files via tools any MCP client can call. Markdown stays the source of truth; SQLite + embeddings are a rebuildable derivative index.

### Step 1.1 — Install `uv` if you don't have it

`uv` is the fastest Python package manager. Open Terminal:

```bash
brew install uv
```

Already have `uv`? Skip. (`uv --version` to check.)

### Step 1.2 — Install Basic Memory

```bash
uv tool install basic-memory
```

Verify:

```bash
basic-memory --version
```

You should see `0.13.x` or higher.

### Step 1.3 — Point Basic Memory at your OS folder

```bash
basic-memory project add think-os "{{OS_HOME}}" --local --default
basic-memory reindex --project think-os
```

The `reindex` reads every markdown file, parses frontmatter, builds the SQLite + vector index. First run: 30–60 seconds for a small OS.

### Step 1.4 — Verify the index works

```bash
basic-memory tool search-notes "identity"
basic-memory tool search-notes "what's on my plate"
basic-memory tool search-notes "current focus"
```

You should see hits from `05 Profile/Identity.md`, `01 Now/Tasks.md`, and `01 Now/Current Focus.md` respectively. If you see errors, run `basic-memory status` and check that the project path matches `{{OS_HOME}}`.

### Step 1.5 — macOS file access

Basic Memory is local. It reads and edits files as a child process of the app that launched it, so macOS privacy rules still apply.

The least-friction path is to put `{{OS_HOME}}` outside protected folders like Documents, Desktop, Downloads, external drives, or cloud-provider folders. Recommended:

```bash
mkdir -p "$HOME/ThinkOS/vault"
```

If you choose a protected folder, grant **Documents Folder** access, or Full Disk Access if needed, to every app that will launch the MCP: Claude Code, Claude Desktop, and the terminal app used for CLI.

A setup script can open the right settings pane, but it cannot silently grant permission:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
```

Healthy check:

```bash
basic-memory status --project think-os --json
basic-memory project ls --name think-os
basic-memory tool search-notes "identity" --project think-os
```

If search works but `project ls` is empty or `status` reports all files deleted, the host app still cannot read the vault folder.

### Step 1.6 — Troubleshooting: the cloud-mode trap

Basic Memory reserves project names **globally** in `~/.basic-memory/config.json`. If a project was ever registered without `--local` (for example by running a bare `basic-memory project add think-os ...`), that name is recorded with `"mode": "cloud"`. Two failure modes follow:

- **`project default` fails** — you see `"set to cloud mode but no credentials"` when running `basic-memory project default think-os`.
- **Re-add fails** — after removing the project and trying to re-add it, you see `"Project already exists"`.

**Detect it.** Check whether the config file contains a cloud entry for your project:

```bash
grep -A3 '"think-os"' ~/.basic-memory/config.json
```

If you see `"mode": "cloud"` in the output, the trap is active. `scripts/thinkos-doctor.sh` flags this as `basic-memory:cloud-mode` in its JSON output.

**Fix it.** Back up the config file first, then remove the offending entry:

```bash
cp ~/.basic-memory/config.json ~/.basic-memory/config.json.bak
```

Open `~/.basic-memory/config.json` in any text editor and delete the block for the `think-os` project (the entire object for that entry inside the `projects` array). If `think-os` is the only project in the file and you want the simplest path, you can delete the file entirely:

```bash
rm ~/.basic-memory/config.json
```

Then re-add the project in local mode:

```bash
basic-memory project add think-os "{{OS_HOME}}" --local --default
basic-memory reindex --project think-os
```

**Why local mode?** Think OS is file-first. The markdown vault is the source of truth; the SQLite + vector index is a rebuildable derivative. Cloud mode requires separate credentials and routes data through a remote service — neither is needed here. Cloud mode is opt-in only and is not configured by any Think OS setup script.

---

## Part 2 — Register Basic Memory in desktop agent (~3 min)

desktop agent manages MCPs through its UI rather than a config file.

### Step 2.1 — Open desktop agent settings

1. Open desktop agent
2. Click the gear icon (Settings)
3. Find the **Connectors** or **MCP Servers** section

### Step 2.2 — Add Basic Memory as a custom MCP

Look for "Add custom MCP" or "Add server":

- **Name**: `Basic Memory`
- **Command**: `basic-memory`
- **Args**: `mcp`
- **Working directory**: (leave default or set to `$HOME`)

If desktop agent wants the full path to the binary:

```bash
which basic-memory
```

Use whatever it returns (something like `/Users/{{you}}/.local/bin/basic-memory` or `/opt/homebrew/bin/basic-memory`).

### Step 2.3 — Save and restart desktop agent

Save the connector. **Restart desktop agent** (fully quit and reopen — not just close the window). MCPs only load on startup.

### Step 2.4 — Verify in a new desktop agent session

Open a fresh conversation (any project) and ask:

> "Can you list available MCP tools and confirm Basic Memory is among them?"

You should see tools like `search_notes`, `read_note`, `write_note`, `list_notes`, `build_context`, `edit_note`. If they're there, Part 2 is done.

If they don't appear: check the desktop agent connector status. The most common error is `command not found` — desktop agent can't see `basic-memory` in its PATH. Use the full path from `which basic-memory`.

---

## Part 3 — Tell your agent to use Basic Memory (~2 min)

Update your desktop agent **global personalization** (or per-project instructions). Paste this:

```
You are operating in my personal context OS. Use the Basic Memory MCP tools to access context:

- search_notes("identity") — load my role, working style, guardrails
- search_notes("project index active projects") — load the project index
- search_notes("current focus") — load this week's priorities
- search_notes("os instructions") — load the meta-rules for using this OS

For "what's on my plate" questions, also: read_note("Tasks")
For questions about people, also: read_note("People")
For comms drafting, also: search_notes("business brain") and any relevant 02 Projects/<slug>

The source-of-truth files are at {{OS_HOME}}. If Basic Memory MCP is unavailable, fall back to direct file reads against that path.

Default write targets: {{OS_HOME}} for memory/notes; the relevant project subfolder for project work. Never write to your Documents root unless I tell you to.
```

Save and verify: start a new desktop agent conversation in any project and ask "who am I?" — you should get a specific answer pulled from `05 Profile/Identity.md`.

---

## Part 4 — Optional: Obsidian as the editor (~10 min)

Obsidian is a free desktop app that opens any folder of markdown files as a "vault." It gives you backlinks, graph view, search, and an iOS app. The files stay plain markdown — Obsidian doesn't lock you in.

### Step 4.1 — Install Obsidian

```bash
brew install --cask obsidian
```

Or download from [obsidian.md](https://obsidian.md).

### Step 4.2 — Open the OS folder as a vault

1. Launch Obsidian
2. "Open folder as vault"
3. Navigate to `{{OS_HOME}}`
4. Select it
5. Open `00 Home.md` as your dashboard

You'll see:

- A quiet root with a dashboard plus numbered folders
- Wiki-links (`[[Person Name]]`, `[[project-slug]]`) become clickable
- Frontmatter renders as a properties panel
- Backlinks panel shows where each file is referenced
- Graph view shows the network of relationships

### Step 4.3 — Recommended Obsidian plugins (all free, optional)

In Obsidian → Settings → Community plugins → Browse:

- **Dataview** — query frontmatter across files
- **Templater** — better templates for new project files
- **Calendar** — daily-note view
- **Tag Wrangler** — manage tags across the vault

### Step 4.4 — Obsidian Mobile (optional)

Obsidian Mobile needs a sync layer to see the same vault on a phone. Use Obsidian Sync, Syncthing, Git, or another sync strategy you explicitly trust. The local MCP setup does not require mobile sync.

---

## Part 5 — Verification checklist

- [ ] `basic-memory status` shows the project synced
- [ ] desktop agent MCP panel shows Basic Memory as Connected (green dot)
- [ ] A fresh desktop agent conversation can call `search_notes("identity")` and get a hit
- [ ] Asking "who am I?" in a fresh desktop agent conversation returns a specific answer
- [ ] (Optional) Obsidian opens the vault and shows the graph view
- [ ] (Optional) Obsidian Mobile opens the same vault from your phone

Diagnostic order if anything fails: (a) Basic Memory binary works at the CLI? (b) desktop agent sees the MCP? (c) The MCP tools appear in a desktop agent session? (d) The agent uses them when prompted?

---

## What this gets you

- **Cross-project desktop agent access** — no more "add this folder to context every session"
- **Search beats grep** — agent can search "tasks past due" or "people I met about AI" and get back relevant matches
- **Future-proof access path** — any MCP-aware agentic tool points at Basic Memory and works
- **A real editor** — Obsidian for editing the OS by hand, graph view for connections, mobile editing

## What this doesn't solve

- **Mobile / web reach** — Basic Memory is stdio-only by default. To call it from mobile or web-only tools, you'd need to expose it via HTTPS+OAuth (a remote MCP, HTTPS/OAuth, or a tool-native connector). Defer this unless mobile reach becomes a daily pain.
- **Auto-refresh of `01 Now/Tasks.md` / `01 Now/Current Focus.md`** — those need `productivity:update` (desktop agent) and `/weekly-review` to run. Schedule those as desktop agent scheduled tasks. See `MAINTENANCE.md` for the cadence model.
- **Cross-Mac sync** — files live on local disk by default. `/thinkos-sync` is the first-class option: it commits, pull --rebases, and pushes your vault on demand (or on an opt-in 18:00-weekday launchd schedule via `bash scripts/install-sync-job.sh`). For non-git strategies (Syncthing, iCloud, Obsidian Sync), see `docs/cross-machine-sync.md`. Each Mac runs its own Basic Memory index; reindex on next session after a remote pull.

---

## Privacy

Basic Memory is a third-party MCP server installed via `uv tool install basic-memory`. Think OS configures it with `--local --default` which keeps the index entirely on disk under `~/.basic-memory/`.

To verify there is no cloud sync configured: `cat ~/.basic-memory/config.json` — the `mode` field should not be `"cloud"`.

To audit network activity: `lsof -i -n -P | grep basic-memory` while a session is active.

For company deployment: IT should review Basic Memory's license at https://github.com/basicmachines-co/basic-memory and confirm the project's privacy posture meets internal requirements.

Connector versions are pinned in `data/plugin-catalog.yaml`. The granola-mcp pin is `>=0.1` in v0.8; exact-version pinning is deferred to v0.9 pending vendor audit.

---

*Setup guide. Last reviewed when you complete it.*
