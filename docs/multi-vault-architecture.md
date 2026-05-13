---
type: architecture
status: proposed
tags:
- architecture
- multi-vault
- privacy
- onboarding
permalink: think-os/multi-vault-architecture
---

# Multi-Vault Architecture

How Think OS handles personal-and-project knowledge, enforces privacy structurally, and lets teams collaborate via git without leaking individual context.

This document is the authoritative reference for the multi-vault design. Implementation tracks against the slices in §10.

---

## 0. Summary

Think OS has one **personal hub vault** (always local, never shared), zero-or-more **project vaults** (shared with teammates via git), and zero-or-more **reference vaults** (read-only imports). The personal hub is always loaded into the agent's context; project vaults layer on top when active.

Privacy is enforced *structurally*: project vault schemas have no slot for personal content (no Work Log, no personal People notes, no `.private/`). The agent cannot write your personal log into a shared repo because there is no destination for it.

Personal vaults also support a true encrypted tier (`.vault/`, an APFS encrypted volume, Touch ID to unlock) for genuinely sensitive content. A middle tier (`.private/`, plain markdown + Time Machine exclusion) covers the everyday "not in backups" case.

Git fits in lazily — never in Phase 1 essentials. The first time a user runs a project-vault command, the system checks git+auth and walks them through install/auth if needed.

---

## 1. Vault types

Three vault types. A user has exactly one Personal Hub, and any number of Project and Reference vaults.

### A. Personal hub

- **Purpose**: your individual knowledge — identity, current focus, people, decisions, learnings, work log, encrypted personal vault.
- **Lives at**: `~/ThinkOS/vault/` (default; user can change).
- **Owner**: you only. Never shared.
- **Sync**: local-first. Optional encrypted backup (out of scope for v1).
- **Schema (full)**:
  ```
  00 Home.md
  01 Now/
    Current Focus.md
    Tasks.md
    Work Log.md
  02 Projects/
    Project Index.md
    <slug>.md per active project
  03 People/
    People.md
  04 Knowledge/
    Decisions.md
    Learnings.md
  05 Profile/
    Identity.md
    Voice Profile.md
    Business Brain.md
  90 System/
    OS Instructions.md
    Connectors.md
  99 Archive/
  .private/                  ← gitignored, Time Machine excluded
    sensitive-log.md
    notes.md
  .vault/                    ← APFS encrypted volume mount point
    relationships.md
    health.md
    finances.md
  .thinkos/
    vault.json               ← vault type + metadata
  ```

### B. Project / team vault

- **Purpose**: shared knowledge for a project or team — project mission, team roster, team decisions, team activity log, specs.
- **Lives at**: default `~/ThinkOS/projects/<name>/`; user can override (e.g. `~/Documents/Think/Argenx/team-os/`).
- **Owner**: team. Shared via git.
- **Sync**: git (any host: GitHub, GitLab, self-hosted).
- **Schema (reduced — no personal slots)**:
  ```
  00 Project Home.md
  01 Work/
    YYYY-MM-DD-<slug>.md       ← one file per entry (append-only)
  02 Decisions/
    YYYY-MM-DD-<slug>.md       ← one file per decision (ADR style, immutable)
  03 Specs/
    <topic>.md                 ← owned, edited via PR
  04 Roster.md                 ← single file, owner-gated
  05 Learnings/
    YYYY-MM-DD-<slug>.md
  .thinkos/
    vault.json                 ← vault type, schema mapping
    schemas/                   ← JSON schemas per content type
  CODEOWNERS                   ← review gating for single-file slots
  .gitignore                   ← excludes ~/.thinkos/, .private/, .vault/
  ```

  Notably absent: `Identity.md`, `Current Focus.md`, `Work Log.md`, `Voice Profile.md`, `.private/`, `.vault/`. The schema doesn't define them; the agent can't write them; teammates pulling the repo never see your personal content because it was never in the repo to begin with.

### C. Reference vault

- **Purpose**: imported folder of markdown the user reads from but doesn't own (e.g. company wiki cloned locally, an Obsidian export, a documentation site's markdown source).
- **Lives at**: wherever the source lives.
- **Owner**: someone else (or you, but treated read-only).
- **Sync**: pull-only git, or fully detached. No writes.
- **Schema**: none enforced. Indexed for search; visually marked `[reference]` in agent output.

---

## 2. Vault registry

A single source of truth at `~/.thinkos/vaults.json`. The wizard and the vault CLI maintain it.

```json
{
  "version": 1,
  "vaults": [
    {
      "id": "personal",
      "type": "personal",
      "label": "Dhiraj's Think OS",
      "path": "/Users/dhirajsapkal/ThinkOS/vault",
      "bm_project": "think-os",
      "default": true,
      "created_at": "2026-05-13T..."
    },
    {
      "id": "argenx-team",
      "type": "project",
      "label": "Argenx Team OS",
      "path": "/Users/dhirajsapkal/ThinkOS/projects/argenx",
      "bm_project": "argenx-os",
      "git_remote": "git@github.com:thinkco/argenx-os.git",
      "team_members": ["dhiraj", "maya", "sarah"],
      "created_at": "2026-05-15T..."
    },
    {
      "id": "design-system-ref",
      "type": "reference",
      "label": "Material Design Docs",
      "path": "/Users/dhirajsapkal/refs/material-docs",
      "bm_project": "material-docs",
      "read_only": true
    }
  ]
}
```

The `default` flag marks the personal hub as the always-loaded vault. The `type` field drives schema enforcement and routing decisions.

---

## 3. Active vault resolution

The agent needs to know which vault is "write-active" at any moment.

**Resolution order:**
1. **Explicit override** — `--vault <id>` flag on any command, or `thinkos vault use <id>` for a sticky session override.
2. **CWD-derived** — if `pwd` is under a registered vault's path, that vault is active.
3. **Default** — the vault marked `default: true` (always the personal hub).

The agent surfaces the active vault on its first response in any session:

> Active vault: `argenx-team` (Argenx Team OS). Personal hub `personal` always loaded for identity/focus.

---

## 4. Privacy: three layered mechanisms

### Layer 1 — Structural absence (no crypto needed)

The project vault schema has no slot for personal content. When the user says "log this" with a project vault active:

- If content has **first-person reflection markers** ("I felt", "I'm frustrated with") or **personal-keyword markers** (comp, salary, health, HR, family) → personal hub, automatic, no question.
- If content is **third-person team activity** ("team shipped X", "we decided Y") → project vault's `01 Work/`.
- If ambiguous → ask: "Personal log or project log?"

The agent never writes a personal-keyword entry to a project vault, even if explicitly asked. The schema validator at commit time would reject it anyway.

### Layer 2 — Filesystem hygiene (personal hub middle tier)

`.private/` subfolder in the personal hub:
- gitignored (relevant only if user opts into personal-vault git backup)
- Time Machine excluded via `tmutil addexclusion -p ~/ThinkOS/vault/.private` at install time (1Password's pattern)
- iCloud Documents&Desktop is explicitly *not* used; recommended vault location is outside `~/Documents`
- Plain markdown — fully readable to apps with full disk access, but invisible to most backup/sync paths

For passive-capture threat models (MDM backup, EDR-light), this is sufficient. Standard MDM enrollment does not read file contents without an EDR plugin.

### Layer 3 — Real encryption (personal hub top tier)

`.vault/` is an APFS encrypted volume:
- Created at install time via `hdiutil create -encryption AES-256 -fs APFS -volname thinkos-vault`
- Passphrase stored in macOS Keychain with `kSecAttrAccessibleWhenUnlocked` + Secure Enclave binding
- Mount requires Touch ID; auto-unmounts after configurable idle (default 60 min)
- Plain markdown *inside* the encrypted volume; backups see only the encrypted `.sparseimage` blob
- Time Machine excluded as belt-and-suspenders

The agent enters **personal mode** to read from `.vault/`:
- Slash command `/personal` toggles personal mode for the session
- Visible UI banner: `PERSONAL MODE — encrypted vault unlocked`
- In personal mode: `.vault/` is in-scope; writes to project vaults are *blocked*
- Exiting personal mode: agent context drops decrypted content; only re-readable by re-entering personal mode

This addresses the second threat (agent leakage into upstream conversations) — encryption protects against disk-level snooping, but the operating mode protects against the agent including content in a session that gets sent to Anthropic.

---

## 5. Schema enforcement

Plain markdown has no native schema. The chosen stack:

- **Frontmatter schemas** as JSON Schema files at `<vault>/.thinkos/schemas/<type>.schema.json`
- **Schema-per-folder mapping** in `<vault>/.thinkos/vault.json`:
  ```json
  {
    "schema_map": {
      "01 Work/*.md": "work-entry.schema.json",
      "02 Decisions/*.md": "decision.schema.json",
      "03 Specs/*.md": "spec.schema.json"
    }
  }
  ```
- **Pre-commit validation hook** (`.git/hooks/pre-commit` installed at vault create) using `remark-lint-frontmatter-schema` or equivalent
- **Hard block on project vaults; warn-only on personal hub** (per research: strict enforcement kills contribution friction on shared spaces; less critical on single-author personal)
- **Agent honors schema at write time** — when writing a Decision, fills exactly the required fields from the schema

Stable UIDs in frontmatter via ULID (`uid: 01J5XYZ...`). Cross-vault links target the UID, not the filename. Prevents link rot on renames.

---

## 6. Git: when and how it enters the picture

### When (lazy)

Git is **not** a Phase 1 essential. A user who only wants a personal vault never installs git via Think OS.

Git is checked the first time a user runs a project-vault command (`thinkos vault create-project` or `thinkos vault clone`). The check sequence:

1. `command -v git` exists?
2. `git config user.name` and `user.email` set?
3. For clone via SSH: `ssh -T git@github.com` succeeds?
4. For create with `--remote github:org/repo` shorthand: `gh auth status` succeeds?

If any check fails, walk the user through the fix:

- Missing git: `brew install git`
- Missing config: prompt for name + email
- Missing SSH key: `ssh-keygen -t ed25519` + paste pubkey to GitHub (link provided)
- Missing `gh` auth: `brew install gh && gh auth login`

This is a separate subcommand `thinkos doctor --git` for explicit health-checking. It runs implicitly before any project-vault git operation.

### How (operations)

**Creating a new project vault**:
1. User: `thinkos vault create-project <name>` (or interactive wizard)
2. Ask: name, label (display), path (default `~/ThinkOS/projects/<name>/`), bm_project name (default `<name>-os`), git remote (optional)
3. Run git checks (above)
4. Create directory, copy `templates/team/` to it
5. `cd <path> && git init -b main && git add . && git commit -m "Initial commit (Think OS project vault)"`
6. If `--remote`: `git remote add origin <url> && git push -u origin main` (or `gh repo create` + push, if shorthand used)
7. Register in `~/.thinkos/vaults.json`
8. `basic-memory project add <bm_project> <path> --local`
9. `basic-memory reindex --project <bm_project>`
10. Tell user how to invite teammates (share the git URL; teammates run `thinkos vault clone <url>`)

**Cloning an existing project vault**:
1. User: `thinkos vault clone <git-url>` (or interactive wizard, e.g. `/thinkos-vault` in agent)
2. Ask: path (default `~/ThinkOS/projects/<derived-name>/`)
3. Run git checks
4. `git clone <url> <path>`
5. Verify it's a Think OS project vault: check for `<path>/.thinkos/vault.json`. If absent: ask user "this doesn't look like a Think OS project vault — register as a reference vault instead?"
6. Read `vault.json` for `bm_project` name + label
7. Register in `~/.thinkos/vaults.json`
8. `basic-memory project add <bm_project> <path> --local`
9. `basic-memory reindex --project <bm_project>`

**Updating from teammates**:
- Standard `git pull` in the vault directory
- Followed by `basic-memory reindex --project <bm_project>` (or automatic via filesystem watcher — v2)

**Pushing your contributions**:
- Standard `git add / commit / push` 
- The pre-commit hook validates schema; commit is blocked on violation

### Conflict avoidance

The schema in §1 makes most concurrent writes conflict-free:
- `01 Work/`, `02 Decisions/`, `05 Learnings/` are one-file-per-entry, named `YYYY-MM-DD-<slug>.md`. Two people writing on the same day produce two files, not a conflict.
- `04 Roster.md` and `00 Project Home.md` are single files with `owner: @handle` frontmatter and `CODEOWNERS` review gating — edited via PR, not concurrent writes.
- The `.thinkos/` config dir is owned by one maintainer (the person who ran `create-project`); changes go via PR.

When conflicts do happen (rare), they're standard git merge conflicts. The agent can help resolve them with a `/thinkos-vault resolve-conflicts` workflow (v2).

---

## 7. Onboarding flow: where each piece fits

### Phase 1 essentials (setup — unchanged in scope)

Phase 1 sets up the **personal hub** only, via the agent-driven install:
- Vault location (default `~/ThinkOS/vault/`)
- Claude Code adapter (MCP, instructions, slash commands)
- Basic Memory installed + project registered
- Plugin bundle (pm / eng / design / ops)

No git. No project vaults. No encrypted vault. This stays as a tight ~5 minute flow.

The post-setup checklist now mentions multi-vault as an *optional next step*:

```
[5] Optional: add a project or team vault
    · `thinkos vault create-project <name>` to create one
    · `thinkos vault clone <git-url>` to join a team's existing one
    · Or wait — you can do this anytime via /thinkos-vault in your agent
```

### Phase 2 essentials (context seeding — unchanged)

Still focused on personal hub HOT-tier seeding. No multi-vault involvement.

### Phase 3 (new — project vaults)

Triggered when user explicitly runs `thinkos vault create-project` or `clone`, or invokes `/thinkos-vault` in an agent. Not gated by Phase 1/2 completion (you can add a project vault anytime). The slash command playbook walks the user through:

- Are you creating new or joining existing?
- For new: name, path, remote
- For clone: URL, path
- (Git check runs implicitly, walks user through any missing pieces)
- Registers, indexes, confirms

### Encrypted personal vault (`.vault/`)

Set up on-demand via `thinkos vault setup-encrypted` (or auto-prompted the first time user uses `/personal` and no `.vault/` exists). Not part of essentials — most users don't need it. Adds friction; only worth it for users with genuinely sensitive content to compartmentalize.

---

## 8. Agent integration

### Active-vault awareness

Every agent session, the adapter instructions tell the agent to:

1. Read `~/.thinkos/vaults.json` on startup
2. Determine active vault per §3
3. Mention active vault in the first response: `Active vault: <id>. Personal hub always loaded.`
4. Load HOT-tier from personal hub *always*: Identity, Current Focus
5. Layer in active vault's "project HOT" (Project Identity, Roster) if active vault is a project type

### Routing rules

When the agent is about to write content:

```
1. Identify content type (work log entry, decision, person note, etc.)
2. Identify scope markers (personal-keyword? first-person reflection? team activity?)
3. Match (type, scope) to a slot:
   - Type has no slot in active vault → write to personal hub
   - Scope has personal markers → write to personal hub (ignore active vault)
   - Type has slot in active vault AND scope is team → write to active project vault
   - Ambiguous → ask
4. Validate the write against the destination vault's schema for that type
5. If schema fails, ask user to clarify or simplify
6. Write via mcp__basic-memory__edit_note or write_note
```

### Personal mode

A session-level flag. Set by `/personal` slash command. When set:
- `.vault/` (encrypted) is unlocked and readable
- Project vault writes are *blocked* (agent refuses, suggests exiting personal mode first)
- A persistent banner shows in agent output

Exiting: `/exit-personal` or end of session.

---

## 9. CLI / agent UX surface

New shell commands:

| Command | Purpose |
|---|---|
| `thinkos vault list` | Show all registered vaults with type, path, status |
| `thinkos vault use <id>` | Sticky-override active vault for this session |
| `thinkos vault create-project <name>` | Create a new project vault (walks through prompts) |
| `thinkos vault clone <git-url>` | Clone an existing project vault, register, index |
| `thinkos vault add-reference <path>` | Register an existing folder as a reference vault |
| `thinkos vault remove <id>` | Deregister (does not delete files) |
| `thinkos vault setup-encrypted` | Create `.vault/` APFS encrypted volume for personal vault |
| `thinkos doctor --git` | Check git install + auth health |

New slash commands (mirror shell commands for in-agent use):

- `/thinkos-vault` — in-chat picker for the vault operations above (Claude Code: text prompts)

---

## 10. Implementation slices (build order)

### Slice 1 (this PR) — Foundation

- `~/.thinkos/vaults.json` registry
- `scripts/thinkos-vault.sh` CLI: `list`, `use`, `create-project`, `clone`, `add-reference`, `remove`
- `scripts/thinkos-git.sh` — git install/auth helper (lazy invocation from vault.sh)
- `scripts/lib/uid.sh` — ULID generator
- `templates/team/` — project vault template directory with the §1.B schema
- `templates/team/.thinkos/schemas/*.schema.json` — JSON schemas per content type
- `templates/team/.gitignore` — excludes `.private/`, `.vault/`, `.thinkos/state`
- `templates/team/CODEOWNERS.template` — owner gating
- `/thinkos-vault` slash command for Claude Code
- Adapter instruction updates (multi-vault awareness, active vault on first response)
- Wizard completion screen mentions multi-vault as next step
- README + AGENTS.md updates
- `docs/multi-vault-architecture.md` (this doc)

### Slice 2 (future PR) — Privacy tiers

- `.private/` automation: setup script writes `tmutil addexclusion`, ensures `.gitignore`
- `.vault/` automation: `thinkos vault setup-encrypted` creates APFS volume, stores key in Keychain
- Personal mode (`/personal` slash command, session flag, write-blocking on project vaults)

### Slice 3 (future PR) — Schema enforcement

- `remark-lint-frontmatter-schema` integration (or pure-bash equivalent)
- Pre-commit hook installed automatically on project vault create
- Agent honors schema at write time
- ULID injection into all new note frontmatter

### Slice 4 (future PR) — Conflict & sync ergonomics

- `thinkos vault sync` (pull + reindex + push)
- `/thinkos-vault resolve-conflicts` agent playbook
- Filesystem watcher for auto-reindex on pull

### Slice 5 (future PR) — Cross-vault search hub

- Federated search across all registered vaults' BM projects
- Result vault-tagging in agent surface

---

## 11. Tradeoffs locked in v1

These are decisions made and locked for the first implementation slice. Future slices can revisit if user feedback warrants.

1. **Personal vault git backup**: not supported in v1. Users wanting backup can `git init` manually; we don't manage it.
2. **`.private/` middle tier**: kept (vs. collapsing to "personal hub OR encrypted only"). The daily-driver "not in backups, no Touch ID friction" tier has real value.
3. **Encryption mechanism**: APFS encrypted volume (vs. `age`-per-file). macOS-native; one Touch ID prompt unlocks everything. Portability is sacrificed for UX.
4. **Schema strictness**: hard block on project vaults, warn-only on personal hub.
5. **Cross-vault search**: deferred. Agent queries personal first, then active project, on its own. No federated layer in v1.
6. **Project vault location default**: `~/ThinkOS/projects/<name>/`. Users can override.
7. **Vault registry storage**: JSON at `~/.thinkos/vaults.json`. Not a database. Read on every command (cheap; small file).
8. **`bm project add` per vault**: each vault is a Basic Memory project. The agent queries them individually (vs. a meta-MCP).

---

## 12. Open questions deferred to user feedback

1. Should the personal hub auto-backup to an encrypted git remote (e.g. private GitHub repo + age-encrypted files)? Punt to v2.
2. How does the agent indicate it's about to write to a shared vault — silent for low-stakes, confirm-on-route for high-stakes? Current rule: silent for `01 Work/`, confirm for `02 Decisions/` and `04 Roster.md`. May tune.
3. When a teammate clones a project vault, do they get any of the personal context their teammates have on the same project? No — that's the privacy guarantee. But it does mean an agent operating in a project vault has zero personal context. Possibly add a "team context overlay" (project-specific personal notes that the user could optionally share). Deferred.
4. Reference vaults — how is their `bm_project` indexed without polluting personal-hub search results? Possibly with a `[REF]` prefix in BM project name and result filtering. Deferred.
5. Linux support. v1 is macOS-only because of APFS encrypted volume + Keychain. `age` fallback path is sketched in §11.3 but not implemented.

---

## 13. Migration path from current single-vault

Existing users (anyone who ran the v0 wizard) have a personal vault at `~/ThinkOS/vault/` with no `~/.thinkos/vaults.json` registry. On first run of any multi-vault command:

1. Detect existing vault at the default path
2. Auto-register it as the personal hub:
   ```json
   {"id": "personal", "type": "personal", "label": "<derived from system username>", "path": "<existing>", "bm_project": "think-os", "default": true}
   ```
3. Tell the user: *"Registered your existing vault as 'personal'. Ready to add project vaults."*

No file moves required; the existing vault works as-is. Schema validation is non-retroactive (existing files aren't checked).
