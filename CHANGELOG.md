# Changelog

All notable changes to Think OS Alpha are documented here. Dates are ISO (YYYY-MM-DD).

## [v0.7.6] — 2026-05-18 — Emergent seeding, drift detection, and shared-mode are actually wired now

### Fixed

- **Three "shipped in v0.5.0" features were never actually loaded into the agent.** `40-emergent-seeding.md`, `50-drift-detection.md`, and `60-shared-mode.md` were authored, committed, and described in the v0.5.0 changelog — but were not in `curated_instruction_files()` in `scripts/thinkos-setup.sh` or `scripts/thinkos-update.sh`. The rendered `~/.claude/CLAUDE.md` block had a "Where to look next" pointer claiming all three sections were concatenated below; in reality the script jumped from `30-think-os-write-targets.md` straight to the adapter block, omitting 156 lines of ambient-behavior instructions. The agent therefore: never detected `<!-- thinkos:stub -->` markers on HOT files (emergent seeding silently no-op'd for every new install), never flagged mid-flow drift (expired Current Focus, unknown people, missing project entries), and — most consequentially — **did not enforce shared-mode redaction.** `/thinkos-shared on` toggled the flag file but the read-time filter that hides `tier: sensitive` notes lived only in the unwired instruction block, so screen-sharing users got no protection. All three are now in the wired list, in declared order, before the v0.7.5 bridge block.

### Changed

- **`templates/instructions/README.md` rewritten** to list all eight curated blocks in the actual wired order, with one-line descriptions of what each contributes. The previous "Files present but not currently wired" section (added in v0.7.5 to document the gap rather than fix it) is gone — the gap is the fix.
- **`templates/instructions/00-think-os-priority.md` "Where to look next" section restored** to the 4–7 + bridge + adapter listing that matches what actually gets concatenated.

### Why this matters

The v0.5.0 release notes said: *"emergent seeding + drift detection + shared-mode + capture consolidation."* The first three of those were lying — the code was there, the docs claimed it shipped, but the wiring was missing and no install since v0.5.0 (six minor versions, ~four months) ever ran the behaviors. Shared-mode is the load-bearing one: a user toggling `/thinkos-shared on` before a screen-share would have reasonably trusted that sensitive notes were now hidden. They weren't.

The fix is a six-line change to two scripts plus the docs that should have always matched them. Total instruction-block size grows from ~390 lines to ~530 lines per session — a real token cost on the cache miss, amortized across cached turns. The alternative (deleting the unused blocks) would have removed actual claimed product behavior, so this is the smaller change.

A separate observation, recorded here so it doesn't get lost: if any of these three blocks turns out to be low-value in practice, the right move is to delete the block from `templates/instructions/` and from the script list at the same time. The shape we want to avoid is the previous one — feature documented, code shipped, wiring forgotten.

## [v0.7.5] — 2026-05-18 — Agent-side bridge awareness (so future Claudes don't tell you Slack is unavailable)

### Fixed

- **`/thinkos-mcp-help` was priming Claude to misread Slack/Gmail/Calendar as unreachable.** The "Freshness and the index" section ended with a flat line: *"The index does NOT pull new data from connectors (email, Slack, calendar). That's the desktop agent's job."* True statement about the vault index — but a separate Claude session loaded the skill, quoted that exact line back, and concluded the agent itself couldn't reach Slack (it could, via the claude.ai bridge — `claude mcp list` showed the connector was active and `mcp__claude_ai_Slack__slack_send_message` was loadable via `ToolSearch`). Section rewritten as "Vault index vs. runtime tools — two separate surfaces" with an explicit table contrasting `mcp__basic-memory__*` (what's captured in the vault) and `mcp__claude_ai_*` (what the agent can call live), and a final sentence: *"'The vault doesn't have your Slack messages yet' and 'the agent can't reach Slack' are different statements."*

### Added

- **`templates/instructions/70-claude-ai-bridge.md`** — new always-on instruction block, ~55 lines, wired into the curated stack so it concatenates into every rendered `~/.claude/CLAUDE.md`. Covers: what the bridge is, what `claude mcp list` entries with `claude.ai *` prefix mean, how deferred-tool loading works (`ToolSearch select:<name>` vs `ToolSearch query="<topic>"`), the index-vs-runtime distinction, a checklist to run before telling the user "X is unavailable", and the fallback when the bridge genuinely isn't present.
- **`curated_instruction_files()` in `scripts/thinkos-setup.sh` and `scripts/thinkos-update.sh`** updated to include `70-claude-ai-bridge.md` after the write-targets block. The pointer in `00-think-os-priority.md`'s "Where to look next" section was also updated to reference it as section 5.

### Changed

- **`templates/instructions/README.md`** updated to reflect the new wired-list order. While there, called out explicitly that `40-emergent-seeding.md`, `50-drift-detection.md`, and `60-shared-mode.md` exist in the directory but are NOT wired into the concatenation — their behaviors ship through the corresponding skills/commands. (This was a pre-existing gap between the docs and the code; the previous priority preamble promised those blocks were included when they weren't. The pointer in `00-think-os-priority.md` was also corrected to only list what's actually concatenated.)

### Why this matters

The trigger: a real Claude Code session said to the user *"Claude Code CLI does not have Slack tools exposed... Think OS itself does not provide Slack access... Per /thinkos-mcp-help: 'The index does NOT pull new data from connectors.'"* That was wrong on the second point and wrong on the third — but the reasoning was *anchored in the Think OS docs*. The skill correctly described the index but didn't draw a clear line between "what's captured" and "what the agent can call." A future Claude that doesn't know about the claude.ai bridge will reach for the most authoritative-looking source it has, which is the ThinkOS skill, and conclude the same wrong thing.

The bridge block fixes the upstream problem: every session now starts with explicit guidance that `mcp__claude_ai_*` tools exist as deferred tools, that they need `ToolSearch` to load before being callable, and that the vault index's coverage gaps are not evidence the agent can't reach those services. The rewritten skill closes the secondary leak — even if a future Claude only loads `/thinkos-mcp-help` and not the full curated block, the wording no longer biases it toward the wrong conclusion.

This is a small content release. No new scripts, no behavioral changes to existing commands, no migration needed. Existing installs pick up the new block on the next `/thinkos-update`.

## [v0.7.4] — 2026-05-18 — Onboarding connector wiring + claude.ai bridge awareness

### Fixed

- **Placeholder MCP URLs in `data/plugin-catalog.yaml` replaced with verified endpoints.** Eight entries had `TODO: verify` comments next to dummy URLs that would have failed on first connection if anyone had actually completed the local install (instead of getting silently skipped — see below). Updated: `gmail` → `https://gmailmcp.googleapis.com/mcp/v1`, `google-drive` → `https://drivemcp.googleapis.com/mcp/v1`, `google-calendar` → `https://calendarmcp.googleapis.com/mcp/v1`, `atlassian-rovo` → `https://mcp.atlassian.com/v1/mcp`, `hubspot` → `https://mcp.hubspot.com/anthropic`, `quickbooks` → `https://ai-inc.quickbooks.intuit.com/v1/mcp`, `pubmed` → `https://pubmed.mcp.claude.com/mcp`, `zoom-claude` → `https://mcp.zoom.us/mcp/zoom/streamable`. Verified by reading the actual `claude mcp list` output of a running Claude Code session with the claude.ai marketplace connected. The remaining TODOs (ms365, linear, asana, monday, fireflies, otter, amplitude, pendo, similarweb, intercom) stay marked unverified — no shipped users hit them in the four canonical presets, and there's no working endpoint to confirm against yet.
- **`scripts/thinkos-install-bundle.sh` was silently skipping every Google/Slack/Notion install on machines signed into claude.ai.** The `_mcp_already_registered` helper fell back to a loose substring `grep -q "${mcp_name}"` against the full `claude mcp list` output. Entries from the claude.ai marketplace bridge appear as `claude.ai Gmail: https://gmailmcp.googleapis.com/...` — searching for the literal `gmail` matched the URL substring `gmailmcp`, the bash function returned 0, and the installer logged `SKIPPED: 'gmail' already registered`. The user-visible effect: the install manifest claimed gmail/slack/notion/granola were installed; `~/.claude.json mcpServers` had none of them. Replaced with a strict anchored check `^<mcp_name>:` and a separate `_mcp_provided_by_bridge` probe that explicitly looks for `^claude.ai <Display Name>:`.
- **`google-calendar` missing from every preset.** It was in the catalog but no preset (pm/eng/design/ops) included it. Anyone who picked a bundle and expected "Claude can see my calendar" got nothing — and `/thinkos-morning`'s calendar pull silently fell back to no-data. Added to all four presets. `google-drive` added to pm/eng/design (ops covers Drive via ms365/OneDrive).

### Added

- **`bridge_match` field on catalog entries (optional).** When set, names the exact `claude.ai <Display Name>` row in `claude mcp list` that the bridge provides for that service. The installer reads it to detect bridge intercepts and report a new `BRIDGE: provided by claude.ai (<name>)` status instead of attempting a duplicate `claude mcp add`. Entries with bridges: slack, gmail, google-calendar, google-drive, notion, airtable, atlassian-rovo, clickup, granola, zoom-claude, canva, hubspot, zoominfo, quickbooks, pubmed. Figma is intentionally not bridged (no claude.ai marketplace entry exists yet) — it stays as a local install.
- **Distinct "Already provided by the claude.ai marketplace bridge" section in the installer summary.** Previously, bridge-intercepted items either fell through to a fake-success local install (after the TODO URL fix would have surfaced auth failures), or appeared as a confusing `SKIPPED` line with no explanation. The new section names each bridged item, points at the `mcp__claude_ai_<Service>__*` tool namespace, and tells the user what to do if they later want a CLI-only install instead.
- **`claude mcp list` output now cached per installer run.** Each call hits every MCP for a health probe and can take 5–15 seconds on a full preset. The previous code called it three times per item (10 items × 3 = 30 probes). Now loaded once; reused for both local-registered and bridge-provided checks.

### Changed

- **`setup/manifest.yaml` bundle descriptions updated** to list Google Calendar and Google Drive in the pm/eng/design rows (ops already mentioned Microsoft 365 which covers OneDrive). These strings show in the install wizard chip-picker, so a user reading "Slack, Gmail, Google Calendar, Google Drive, Notion, Figma, Granola + Design and Productivity skills" sees what they will actually get.

### Why this matters

The bug surfaced when a user said: "ThinkOS onboarding doesn't connect Claude Code with Gmail/Calendar — it can't read them." Diagnosing it turned up three independent failures on the same path: a catalog with placeholder URLs nobody had verified, a preset bundle that omitted calendar entirely, and an installer whose "already registered" guard was loose enough to mask the previous two issues by silently no-op'ing in the most common environment (a user signed into claude.ai). Each failure on its own would have shown up in testing. Together they produced a "success" output that hid the entire failure mode.

The fix tightens the installer's contract: a local install attempt either succeeds with a working URL, gets cleanly deferred to the bridge, or fails loudly. The catalog now distinguishes "we install this locally" from "claude.ai provides this for free" with a single declarative field. And the user-facing summary tells the truth about what is and isn't wired up.

## [v0.7.3] — 2026-05-15 — Fabricated demo persona scrubbed from website

### Fixed

- **`ConversationStrip` and `VaultTree` components on the website were rendering a fabricated bio for the maintainer** ("Dhiraj — Director of AI Engagement at Think Company, Philadelphia, Designer background, eight years across consultancy and in-house...") along with invented current work ("Q3 internal AI roadmap to Maya by Friday", "two stuck performance reviews"). None of that was true — the implementation agent invented a persona while trying to ground the demo in real names. Replaced with a clearly fictional persona (Sam Reyes — Engineering Lead at Cardinal Studio, Brooklyn) and tightened the disclaimer line under the conversation strip to "Sample vault content. Sam Reyes and Cardinal Studio are fictional — your real vault has your real notes." The legitimate references that remain on the site ("Designed and built by Dhiraj Sapkal" in the footer; "Built at Think Company" in the trust bar; the Think Company logo) are actually true and stay.

## [v0.7.2] — 2026-05-15 — Changelog anchors + RSS link cleanup

### Fixed

- **`/changelog` page now has working anchors** for each release. Previously, links like `/changelog/#v0-7-0` resolved nowhere because the rendered `<article>` elements had no `id` attribute. Each entry now carries `id="v0-7-0"` (etc.), and `scroll-mt-24` keeps the target from landing under the header. The version stamp in each entry is now a self-link — click it to copy the per-release URL.
- **RSS link normalization**. `@astrojs/rss` was emitting URLs like `https://thinkos.dev/changelog/#v0-7-0/` with a trailing slash *after* the fragment, which some feed readers tolerated and some treated as a broken link. The slash came from the package's `new URL(link, site)` normalization; the feed now constructs URLs explicitly with `new URL('/changelog/', site)` and appends the fragment after — output is clean `https://thinkos.dev/changelog/#v0-7-0`.

### Added

- **`:target` flash on changelog anchors.** When you land on `#v0-7-0`, the entry briefly highlights so the eye finds it. Respects `prefers-reduced-motion` — no animation if the user has it set.

## [v0.7.1] — 2026-05-15 — Documentation truth pass + website refresh + public changelog

### Added

- **`/changelog` page on the website** rendered from a new Astro content collection (`website/src/content/changelog/`). Five entries — v0.4.4, v0.4.5, v0.5.0, v0.6.0, v0.7.0 — newest-first, each with a 3-bullet highlights section, 1–3 short paragraphs for headline features, flat list for smaller items, and an "Upgrade" footer. Different from `CHANGELOG.md` in purpose: this one is the public, user-facing read; CHANGELOG.md stays the maintainer-facing inventory.
- **RSS feed at `/rss.xml`** generated from the changelog content collection. Linked from `BaseLayout.astro` `<head>` so feed readers auto-discover it. ISO datetimes with hour granularity used in frontmatter so reverse-chronological sort is stable.
- **Five new website components.** `ConversationStrip.astro` (three-panel realistic Claude Code transcript showing cold-start vault read, mid-flow capture offer, `/thinkos-morning` output — uses real `mcp__basic-memory__*` tool names, no fabrication), `VaultTree.astro` (CSS-only folder structure with two files "open" showing realistic frontmatter from `templates/05 Profile/Identity.md` shape), `TrustBar.astro` (one-line mono: `v0.7.0 · Built at Think Company · Open source on GitHub`), `WorksWith.astro` ("Plays well with" row — Claude Code · Basic Memory · Granola · Calendar · Slack · Gmail · Linear · Notion · GitHub), `ChangelogPreview.astro` (quiet "See what's new →" line below the install prompt).
- **OG image** at `website/public/og.png` (1200×630, rendered from `og.svg` via `qlmanage` + `sips`). `og:image` and `twitter:image` meta tags wired into `BaseLayout.astro`.
- **`Changelog` link in the header nav** between Docs and GitHub.

### Changed

- **Website version stamps corrected.** Header was `v0.4 · alpha`, Footer was `v0.4.2 · alpha`. Both now `v0.7.0 · alpha`.
- **Website slash-command list regrouped into six workflow groups** instead of a flat 24-entry list. Groups: Morning ritual, Capture & recall, People & projects, Vault health & maintenance, Setup/lifecycle/automations, Discovery. `/thinkos-vitals`, `/thinkos-sync`, `/thinkos-shared` added. `/thinkos-log`, `/thinkos-decide`, `/thinkos-save` explicitly labeled as aliases. Footer note added pointing at `~/.claude/commands/` to surface that commands are plain editable markdown files.
- **Website FAQ "which agent surfaces does Think OS support?"** rewritten — removed the v0.4 Cowork-support claim, pointed at the `roadmap/cowork-codex` branch.
- **Website hero subhead** reframed to lead with human behavior ("durable memory of who you are, what you're working on, and how you like to work") instead of infrastructure terms.
- **Documentation sweep across 12 files** to reflect current v0.7.0 state:
  - `README.md` — version stamp `v0.4.1` → `v0.7.0`; Step 3 reframed from "DO NOT SKIP THIS / the step that makes Think OS actually useful" to opt-in emergent seeding as the default
  - `AGENTS.md` — body updated; curated-instructions list now includes blocks 40/50/60 with descriptions
  - `MAINTENANCE.md` — "Stop hook" replaced with the accurate launchd job; `/thinkos-vitals` added to the on-demand freshness checks
  - `LIMITATIONS.md` — `/thinkos-index-projects` (a command that doesn't exist) replaced with `bash scripts/thinkos-index.sh` and the `/index-projects` skill
  - `adapters/claude-code/INSTALL.md` — Step C reframed: emergent seeding default, `/thinkos-continue` opt-in; "DO THIS NEXT" imperative removed
  - `docs/agent-setup-playbook.md` — Step 3 updated to match the new opt-in framing
  - `docs/automation-roadmap.md` — implementation-status section updated (indexer shipped, continuous capture shipped, Phase 2 opt-in)
  - `docs/multi-vault-architecture.md` — Slice 2 marked `tier:` + `/thinkos-shared` as shipped in v0.5.0; Slice 4 marked `/thinkos-sync` as shipped in v0.6.0
  - `docs/setup-basic-memory.md` — cross-machine bullet now references `/thinkos-sync` and the opt-in launchd job instead of "choose an explicit sync strategy"
  - `docs/update-protocol.md` — channel-switch example bumped from `v0.4.0` to `v0.7.0`
  - `docs/continuous-capture/{capture-log-schema.md,sources/README.md}` — "Cowork `/schedule`" references generalized to "MCP-based writer"
- **`website/astro.config.mjs`** — added `site: 'https://thinkos.dev'` (required by `@astrojs/rss`).

### Why this matters

The three earlier releases this cycle shipped a lot of real surface (vitals, sync, emergent seeding, shared mode, capture consolidation, the scaffolding cut), but the docs and website were narrating an older version of the product. A new visitor reading the README or the landing page wouldn't have seen most of what changed.

v0.7.1 closes that gap. Same week's shipping, now reflected in everything a reader actually reads first: the README's version stamp, the website's hero, the commands table, the FAQ that no longer overpromises Cowork. The public `/changelog` page (+ RSS) gives ongoing releases a surface that doesn't require reading a maintainer-facing markdown file — and gives the project a "active" signal that quietly compounds over time.

Pure documentation + presentation release. No code paths changed; no manifest entries added; existing installs see zero drift from this release.

## [v0.7.0] — 2026-05-15 — Cowork/Codex moved to roadmap branch

### Removed

- **`adapters/claude-cowork/` and `adapters/codex/` trees deleted from `main`.** Preserved verbatim on the new long-lived branch `roadmap/cowork-codex` for future cherry-pick when their plugin formats stabilize.
- **`setup/manifest.yaml`:** `codex-block` managed-files entry removed.
- **Scripts cleaned (`thinkos-update.sh`, `thinkos-doctor.sh`, `thinkos-setup.sh`, `thinkos-uninstall.sh`, `thinkos-continue.sh`, `thinkos-migrate-manifest-v1-to-v2.sh`):** Cowork/Codex branches removed from `usage()` blocks, `--products` help, `all`-expansion, manifest writer/reader, install/uninstall function definitions, and call sites. Each script gained one `# Cowork/Codex adapters cut in v0.7.0 — see roadmap/cowork-codex branch.` comment marker so future grep-archaeology lands on the cut. `bash -n` passes on every modified script.
- **`thinkos-uninstall.sh` dead plumbing pruned** (`M_CODEX_MCPS` variable, `cx_bm` flag, codex branch in manifest-reader Python, terminal-empty-detection conditional). The codex code path was emptied in the initial scrub but the surrounding variable still threaded an always-empty value through three call sites — now fully removed.
- **`docs/update-protocol.md`:** Cowork reapply path and Codex managed-file example removed; product list resolved to `claude-code` only.

### Changed

- **`README.md`:** "Tool support roadmap" callout removed; Product support table removed; adapters tree diagram reduced to `claude-code/`; one-line pointer added below Staying Current: "Cowork and Codex scaffolding lives on the `roadmap/cowork-codex` branch — cherry-pick when their plugin formats stabilize."
- **`AGENTS.md`:** "Roadmap (not active in v0.3)" paragraph replaced with the same one-line roadmap pointer.
- **`LIMITATIONS.md`:** "Out of scope" header retitled; "Claude Code only" bullet rewritten to point at the roadmap branch.
- **`docs/automation-roadmap.md`:** "Cowork + Codex install integration" bullet removed from the Future roadmap section.
- **Website (`website/src/pages/index.astro`, `website/src/layouts/BaseLayout.astro`):** hero subhead, FAQ answer for agent-surface support, footer chip, and the shared `<meta description>` all updated to drop Cowork/Codex framing and reference the roadmap branch.

### Why this matters

Dormant adapter scaffolding for Cowork and Codex was carrying real cost: grep noise across the repo, six scripts with dead branches, `--products` flags that listed surfaces the installer couldn't reach, and a website front page that promised Cowork support. None of it was active code; all of it was load-bearing on user trust.

Cutting it doesn't lose work — the full tree lives on `roadmap/cowork-codex` and is one `git cherry-pick` away when either Cowork's plugin format stabilizes (it doesn't yet) or Codex grows install ergonomics worth automating. What it does buy: a `main` branch where every shipped surface actually works, scripts with no dead arms, and a website that matches the tree.

This release is pure subtraction. No new commands, no new behavior — just a cleaner load-bearing surface for the next thing.



## [v0.6.0] — 2026-05-15 — Vitals + cross-machine sync

### Added

- **`/thinkos-vitals` — vault-health snapshot.** New script `scripts/thinkos-vitals.sh` plus slash command. Reports per-HOT-file `last_reviewed` age vs. today, `covers_week` expiry, WARM-file mtime staleness (>30d threshold), line counts vs. budgets (Project Index 200, People 300, Current Focus 200, Identity 150 — overrideable via frontmatter `budget:`), unreviewed-autocapture count from `90 System/Capture Log.md` (`source != manual` AND `reviewed: true` absent, last 30 days), ledger volume 7d/30d, broken cross-links (wikilink + Markdown link patterns) scoped to HOT files + `02 Projects/*.md`, and section ages for append-only logs (`Decisions.md`, `Learnings.md`, `Work Log.md`). Two output modes: `--json` for tooling, default human-readable for terminals. Robust on empty/stub vaults — emits `status: stub` instead of crashing. New doc: `docs/vitals-design.md` (rationale for why vitals is separate from doctor; full JSON schema; heuristic catalog).
- **`/thinkos-vitals` chip-picker follow-through.** After surfacing the report, offers four actions: "Address oldest stale file" → routes through `/thinkos-capture --mode session-recap`; "Mark autocaptures reviewed" → one-by-one prompts to set `reviewed: true` via Basic Memory `edit_note`; "Fix broken links" → list-and-decide flow per link; "Just close".
- **`/thinkos-sync` — cross-machine sync, first-class.** New slash command + new `sync-vault` subcommand on `scripts/thinkos-git.sh`. Behavior: `git status --porcelain` short-circuit on clean+up-to-date; auto-commit unstaged changes with `chore(vault): sync <YYYY-MM-DD HH:MM>` (overrideable via `--message`); `fetch && pull --rebase`; `push`. **Merge conflicts pause to the user — never auto-resolved.** Recovery options surfaced verbatim: edit and re-sync, or `git rebase --abort`. Flags: `--vault <path>`, `--message <msg>`, `--dry-run`.
- **Opt-in launchd job for scheduled vault sync.** `scripts/install-sync-job.sh` + `scripts/uninstall-sync-job.sh`, mirroring the `install-session-capture.sh` pattern. Plist template at `templates/LaunchAgents/com.thinkos.sync.plist.template`. Default schedule: weekday 18:00 local (end-of-workday) — single fire per workday, matches the existing daily-reindex / weekly-review cadence. `RunAtLoad: false` so installation doesn't immediately fire. Idempotent (unloads existing plist before reloading). Customizable by editing the rendered plist post-install. New doc: `docs/cross-machine-sync.md` covers UX, conflict handling, multi-machine notes (each machine runs its own Basic Memory index — reindex on next session pulls in remote-pushed notes), and non-git alternatives.

### Changed

- **`LIMITATIONS.md` cross-machine bullet rewritten.** "Cross-machine sync is now first-class via `/thinkos-sync` (manual) or the opt-in launchd job (default 18:00 weekdays). For non-git sync strategies (Syncthing, iCloud), see `docs/cross-machine-sync.md`." Other limitations bullets preserved verbatim.
- **`README.md` Slash commands table updated.** Adds `/thinkos-vitals`, `/thinkos-sync`, and (deferred from v0.5.0) `/thinkos-shared`. Recasts `/thinkos-log`, `/thinkos-decide`, `/thinkos-save` as "soft alias → /thinkos-capture --mode X" entries. Adds a "multi-machine sync" sentence to the "Staying current" section pointing at `/thinkos-sync` and the launchd installer.

### Why this matters

Cross-machine sync was the highest-pain unsolved item in `LIMITATIONS.md` — punted to the user with "choose an explicit sync strategy." Now there's a first-class option that integrates with the existing launchd cadence pattern and pauses cleanly on conflict instead of silently breaking. Two-machine round-trip on the personal hub takes one command (or zero, if you install the job).

Vitals fills a different gap: the OS could rot silently before this release. Stale `Current Focus`, growing autocapture backlog, broken cross-links — none of it visible until you ran `/thinkos-stale` (narrow) or `/weekly-review` (Sunday-only). `/thinkos-vitals` makes vault health a queryable surface, so the OS itself has a reason to flag its own decay.



## [v0.5.0] — 2026-05-15 — Emergent seeding + drift detection + capture consolidation + shared-mode

### Added

- **Emergent seeding (curated rule block `40-emergent-seeding.md`).** HOT files now fill in from natural conversation over the first few real sessions. Shipped HOT-file templates (`Identity`, `Project Index`, `Current Focus`, `People`) carry a `<!-- thinkos:stub -->` marker so the agent can detect empty state, draft proposals from conversation, and propose-then-save with explicit confirmation. Per-file draft state lives in `~/.thinkos/emergent-state.json`. Capped at 3 deferrals per file before going silent. New doc: `docs/emergent-seeding.md`.
- **Agent-initiated drift detection (curated rule block `50-drift-detection.md`).** The agent flags four contradiction types mid-flow — Identity vs. recent Work Log, stale `covers_week`, unknown-person mentions, project not in index — with a bounded one-line nudge. Auto-muted after `/weekly-review` until the next Sunday, and silent in shared-mode. Max one nudge per session, max one re-surface per topic per week. New doc: `docs/drift-detection.md`.
- **Cost-of-context skip rule** in `00-think-os-priority.md`. Conservative exception: when CWD is a registered project AND the question is project-local factual (no first-person pronouns, no identity/focus/decisions/learnings keywords), the agent skips the two mandatory first-action MCP reads. False negatives (skipping when context would have helped) are recoverable; false positives are not — so the heuristic biases conservative. New doc: `docs/cost-of-context-heuristic.md` with 10 worked examples.
- **Privacy tiers + shared-mode (curated rule block `60-shared-mode.md`).** New optional `tier: standard | sensitive` frontmatter field (default `standard`). When shared-mode is active, the agent post-filters search results to drop `tier: sensitive` notes and refuses reads with a redaction message. Activation: presence of `~/.thinkos/shared-mode` flag file, or `THINKOS_SHARED=1` env var (env overrides file). New slash command `/thinkos-shared on|off`. Writes are unaffected by shared-mode. New doc: `docs/privacy-tiers.md`.
- **Three new entries in `setup/manifest.yaml` `composed_with`** for the new curated instruction blocks. Existing v0.4.5 baseline-refresh on update absorbs the change cleanly — users on v0.4.5 → v0.5.0 see one expected drift on `~/.claude/CLAUDE.md` (the BEGIN/END block), no false drift on existing slash commands.

### Changed

- **Capture surface consolidated to one canonical command.** `/thinkos-capture` is now the canonical multi-type handler with type inference: decision (verb phrasing like "from now on", "we'll always") → learning ("noticed that", generalizable) → log (first-person past-tense single event) → session-recap (multi-paragraph or empty $ARGUMENTS). `/thinkos-log`, `/thinkos-decide`, `/thinkos-save` reshaped as ~14-line soft aliases that set the `--mode` and delegate, with a one-line hint shown once per session ("Routing through /thinkos-capture — same behavior, one fewer command to remember"). Vault output format unchanged per type. **v0.4.4 topic-overlap dedup semantics preserved verbatim** in the session-recap section (Step 0a triage + Step 0b semantic-overlap check + ledger `topic` field).
- **`/thinkos-continue` reframed: Phase 2 is now opt-in.** The playbook content is unchanged for users who explicitly invoke `/thinkos-continue`; the default onboarding path is now emergent seeding. `docs/phase-2-seeding-playbook.md` gains a top-of-file note explaining the new positioning.
- **README "Step 3 — DO NOT SKIP THIS" framing retired** (deferred to a follow-up README pass). The product now defaults to empty-templates-then-emerge, with `/thinkos-continue` available as an opt-in bulk-seed path.

### Why this matters

Two structural shifts. First, **onboarding stops being a 30-minute wall.** The previous Phase 2 step was framed as required; users who didn't complete it got an empty-feeling vault and an under-personalized agent. Emergent seeding inverts the contract: start empty, let the agent surface what it learns, save on confirmation. Phase 2 is still there for power users with rich connector data — it just isn't blocking.

Second, **the capture surface stops fragmenting.** Four slash commands (`log`, `capture`, `decide`, `save`) became four ways to do the same thing. Now there's one canonical name with three soft aliases that keep working forever. Reduces decision fatigue without breaking muscle memory.

Drift detection and shared-mode are smaller but pay compounding interest: the OS catches its own stale state without waiting for `/weekly-review`, and you can hand a screen to a collaborator without leaking 1:1 notes.



## [v0.4.5] — 2026-05-15 — Drift handling: auto-baseline refresh + system-caused drift option

### Fixed

- **`scripts/thinkos-update.sh` now refreshes the install-manifest baselines at the end of every run.** Previously, `shipped_sha` values were only updated during the v1→v2 migration; subsequent `--skip-pull` runs touched files but left stale baselines, accumulating false-positive drift over time. Each successful update now recomputes `shipped_sha` + `current_sha` for every managed file, bumps `thinkos_version` to the current git HEAD, and updates `last_updated_at`. Idempotent and respects `--dry-run`.

### Added

- **`/thinkos-update` playbook now offers four chip options when drift is detected** (was three): "Back up and replace" (safe default), "Just replace, no backup" (new — for system-caused drift cases or when bloat avoidance matters more than rollback safety), "Keep mine", "Show diff first". The playbook explains when system-caused drift is likely so the user can choose the no-backup path without guilt.

### Why this matters

Yesterday's first real `/thinkos-update` test surfaced both quirks: drift was reported on a file the user never touched (baseline lag), and the only path forward forced a backup of a stale intermediate version. v0.4.5 closes both gaps — drift detection now reflects reality, and the user has a clean path for cases where the safe-default backup is just noise.

## [v0.4.4] — 2026-05-15 — Multi-instance dedup fix

### Changed

- **`/thinkos-save` Step 0 now uses topic-overlap comparison instead of blunt timestamp proximity.** The original logic blocked on ANY recent `source: manual` event in the ledger and surfaced "recent save detected — save anyway?" prompts even when the recent save was from a concurrent session doing unrelated work. New flow: triage candidates silently with topic slugs (Step 0a), then check for *semantic* overlap with recent ledger topics (Step 0b). Only prompt the user when topics actually overlap; otherwise proceed silently. Per-draft chip-pickers in Step 1 are still the user's final approval gate.
- **Step 3 ledger event template now explicitly requires the `topic` field** in `detail`. This is what enables future invocations to detect overlap without re-reading vault content.

### Added

- **Multi-instance awareness rule in the curated priority preamble** (`templates/instructions/00-think-os-priority.md`). New core operating rule: "Multi-instance Claude is normal. Shared state will reflect activity from other concurrent sessions. For any dedup check, compare semantic overlap, not timestamp proximity." Applies to `/thinkos-save`, `/thinkos-log`, `/thinkos-decide`, `/thinkos-capture`, and any future capture-dedup logic — gets it right at the platform layer, not per-command.

### Why this matters

Users routinely run Claude Code in several terminals, Cowork tabs, Desktop, and mobile across a day. Each instance writes to the same vault and ledger. The original dedup logic treated parallel work as duplication — false-positive prompts that erode trust faster than occasional small redundancies. The fix aligns the agent's behavior with how the OS is actually used.

## [v0.4.3] — 2026-05-14 — `/thinkos-save` — manual substance capture

### Added

- **`/thinkos-save`** — new slash command that captures the substance of the current session (Work Log + Decisions + Learnings + People entries) with per-item chip-picker approval. Complementary to the autosave launchd job, which captures metadata (cwd, file counts, commits) every 2h. Autosave handles "what files were touched"; `/thinkos-save` handles "what was decided / learned / shipped."
- The playbook checks for recent manual saves (last 30 min) to avoid duplicates; routes everything to the personal hub vault; appends ledger events with `source: manual` and `via: thinkos-save` so the audit trail differentiates manual saves from automated captures.
- Privacy filter applies (comp/HR/health/family/etc.) — entries land in the vault but ledger detail is redacted.

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
