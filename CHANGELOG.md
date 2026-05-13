# Changelog

All notable changes to Think OS Alpha are documented here. Dates are ISO (YYYY-MM-DD).

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
