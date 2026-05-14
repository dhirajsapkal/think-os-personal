# Changelog

All notable changes to Think OS Alpha are documented here. Dates are ISO (YYYY-MM-DD).

## [v0.4.2] — 2026-05-14 — Ledger moves into the vault; Cowork can now drive autonomous capture

### Changed

- **Capture ledger relocated** from `~/.thinkos/capture-log.jsonl` to the vault note `90 System/Capture Log.md`. The new file is a markdown note with a short header and JSONL events on subsequent lines (parsers skip lines that don't start with `{`). Existing events migrated automatically by the install path; the old file is renamed to `capture-log.jsonl.migrated` as a safety net.
- **Why**: Cowork agents can write to the vault via `mcp__basic-memory__edit_note` but cannot reach `~/.thinkos/` without filesystem MCP (which is org-blocked for many enterprise Cowork users). Moving the ledger to a vault note gives both surfaces — Claude Code (shell `>>`) and Cowork (`edit_note` append) — first-class write access to the same file.
- **Phase A session capture, Phase B reader (`thinkos-recent.sh`), Phase B doctor checks, and Phase C source playbooks (granola, calendar, gmail, clickup, slack)** updated to read/write the new path. Phase 3 maintenance prompts (weekly-review, quarterly-archive, morning-brief) gained explicit ledger-append steps so events also surface from Cowork-scheduled fires.

### Added

- **Cowork can now drive autonomous capture** via Cowork's native `/schedule` primitive. New section in `adapters/claude-cowork/README.md` documents the workflow: paste any `scripts/cron-prompts/<name>.txt` into a Cowork task, type `/schedule`, pick the cadence. The ledger lives in the vault so both Cowork-scheduled and Claude Code launchd fires merge cleanly in `/thinkos-recent`.
- **Sidecar pattern clarified** — Cowork's `/schedule` requires Claude Desktop to be open. Claude Code's launchd jobs fire whenever the Mac is awake regardless of app state. Users who close Claude Desktop overnight should keep Claude Code as the autonomy driver; users who live in Claude Desktop can choose either.

### Known limits

- **Rotation strategy is TBD.** With the ledger living as a Basic Memory note, the existing `thinkos-capture-rotate.sh` (which gzip-rotated the old JSONL file) is stale. Until rotation is reworked, the ledger note grows append-only — same size budget as any other Basic Memory note.
- **Stale `thinkos-capture-rotate.sh`** kept in the repo for the moment; will be reworked or removed in a follow-up.

## [v0.4.1] — 2026-05-14 — Claude Cowork support (Option A)

### Added

- **Cowork adapter ships as installable** via `bash scripts/thinkos-setup.sh --products claude-cowork --yes`. Auto-edits `~/Library/Application Support/Claude/claude_desktop_config.json` to register `basic-memory` MCP pointing at the user's Think OS project. Backs the original config up with a `.pre-thinkos.<timestamp>.bak` suffix before writing. Refuses to overwrite an existing basic-memory entry that points at a different project — writes a proposed merged config to `~/.thinkos/claude-cowork-mcp-conflict.json` instead so the user can resolve manually.
- **Honest README rewrite at `adapters/claude-cowork/README.md`** — replaces the prior aspirational claims with the post-research reality: Cowork uses a DXT (Desktop Extension) plugin format, not the `~/.claude/skills/` directory that Claude Code uses. We don't ship a DXT yet (would need Anthropic marketplace approval + possible org allowlisting). So Cowork users get vault access via MCP + curated instructions via paste, but no slash commands and no autonomous capture jobs.
- **`adapters/claude-cowork/instructions.md`** — added a "How invocation works in Cowork" section that teaches the agent to match user intent against natural-language patterns ("who am I?", "what's on my plate?", etc.) instead of expecting slash commands. Added a closing note that autonomous capture is Claude Code-only and Cowork users should run Claude Code as a sidecar if they want it.

### Known limits (documented, not bugs)

- No slash commands in Cowork (DXT not built).
- No autonomous capture in Cowork (no equivalent of `claude -p` non-interactive surface).
- One manual paste step during install (Cowork's global instructions field has no scriptable storage path that we could locate).

## [Unreleased] — local launchd correction

### Changed

- Phase 3 maintenance triggers and Phase C continuous capture sources
  now run as local launchd jobs, not remote scheduled triggers. The
  original "remote triggers run on Anthropic infrastructure, your
  laptop can be closed" framing was wrong: remote triggers can't write
  to the user's local personal-hub vault. Local launchd does, with the
  trade-off that jobs only fire when the Mac is awake.
- Trigger registration in the Phase 2 wrap-up and standalone slash
  commands (`/thinkos-automate`, `/thinkos-capture-setup`) now uses
  `bash scripts/install-launchd-job.sh <name>`. The script names and
  prompts are unchanged; only the registration mechanism moved.
- Remote scheduled triggers remain available via the `schedule` skill
  for use cases that fit (project vaults, posting to Slack/email,
  anything that doesn't write to the personal vault).
- Schedule expressions for daily sources changed from UTC cron to local
  time (launchd uses the system clock, no UTC offset needed).

---

## [0.4.0] — 2026-05-14

### Added

- **Continuous capture — three-layer system.** Layer A is live; Layers B and C are opt-in.
  - **Layer A: Session capture.** A launchd job runs every 2 hours and appends a stub entry to `01 Now/Work Log.md` (cwd, file count, last commit). No LLM call. No file contents leave the machine. Toggle via `/thinkos-autosave on|off|status|now`.
  - **Layer B: Audit & trust.** Append-only JSONL ledger at `~/.thinkos/capture-log.jsonl`. `/thinkos-recent` shows captures by source and timestamp. `/thinkos-undo-capture` removes any captured entry from both the vault and the ledger. Four new `capture:*` doctor checks.
  - **Layer C: External ingestion (opt-in per source).** Hourly Granola, daily Calendar/Linear/ClickUp/Gmail, hourly Slack. Per-source filter rules. Keywords (`comp`, `salary`, `HR`, `health`, `family`, `performance`, `1:1`) are privacy-routed to the personal hub only. Configure via `/thinkos-capture-setup`. Source playbooks at `docs/continuous-capture/sources/`.
  - Design docs: `docs/continuous-capture/README.md`, `docs/continuous-capture/session-capture.md`, `docs/continuous-capture/audit.md`, `docs/continuous-capture/capture-log-schema.md`.

- **`/thinkos-update` slash command.** In-place update without re-install. Fetches latest commits, summarizes the diff, detects drift on managed files via sha256, asks before overwriting, and atomically re-applies curated instructions and slash commands. Vault content is never touched. Design doc: `docs/update-protocol.md`.

- **Manifest v2.** `~/.thinkos/install-manifest.json` now carries `managed_files` array, `thinkos_version`, `channel`, `repo_path`, and `last_updated_at`. Migrator: `scripts/thinkos-migrate-manifest-v1-to-v2.sh`.

- **Doctor extension — 4 new `install:*` checks:** manifest-version, version, available updates, and drift on managed files.

- **Phase 1.5 — optional capabilities.** After vault registration but before the post-install checklist, the agent offers a chip-picker for Playwright (browser capture for Phase 2) and GitHub CLI auth (required for project vaults and the `/thinkos-update` flow).

- **Self-healing feedback loop.** When the GitHub CLI is authenticated at install time, the final install screen ends with: "If anything in this install felt off, tell me — I'll open a PR upstream so the next person doesn't hit it." Omitted if `gh` is not authenticated.

- **Declarative install manifest** `setup/manifest.yaml` — source of truth for setup steps, optional capabilities, managed files, and migration paths.

### Changed

- **README setup section** updated to a 3-step flow: Install (5 min, includes Phase 1.5), Restart + authenticate (2 min), Continue setup via `/thinkos-continue` (~15–30 min). "Staying current" section now documents `/thinkos-update` as the primary flow; `scripts/thinkos-update.sh --pull` noted as a non-interactive fallback.
- **`adapters/claude-code/INSTALL.md`** updated with Phase 1.5 step (Step 4.5), self-healing offer (Step 7), and post-install checklist harmonized with the 3-step README framing.

---

## [0.3.3] — 2026-05-13

### Added

- **`/thinkos-automate` slash command** + canonical playbook at `docs/phase-3-automations-playbook.md`. Offers 4 pre-built scheduled triggers (daily reindex, weekly Current Focus review, quarterly archive rotation, optional daily morning brief) via Claude Code's remote-trigger infrastructure (`schedule` skill / `CronCreate` tool). Each opt-in Y/N. Triggers run on Anthropic's infrastructure — no local app needs to stay open.

### Changed

- **README setup section restructured** into three explicit numbered steps: Install, Continue setup (`/thinkos-continue`), Set up automations (`/thinkos-automate`).
- **`adapters/claude-code/INSTALL.md` post-install checklist** rewritten with the same 3-step framing (Restart, OAuth, Phase 2, Phase 3).

---

## [0.3.2] — 2026-05-13

### Added

- **`adapters/claude-code/INSTALL.md`** — agent-facing install playbook. Single self-contained file that any AI agent can read and follow to install Think OS for a user. Contains all 5 setup questions (with bracketed defaults), the exact bash commands, and the post-install checklist.

### Changed

- **README install prompt simplified to one line.** Users now paste only `Install Think OS for me from https://github.com/dhirajsapkal/think-os` — the agent clones the repo, finds `adapters/claude-code/INSTALL.md`, and follows it.
- **AGENTS.md** leads with "If you're installing, read INSTALL.md and stop reading other docs."

---

## [0.3.1] — 2026-05-13

### Added

- **Filesystem indexer** (`scripts/thinkos-index.sh`) — walks user-selected
  project folders and writes `<vault>/.index/projects.json`. Captures per
  candidate: path, slug, tech stack (from manifest sniffing), README first
  paragraph, last git commit (date + subject), top 5 git collaborators
  (last 180d), last modified time. Cheap, deterministic, no MCP / LLM calls.
  Phase 2 reads this JSON to synthesize Project Index drafts.
- **Sanitized Business Brain template** at `templates/05 Profile/Business Brain.md`.
  Built from a Think Co-shared baseline; first-time installs get a populated
  starting point instead of a blank skeleton. Drops all personal references
  (names, clients, projects); keeps company values, voice, methodology.
- **Automation roadmap doc** (`docs/automation-roadmap.md`) — full source
  matrix documenting which sources drive which HOT-tier files, the
  indexer-first pattern, token economics, and the v0.4+ ongoing-update plan.
- **Cowork + Codex scaffolding preserved.** `adapters/claude-cowork/` and
  `adapters/codex/` are restored alongside their entries in the plugin catalog.
  Install integration deferred to v0.4 / v0.5 respectively; the underlying
  script multi-product code paths remain functional but aren't triggered by
  the v0.3 install prompt.

### Changed

- **Phase 2 playbook** (`docs/phase-2-seeding-playbook.md`) adds Section 0a
  "Indexer-first principle" — Phase 2 now dumps deterministic data to disk
  first, then synthesizes from cache. Avoids re-fetching MCP data during
  draft iteration.
- **README + AGENTS.md** clarify the tool support roadmap: Claude Code in
  v0.3, Cowork in v0.4, Codex in v0.5.

---

## [0.3.0] — 2026-05-13

### Removed
- **Interactive wizard** (`scripts/thinkos-wizard.sh`). The agent-driven install via the chat-based prompt is now the canonical path. Manual terminal users can still call `scripts/thinkos-setup.sh` directly with flags.

### Tool support roadmap
- **v0.3 (now)**: Claude Code only. Install flow asks only Claude-Code questions.
- **v0.4 (next)**: Cowork install integration. Adapter files at
  `adapters/claude-cowork/` are preserved in this repo as the design contract.
- **v0.5 (after)**: Codex install integration. Same: `adapters/codex/` preserved.

The underlying scripts (`thinkos-setup.sh`, `thinkos-uninstall.sh`,
`thinkos-doctor.sh`, `thinkos-update.sh`) retain the multi-product code paths
from v0.2 — they're tested, they work, they just don't get triggered by the
default install prompt. A developer can still invoke them with
`--products claude-cowork` or similar for prototyping.

### Changed
- README + AGENTS.md lead with the Claude Code install path. Cowork/Codex
  mentioned as roadmap items.
- Install prompt in the README only asks Claude-Code-relevant questions
  (vault path, Basic Memory, bundle, vault id/label).
- VERSION → 0.3.0.

---

## [0.2.1] — 2026-05-13

### Added

- **`templates/instructions/05-global-rules.md`** — non-negotiable NEVER / ALWAYS behavioral rules. Covers destructive ops, scope creep, secrets, drafts-never-send, plan-before-edit, file:line citations, freshness checks, disagreement protocol, and more.
- **Strengthened MCP-first directive** in `00-think-os-priority.md`. New explicit `IMPORTANT: First-action protocol` section with the exact tool calls the agent must make before answering substantive questions. Clear exception list (trivial syntax, generic facts, same-session continuation).

### Changed

- **Slash command rename** — all Claude Code slash commands now use the `thinkos-` prefix (e.g., `/log` → `/thinkos-log`, `/voice-rewrite` → `/thinkos-voice`, `/update` → `/thinkos-reindex`) for discoverability and to avoid collisions with common English words. Descriptions rewritten to be action-first and specific. References updated across all docs, templates, and instruction files.
- **Two new help commands** — `/thinkos-help` (command index with script and doc pointers) and `/thinkos-mcp-help` (Basic Memory query/write tutorial with natural-language examples).

---

## [0.2.0] — 2026-05-13

### Added

- **Interactive setup wizard** (`scripts/thinkos-wizard.sh`) — DOS-style guided installer with five numbered screens (vault → products → Basic Memory → bundle → review). One question per screen, no pre-selections, only suggestions with bracketed defaults.
- **Phase 2 context-seeding playbook** (`docs/phase-2-seeding-playbook.md`) — after Phase 1 + OAuth + restart, the agent drafts the HOT-tier files (Identity, Project Index, Current Focus, People) from connected tools with per-source consent and citations. State at `~/.thinkos/wizard-state.json` for resumption.
- **State helper** (`scripts/thinkos-state.sh`) — JSON state CRUD for the wizard's phase tracking.
- **Continue script + slash commands** (`scripts/thinkos-continue.sh`, `/thinkos-continue` for Claude Code and Cowork) — resume setup after restart, drive Phase 2.
- **Multi-vault architecture** (`docs/multi-vault-architecture.md`) — personal hub + project vaults (shared via git) + reference vaults (read-only). Privacy enforced structurally: project vault schemas have no slot for personal content.
- **Vault registry CLI** (`scripts/thinkos-vault.sh`) — list / use / create-project / clone / add-reference / remove / migrate.
- **Lazy git helper** (`scripts/thinkos-git.sh`) — only checks git + auth when a project-vault op needs it.
- **ULID generator** (`scripts/lib/uid.sh`) — stable cross-vault link targets.
- **Project vault templates** (`templates/team/`) — 15-file skeleton with JSON Schemas per content type, CODEOWNERS, .gitignore.
- **`/thinkos-vault` slash commands** for both adapters.
- **Curated always-on agent instructions** (`templates/instructions/`) — four-file stack (priority preamble, token-efficiency rules, skill-routing table, write targets) concatenated on top of the adapter-specific instructions inside the BEGIN/END THINK OS block. Refreshable via `thinkos-update.sh`.
- **Update script** (`scripts/thinkos-update.sh`) — pulls latest curated instructions and re-applies the global agent block without re-running the full wizard.
- **Uninstaller** (`scripts/thinkos-uninstall.sh`) — manifest-driven undo with `--dry-run` / `--keep-vault` / `--remove-mcps` / `--all`. Preserves user data by default.
- **Install manifest** — `scripts/thinkos-setup.sh` now writes `~/.thinkos/install-manifest.json` at the end of a successful apply so the uninstaller knows exactly what to undo.

### Fixed

- **PyYAML missing on stock Homebrew Python** — `scripts/lib/catalog.sh` now falls back to a JSON copy of the catalog (`data/plugin-catalog.json`) when PyYAML is unavailable. `scripts/lib/render-catalog.sh` keeps them in sync.
- **`declare -A` on macOS bash 3.2** — `scripts/thinkos-install-bundle.sh` rewrote associative arrays as parallel arrays + helpers.
- **Dry-run output lied "Created:"** — now says "Would create:".
- **`thinkos-vault.sh migrate` only checked default path** — now detects vaults via `basic-memory project list --json` for users with non-standard paths. Accepts `--path` override.
- **`thinkos-vault.sh list` column alignment** — DEFAULT column was empty and shifted neighbors. Fixed with consistent width specifiers.
- **`copy_templates` leaked `templates/team/` into personal vaults** — now properly excluded alongside `templates/instructions/`.

### Removed

- **`scripts/thinkos-preview.sh`** — separate preview tool. The wizard's review step now generates its own summary inline. Less clutter; fewer docs to read.

### Changed

- **Wizard completion screen** — explicit numbered post-install checklist (Cowork wiring, per-app OAuth, restart, Phase 2 continue, optional project vault add). Counts dynamically based on chosen products + bundle.
- **Adapter instructions** — new Multi-Vault Awareness section. Curated stack concatenation order: priority preamble → token-efficiency → skill-routing → write-targets → adapter-specific.
- **README + AGENTS.md** — multi-vault and Phase 2 explained; "Staying current" section added under Guided Setup.

## [0.1.0] — earlier 2026-05

Initial alpha. See git log for details.
