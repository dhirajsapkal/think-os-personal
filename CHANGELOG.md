# Changelog

All notable changes to Think OS Alpha are documented here. Dates are ISO (YYYY-MM-DD).

## [0.3.3] — 2026-05-13

### Added

- **`/thinkos-automate` slash command** + canonical playbook at `docs/phase-3-automations-playbook.md`. Offers 4 pre-built scheduled triggers (daily reindex, weekly Current Focus review, quarterly archive rotation, optional daily morning brief) via Claude Code's remote-trigger infrastructure (`schedule` skill / `CronCreate` tool). Each opt-in Y/N. Triggers run on Anthropic's infrastructure — no local app needs to stay open.

### Changed

- **README setup section restructured** into three explicit numbered steps:
  - Step 1: Install (paste the one-line prompt)
  - Step 2: Continue setup (`/thinkos-continue` after restart — DO NOT SKIP, flagged emphatically)
  - Step 3: Set up automations (`/thinkos-automate`, optional but recommended)
  
  Previously Phase 2 was a tucked-away bullet under "After install" that users could easily miss. Now it's a top-level numbered step with explicit DO-THIS-NEXT framing.

- **`adapters/claude-code/INSTALL.md` post-install checklist** rewritten with the same 3-step framing (Restart, OAuth, Phase 2, Phase 3). Agents now surface Phase 2 + Phase 3 prominently after install completes, rather than burying them.

### Rationale

The user feedback was that the previous README structure made it too easy to think "install complete = done." It's not — Phase 2 is where Think OS actually becomes useful, and Phase 3 is where it stays useful over time. Both now get unmissable real estate.

On the scheduled-tasks question: Claude Code's remote-trigger model (cloud-side, cron-driven, runs without a local instance) is actually a better fit for "set and forget" maintenance than Cowork's locally-scheduled tasks (which require the app to be running). The phase-3 playbook makes this trade-off explicit.

---

## [0.3.2] — 2026-05-13

### Added

- **`adapters/claude-code/INSTALL.md`** — agent-facing install playbook. Single self-contained file that any AI agent can read and follow to install Think OS for a user. Contains all 5 setup questions (with bracketed defaults), the exact bash commands, and the post-install checklist.

### Changed

- **README install prompt simplified to one line.** Users now paste only `Install Think OS for me from https://github.com/dhirajsapkal/think-os` — the agent clones the repo, finds `adapters/claude-code/INSTALL.md`, and follows it. No more 6-step prompt template.
- **AGENTS.md** leads with "If you're installing, read INSTALL.md and stop reading other docs." Maintenance-focused docs are listed separately.

### Rationale

The previous install prompt was 6 steps long because the prompt itself had to spell out the install procedure. With a canonical playbook checked into the repo, the prompt collapses to the user's intent ("install this") + the repo URL. The agent's first move (clone + read) leads it to the playbook. Less for the user to copy; less to keep in sync between README and reality.

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

The "ship a polished Claude Code experience" release. Focus narrows to Claude Code; Cowork and Codex remain scaffolded for future versions.

### Removed
- **Interactive wizard** (`scripts/thinkos-wizard.sh`). The agent-driven install
  via the chat-based prompt is now the canonical path. Manual terminal users
  can still call `scripts/thinkos-setup.sh` directly with flags. The wizard's
  interactive read-prompts couldn't be driven from Claude Code's Bash tool, so
  the agent-driven install in chat is strictly better UX.

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

- **`templates/instructions/05-global-rules.md`** — non-negotiable NEVER / ALWAYS behavioral rules curated from a survey of well-regarded CLAUDE.md files (Anthropic docs, HumanLayer, ctoth, Glen Rhodes, Joe Cotellese, et al.). Inserted between the priority preamble and token-efficiency rules in the BEGIN/END THINK OS block. Covers destructive ops, scope creep, secrets, drafts-never-send, plan-before-edit, file:line citations, freshness checks, disagreement protocol, and more.
- **Strengthened MCP-first directive** in `00-think-os-priority.md`. New explicit `IMPORTANT: First-action protocol` section with the exact tool calls the agent must make before answering substantive questions. Clear exception list (trivial syntax, generic facts, same-session continuation). The forceful language (MUST, BEFORE, IMPORTANT:) follows documented patterns that measurably improve compliance.

### Changed

- **Slash command rename** — all Claude Code slash commands now use the `thinkos-` prefix (e.g., `/log` → `/thinkos-log`, `/voice-rewrite` → `/thinkos-voice`, `/update` → `/thinkos-reindex`) for discoverability and to avoid collisions with common English words. Descriptions rewritten to be action-first and specific. References updated across all docs, templates, and instruction files.
- **Two new help commands** — `/thinkos-help` (command index with script and doc pointers) and `/thinkos-mcp-help` (Basic Memory query/write tutorial with natural-language examples).

---

## [0.2.0] — 2026-05-13

The "ready to install on yourself" release. Major expansion across three axes: onboarding UX, multi-vault architecture, and curated always-on agent guidance.

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
