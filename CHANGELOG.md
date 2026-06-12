# Changelog

All notable changes to Think OS Alpha are documented here. Dates are ISO (YYYY-MM-DD).

## [v0.9.7] — 2026-06-12 — Cause, then effect: the homepage scenes learn to tell their story in order

Client-note revision pass on the Live Session site. Every animated scene is now a sequenced story — nothing renders before its trigger. A step engine walks each scene's beats on entry: in The Read, you say good morning, an annotation notes it runs /thinkos-morning, the connector draws, the two vault files light up as read, and only then does the answer print, with numbered beat badges narrating. The try-it terminal is now genuinely typeable: free-typed input matches four demos (including a log demo that writes your own words into a Work Log diff with a file side-effect chip), with a graceful fallback for everything else. CommandStage tabs replay their vignette as cause-then-effect. Homepage copy cut roughly a third — captions over paragraphs, a file-grid graphic replacing a sentence about files. Reduced-motion and no-JS still render everything static and complete.

### Changed

- Scene choreography: new step engine in BaseLayout (IntersectionObserver, once-only, per-step durations); Scenes 2/3/5 and the Pair connector wired to it; beat badges added.
- TryTerminal: real prompt input (Enter runs, Escape clears), four matched demos + unknown-input fallback, log demo echoes sanitized user text via textContent, Work Log side-effect chip.
- CommandStage: JS replay engine (cancellable) — command types, response prints, file effect lights last; ARIA tablist unchanged.
- Homepage copy diet: hero subhead, scene captions, flow nodes, trust cards, setup steps, two FAQ answers; FlowDiagram gains an optional per-node file-chip grid.

## [v0.9.6] — 2026-06-12 — Website 2.0, for real: a new visual world, scroll as narrative, and two things you can click

A website-only release — nothing outside `website/` changes; no scripts, templates, instructions, or playbooks are touched (verify with `git diff --stat`). v0.9.5 changed the *content* — every beat became a two-pane Pair — but a client's read was blunt: it still looked like version 1. Same typography, same centered-prose layout, same light-paper-with-navy palette. The content had moved on; the design hadn't. This release makes the departure mechanically visible. The type system changes (Newsreader display / Hanken Grotesk body / IBM Plex Mono are retired; **Bricolage Grotesque** carries display and body, **JetBrains Mono** carries the machine voice — both self-hosted via fontsource). The color world changes (the default is now a dark "live session" — the site reads as a terminal viewed at night, file-panes glow as lit phosphor artifacts; the warm-paper world survives as "The Printout," the second theme behind the toggle). The layout grammar changes (no more centered prose column with a kicker-and-heading rhythm — the homepage is a sequence of full-bleed SCENES timestamped across one workday, and scroll is the engine that plays them). The good bones from v0.9.5 — `Pair`, `TerminalPane`, `FilePane`, `DiffPane`, the typewriter CSS — are restaged and restyled inside the new world, not thrown away. The verified copy stays the copy.

### Added

- **A dark-first "Live Session" visual world** (`website/src/styles/global.css`, rewritten head-to-foot; `website/tailwind.config.cjs`). The default `[data-theme="dark"]` is a night-terminal room (`--bg #0A0F0C`) where panes are lit bodies with a faint phosphor bloom (`--accent #56D99F`), a fixed dotted `.field` grid gives the room its texture, and selection/focus rings glow green. The light theme is recast as **"The Printout"** — warm paper (`--bg #F4F1E6`), the same artifacts as if run to a sheet of paper — and survives the existing toggle as a fully coherent second world. The functional diff tokens from v0.9.5 (`--add` green for "a line the product wrote," `--readhl` accent for "a file it read") carry into both worlds; contrast is documented AA-compliant in each.
- **`SessionBar` — the window chrome, on every page** (`website/src/components/SessionBar.astro`, new; replaces the retired `Header.astro` and `TrustBar.astro`). A fixed 40px top bar styles the whole site as one maximized terminal window: traffic-light dots, a `~/ThinkOS` working-directory label, nav, theme toggle, the version stamp, and a **live session clock** that advances as you scroll the homepage's timestamped scenes (`08:40 → 14:02 → … → Sun 20:14`). Static and honest with no JS.
- **`CommandStage` — interactive moment 1** (`website/src/components/CommandStage.astro`, new). Three keycap command chips — `/thinkos-morning`, `/thinkos-decide`, `/weekly-review` — are a WAI-ARIA tablist; clicking one swaps which vignette plays (the three former `DayPairs` beats relocated here as panels) and snaps the SessionBar clock to that moment. One `aria-live` region receives the full transcript per panel; no-JS renders all three panels stacked and static; reduced-motion keeps the chips but makes swaps instant.
- **`TryTerminal` — interactive moment 2** (`website/src/components/TryTerminal.astro`, new). Preset command buttons type the chosen command into a mock terminal and "run" it line-by-line; pick another preset and it retypes. The pane body is `aria-hidden` during animation with the transcript delivered once; no-JS hides the presets and shows preset 1's transcript statically with a note; reduced-motion shows the result without the typing.
- **Scroll-as-narrative homepage** (`website/src/pages/index.astro`, restructured into timestamped `.scene` sections). Commands type themselves as each scene enters the viewport (the v0.9.5 typewriter, extended from hero-only to per-scene via `IntersectionObserver`), diffs write in line-by-line and deletions strike L→R on reveal, and the day progresses down the page. Two `IntersectionObserver`s — one gates `.reveal-ready` (motion only when `prefers-reduced-motion` is not set) and lights up scenes; one drives the clock.

### Changed

- **The type system is retired and replaced** (`package.json`, `package-lock.json`, `BaseLayout.astro`, `global.css`, `tailwind.config.cjs`). `@fontsource-variable/newsreader`, `@fontsource-variable/hanken-grotesk`, and `@fontsource/ibm-plex-mono` are removed; `@fontsource-variable/bricolage-grotesque` (display + body, optical-sizing on) and `@fontsource-variable/jetbrains-mono` (machine voice) are added and self-hosted — no CDN, and none of the banned families (no Inter/Roboto/Space Grotesk/system). The `.display` voice is now a heavy Bricolage at `opsz 96`; the `.md-heading` / `.md-quote` markdown-source devices are re-voiced to match.
- **Layout grammar: sections become scenes** (`index.astro`, `Pair.astro`, `panes/TerminalPane.astro`). The centered-prose column with kicker-and-heading rhythm is gone from the homepage; each beat is a full-bleed scene with a hairline top rule, a timestamp, and a Pair restaged into the new pane chrome (lit `--bg-raised` bodies, phosphor bloom in dark, printed card in light). The `DayPairs` component is removed — its three beats now live inside the interactive `CommandStage`.
- **Every page restyled into the new world** (`guide.astro`, `commands.astro`, `changelog.astro`, `404.astro`, `DocsLayout.astro`, `InstallPrompt.astro`, `FlowDiagram.astro`, `Footer.astro`, `ThemeToggle.astro`). No page is left reading like v1: the guide and docs prose, the commands filter and table, the changelog index and version chips, the 404 `cat`-miss Pair, and the install card all adopt the dark-first palette, the new type, and the pane/keycap chrome. The Think Company attribution in the footer is preserved.

### Accessibility & build

Everything degrades. `prefers-reduced-motion: reduce` collapses every device — hero and per-scene typing, scroll reveals, staggered diff write-in, the L→R strike, the FlowDiagram connector draw — to its final static, fully-visible state (nothing is hidden behind animation). With no JavaScript the page is fully readable: reveals never hide content (the `.js` / `.reveal-ready` gating only *adds* motion), the interactive chips/presets fall back to static stacked panels, and the clock is honest. AA contrast is verified in both the dark and light worlds; `:focus-visible` rings, the skip-to-content link, and the full second theme are intact. The version stamp stays single-sourced from `VERSION` via `src/lib/version.ts` (synced by the `prebuild` step) — never hardcoded — and the changelog collection, RSS feed, 404, both `netlify.toml` files, and the standalone `npm run build` are unchanged and green. No new heavy JS dependencies; the interactivity is vanilla JS + `IntersectionObserver` + CSS.

### Why this matters

A redesign that changes the words but not the type, the color, or the layout isn't a redesign — and a client could see that at a glance. This release makes the 2.0 a visible fact, not a claim: the first screen reads instantly as a different site, the page plays like a session unfolding rather than a document you read top to bottom, and two genuinely interactive moments let a visitor drive the demo instead of watching it. Crucially, none of this costs the product its honesty — the new behavioral claims still trace to shipped playbooks under `adapters/claude-code/commands/` (the `CommandStage` chips are real commands; `/thinkos-morning`, `/thinkos-decide`, and `/weekly-review` behave as their markdown describes), and the verified v0.9.5 copy is reused verbatim. The bones were good; this gives them a body.

## [v0.9.5] — 2026-06-11 — Website 2.0: show the product, don't describe it

A website-only release — nothing outside `website/` changes; no scripts, templates, instructions, or playbooks are touched (verify with `git diff --stat`). The v0.9.4 site finally told people what to *do*, but it still opened on long-form prose, and a Design Lead's read was blunt: even a trimmed essay reads as an essay. This release rethinks the homepage as a product, not a document. It commits to one bold idea — Think OS is two surfaces, a terminal where you talk and a folder of plain files that change because you talked — and builds the whole page from a single signature device that *shows* that pairing instead of paraphrasing it. The design system (Newsreader display / Hanken Grotesk body / IBM Plex Mono, hairline rules, reduced-motion-safe motion) is extended, not re-themed; the brand navy/Think-blue palette stays.

### Added

- **The `Pair` device** (`website/src/components/Pair.astro`, plus `panes/TerminalPane.astro`, `panes/FilePane.astro`, `panes/DiffPane.astro` — all new). Every homepage beat is now a two-pane vignette: LEFT what you typed in Claude Code, RIGHT the plain markdown file that was read (`FilePane`, accent-highlighted rows) or written (`DiffPane`, diff-green appended lines / strikethrough replacements). A hairline connector with a `→` glyph joins the panes on desktop and rotates downward when they stack on mobile. The product is shown as cause and effect, not described in paragraphs.
- **`DayPairs` — "A day with it"** (`website/src/components/DayPairs.astro`, new). Four cause/effect moments from one workday: **08:40** a morning brief (Current Focus READ), **14:00** an automatic work-log entry you typed nothing to trigger (`+3 lines`), **16:30** a decision captured in one line (`+1 entry`), **Sunday 20:00** the staleness flag and `/weekly-review` (Current Focus replaced). The provenance comment names the exact source each pane mirrors: `thinkos-morning.md`, `thinkos-autosave.md` (session capture), `thinkos-capture.md` decision mode (`**Decision** / **Why** / **Context** / **Applies to**`, verified field-for-field), and the v0.9.3 `SessionStart` hook.
- **`FlowDiagram` — "How it works" in three nodes** (`website/src/components/FlowDiagram.astro`, new): your files → a local index → every session, joined by arrows, replacing three paragraphs of architecture prose with one glance.
- **Functional diff design tokens** (`website/src/styles/global.css`). New `--add` / `--add-bg` (diff-green) and `--readhl` (accent) tokens give the visual system a job: green means "a line the product wrote," accent means "a file it read," consistently across every artifact on the site. Contrast is documented and AA-compliant in both themes (4.9:1 light, 8.7:1 dark for the green).
- **Commands filter** (`website/src/pages/commands.astro`). A zero-dependency text input narrows all 36 commands as you type and hides any group whose rows are all filtered out; `aria-label`'d, keyboard-usable, no new JS deps.
- **Guide anchor TOC** (`website/src/pages/guide.astro`). A static, JavaScript-free table of contents jumps to the mental model, your first week, the daily and weekly rhythms, maintenance, dos and don'ts, and the cheat-sheet, with `scroll-mt` offsets on each section.

### Changed

- **Homepage rebuilt around the Pair** (`website/src/pages/index.astro`). The hero leads with a demonstrated morning brief (two small files read whole — "that's the entire trick"), then How it works (the three-node flow), A day with it (the four `DayPairs` beats), Get started (three steps), What it doesn't do (trust, stated as negatives), Works with, and the FAQ. Copy drops to captions; the panes carry the narrative.
- **Retired the decorative chrome** in favor of the markdown-source devices. The serif `pullquote`, `section-numeral`, and `ornament` styles are gone; `.md-heading` (a dimmed accent `## ` before mono heading text) and `.md-quote` (a `> ` blockquote) now carry section structure on the homepage, guide, and docs — the site's chrome is built from the same markdown the product manages. `architecture.astro` and `guide.astro` adopt these; the 404 page becomes a `cat 404.md: No such file or directory` Pair.
- **`ConversationStrip` removed** (`website/src/components/ConversationStrip.astro`, deleted). Its job — showing the product in motion — is now done more sharply by `DayPairs`.
- **`VaultTree` and `InstallPrompt` refreshed** to the new pane chrome (`pane-path` / `pane-tag` title bars, sample-data disclaimers retained; Sam Reyes / Cardinal Studio remain explicitly fictional).

### Accessibility & build

All motion stays behind `prefers-reduced-motion` guards — the hero typing, scroll reveals, and staggered diff lines each collapse to a static, fully-visible state; reveals are JS-opt-in and degrade to visible without JavaScript. `:focus-visible` outlines, the skip-to-content link, and full dark-mode styling are intact. The version stamp stays single-sourced from `VERSION` via `src/lib/version.ts` (synced by the `prebuild` step), and the changelog collection, RSS feed, 404 page, both `netlify.toml` files, and the standalone `npm run build` are unchanged and green. No new heavy JS dependencies.

### Why this matters

The product's ethos is honest, plain-spoken claims — and the clearest way to be honest about what Think OS does is to show it. A reader who has never heard "agentic OS" can look at a single Pair and understand the whole thing: you type a line, a plain file on your disk changes, and you can open that file anywhere. Every behavioral claim in the rebuilt pages still traces to a shipped playbook under `adapters/claude-code/commands/`, so the site can't drift into describing a product that doesn't exist. The visual system now does work instead of decoration, and the page respects a reader who wants to set up and be told how to use it rather than read an essay first.

## [v0.9.4] — 2026-06-11 — The website learns to teach: How-to-Use guide, scannable homepage, dedicated guide/commands pages

A website-only release — nothing outside `website/` changes; no scripts, templates, instructions, or playbooks are touched (verify with `git diff --stat`). The v0.9.3 site explained what Think OS *is* in one 758-line scroll but never told anyone what to *do* with it once installed. This release fixes that in three moves: a dedicated How-to-Use guide written for someone with no agentic-OS background (daily rhythm, weekly rhythm, dos and don'ts, a ten-command cheat-sheet), a homepage cut from one long scroll to five short sections plus FAQ (758 → 331 lines, with the displaced content landing on dedicated pages rather than being deleted), and a content accuracy pass that brings the published copy back in line with the v0.9.3 ground truth. Every behavior the guide describes traces to a shipped playbook under `adapters/claude-code/commands/`, `adapters/claude-code/INSTALL.md`, or `docs/` — nothing is invented. The existing design system (Newsreader display / Hanken Grotesk body / IBM Plex Mono, editorial numbered sections, reduced-motion-safe reveals) is extended, not re-themed.

### Added

- **`/guide` — the How-to-Use page** (`website/src/pages/guide.astro`, new). Seven numbered sections in the site's editorial style, aimed at someone who just installed and wants to be told what to do: **§ I** the mental model ("Three things, plainly"); **§ II** your first week, day 1 to day 7 — including a plain-language walkthrough of emergent seeding ("it fills in as you talk": the y / n / later offer, the three-deferral backoff, the `/thinkos-continue` bulk-import fast path); **§ III** the daily rhythm (a normal day); **§ IV** the weekly rhythm ("Sunday, twenty minutes" — `/weekly-review`); **§ V** maintenance and health ("When something feels off" — doctor, vitals, reindex); **§ VI** a Do / Don't double column; **§ VII** the cheat-sheet — "The ten commands you'll actually use," each row showing what you type, the plain-English phrase that works instead, and what happens. Reveals stay reduced-motion-safe throughout.
- **`/commands`** (`website/src/pages/commands.astro`, new). The full 36-command listing, moved off the homepage and grouped by when you'd reach for each (Morning ritual, Capture & recall, People & projects, …), keeping the per-group "when you'd reach for this" intros. Command descriptions match the shipped skill descriptions.
- **`/docs/whats-installed` and `/docs/architecture`** (new docs pages). The homepage's "Built in" cards and the "Your files are already the database" section (header copy, pullquote, three cards, GitHub link), relocated intact into the docs layout where they read as reference material instead of scroll filler.
- **Navigation for the new pages.** Header gains "How to use it" and "Commands" links (with short labels on small screens; the version stamp and GitHub link now hide below `sm` to keep the bar from wrapping); the docs sidebar gains a "Using Think OS" group at the top (`DocsLayout.astro`); the docs overview gains three matching cards; the 404 page links to the guide; and Install, Continuous Capture, and the homepage FAQ all cross-link `/guide` at the moment a reader would ask "okay, now what?"

### Changed

- **Homepage restructured from one long scroll into five short sections + FAQ** (`website/src/pages/index.astro`, 758 → 331 lines). **§ I** "What it is, who it's for" answers What / Who / Trust in three cards before asking the reader to scroll; **§ II** "Get started in three steps" replaces the longer onboarding prose; **§ III** "A day with it" rebuilds the conversation strip (see below); **§ IV** keeps the three rules unchanged; **§ V** is the FAQ, now led by the question the old site never answered — "What do I actually do day to day?" — with a one-sentence honest answer (one morning command, a one-line capture when a decision is worth keeping, twenty minutes on Sunday) and a link into the guide. A header comment in the file documents exactly which removed section moved to which page, so nothing was silently deleted: Built-in cards → `/docs/whats-installed`, files-not-a-database → `/docs/architecture`, vaults + VaultTree → `/docs/multi-vault`, the command table → `/commands`, continuous capture → `/docs/continuous-capture`, staying current → `/docs/update-protocol`.
- **ConversationStrip rewritten as "A day with it"** (`website/src/components/ConversationStrip.astro`). Three panels (cold start / capture offer / morning brief) become four beats from one workday: the 08:40 morning brief, an automatic work-log entry, a decision captured in one line, and Sunday's `CURRENT FOCUS STALE … run /weekly-review` flag followed by the review. The no-fabrication rule carries over and the provenance comment now names the exact sources each line mirrors: `thinkos-morning.md`, `session-capture.md`, `thinkos-capture.md` (decision mode), `thinkos-session-start.sh`, and `weekly-review.md`.
- **VaultTree moved to `/docs/multi-vault`** (`website/src/components/VaultTree.astro`, `website/src/pages/docs/multi-vault.astro`). The populated-vault "On disk" illustration is now an embeddable block sitting next to the architecture it illustrates, instead of a standalone homepage section.
- **Content accuracy pass.** The install page caught up with v0.9.3's onboarding truth: it said "four questions" when the wizard asks five — the fifth (tracked work folders, added in v0.9.3) is now listed *and* explained, because it matters: automatic session capture watches only the folders you name there. Install also gains an "Installed?" pointer into the guide, and Continuous Capture now states explicitly that it documents the system design while the user-facing rhythm (what's automatic, what needs a sentence from you, how to audit or undo a capture) lives in the guide.
- **One style addition** (`website/src/styles/global.css`): a `.prose blockquote` rule (Newsreader, accent left rule) for the guide's quoted agent lines — e.g. the emergent-seeding offer shown verbatim.

### Why this matters

The product's ethos is honest claims, and the most dishonest thing the old site did was structural: it implied that understanding Think OS was the user's job. The guide inverts that — install it, then do these three things at these three cadences — and every sentence of it is derived from the playbooks that actually ship, so the site can't drift into describing a product that doesn't exist. The homepage now respects the reader who won't scroll: what it is, how to start, what a day looks like, the rules, the questions. Everything deeper is one labeled click away instead of three screens down.

## [v0.9.3] — 2026-06-11 — Same Architecture, Smaller Footprint: instruction-stack diet, retrieval doctrine, mechanical freshness, index hygiene

A token-efficiency release that changes no architecture. Files stay the source of truth, Basic Memory stays the read/write surface, and zero new derived artifacts sit at the session entry point — but the per-session footprint drops by roughly half to two-thirds across the measured paths. The work is grounded in a 22-agent verified research study (`.plans/2026-06-10-memory-architecture-research/report.md`): the deployed instruction stack measured 560 lines / 37,147 chars (~9.3k tokens) loaded *every* session, the mandated first-action search pair cost ~1,620 tokens at `page_size=10` when ~520 at `page_size=3` held the same top-3 recall, three playbooks read the full Tasks file when they needed one section, `/recent-log` read the whole ~9.3k-token Work Log for a 7-day window, capture dedup read the full ~6.5k-token ledger for a recency check, Current Focus went 17 days past its `covers_week` under prose-only enforcement, and the live Basic Memory FTS index had silently accumulated duplicate rows from concurrent per-session servers racing delete+insert. Every one of those findings gets a mechanical fix here.

Measured per-command results: `/thinkos-morning` ~17.6k → ~8.2k tokens, `/recent-log` ~20.2k → ~6.2k, `/thinkos-capture` ~9.6k → ~2.0k, a trivial-question session ~10.9k → ~4.7k.

### Changed

- **Instruction-stack diet: ~9.3k → ~4.5k tokens per session** (`templates/instructions/`, `adapters/claude-code/instructions.md`). The assembled always-on block now measures 241 lines / 18,609 chars, against a documented budget of ~240 lines / ~18,000 chars in `templates/instructions/README.md` (with the measurement command). Three blocks moved out of residency into on-demand skills (see Added): the claude.ai bridge guide, the shared-mode full spec, and the emergent-seeding save-flow mechanics — each leaving a resident stub. **Passive trigger-bearing logic deliberately stayed resident**: shared-mode's detection precedence plus `search_notes` filtering and `read_note` redaction, drift-detection heuristics, and the seeding offer cadence all remain in the always-on block, because a skill the model never loads is a behavior that never fires. `05-global-rules.md` is byte-identical to v0.9.2 — the safety rules were explicitly out of bounds for the diet. The rendered block is deterministic (identical hash across renders, no dynamic content) so prompt caching holds; dynamic state arrives via the SessionStart hook instead.
- **Retrieval doctrine: `page_size=3` + escalation, snippets are pointers** (`templates/instructions/00-think-os-priority.md`, `templates/instructions/10-token-efficiency.md`, reference card in `adapters/claude-code/commands/thinkos-mcp-help.md`). The mandated first-action search pair now runs at `page_size=3` (~520 tokens, measured, vs ~1,620 at the old default — top-3 recall held in testing), with an explicit escalation ladder when results look thin: `page=2` → `page_size=10` → `read_note`. Search snippets are treated as pointers to notes, never quoted as answers (they're undated mid-sentence fragments). `build_context` discipline documented: text + timeframe modes, the 7d-default trap, and the 4k-char-truncation pointer behavior. Whole-file reads of *small* HOT files (Identity, Current Focus) remain correct and are deliberately not optimized away — verbatim reads are the strongest grounding the system has.
- **Scoped reads of the three big files — `read_note` of Work Log / Capture Log / Tasks demoted to explicit fallback everywhere** (12 files under `adapters/claude-code/commands/`). Deterministic read-only shell extraction replaces full-file reads: `/recent-log` calls the new `thinkos-recent.sh --worklog --days N --json` (date-window extraction from the file on disk, repo resolved via the install manifest's `repo_path`); `/thinkos-capture`'s dedup check reads `tail -n 30` of the Capture Log instead of the whole ledger; `/thinkos-morning` and `/thinkos-plate` extract exactly the `## Today` / `## This week` sections of Tasks via a tested awk pattern, with plate's freshness check now a mechanical `grep -m1 '^last_synced:'`; `/thinkos-refresh` writes via `find_replace` on the `## Today` region instead of a full-file replace (full replace demoted to an explicit fallback). A sweep confirmed zero undocumented full-file reads of those three files remain — every surviving `read_note` is an explicit shell-unavailable / anchor-absent fallback. Vault *writes* still go through Basic Memory exclusively.
- **`/weekly-review` is now replace-and-prune** (`adapters/claude-code/commands/weekly-review.md`). The outgoing focus block is archived to the Work Log *before* Current Focus is replaced and `covers_week` updated; a legacy rule prunes multi-week accumulation from older installs; confirm-before-write preserved. This stops Current Focus growing by accretion and makes the freshness window actually advance.
- **Website redesign: editorial type, motion, depth + research-backed positioning** (`website/`). Self-hosted typography (Newsreader Variable display, Hanken Grotesk Variable body, IBM Plex Mono — the Google Fonts CDN dependency is fully removed), strict `prefers-reduced-motion` handling (CSS collapse + JS matchMedia guard; reveals degrade to fully visible), `:focus-visible` outlines and a skip-to-content link, both themes covered. New "Your files are already the database" homepage section and FAQ entries carry the research-backed positioning (local zero-API-call embeddings, hybrid FTS + vector + relation-graph retrieval, the staleness hook, doctor's index-drift detection) — every claim checked against the study. The changelog page got a matching refresh, brittle line-count claims were removed sitewide, and the version stamp stays single-sourced from `VERSION` via `src/lib/version.ts`.

### Added

- **Mechanical freshness — `SessionStart` hook** (`scripts/thinkos-session-start.sh`, wired by `install_session_start_hook()` in `thinkos-setup.sh` / `thinkos-update.sh`). One read-only script, <500ms measured (59ms live), bash-3.2-safe: when Current Focus's `covers_week` end date is past, every new session opens with one line — `CURRENT FOCUS STALE: covers_week ended <date> — run /weekly-review`. Silent when fresh, silent on missing vault or malformed `vaults.json`, exit 0 always. The hook merge into `~/.claude/settings.json` is idempotent, preserves pre-existing user hooks (tested against existing SessionStart+Stop entries), backs up the file, and writes atomically. Freshness is now enforced by mechanism, not prose — the prose-only version let Current Focus run 17 days stale.
- **Focus Freshness one-liner for non-CLI surfaces** (`templates/90 System/Focus Freshness.md`, written by doctor). Surfaces that can't run hooks (Desktop, mobile) get the same staleness signal as a tiny vault note: one `focus-fresh: YES/NO` line with a `generated_at` stamp, overwritten by `thinkos-doctor.sh` on each run.
- **Index hygiene — doctor drift detection against `memory.db`** (`scripts/thinkos-doctor.sh`). New `index:drift` check compares Basic Memory `search_index` rowcounts against actual entity/observation/relation counts and recommends `/thinkos-reindex` on mismatch — it caught the live corruption (52/122/161 rows vs 37/99/122 actuals at release-time) that concurrent per-session servers raced into the FTS5 table. Also new: `focus:freshness` and a generalized `derived:freshness` check over `generated_at` notes under `90 System/`; all three surfaced in `/thinkos-vitals` (new "FRESHNESS & INDEX SIGNALS" section + `--json` fields). Degrades to an honest `ok — sqlite3 unavailable` rather than a false clean, and reads WAL-mode databases via a plain-open fallback (`sqlite3 -readonly` cannot open a WAL database whose sidecar needs write access — found live when the rebuilt index came up WAL). An upstream issue with the live evidence and suggested fixes is drafted (marked DRAFT, re-verify before filing) at `.plans/2026-06-10-memory-architecture-research/upstream-issue-draft.md`; single-shared-BM-server mode is documented as the long-term posture in `docs/why-files-not-a-database.md` §6.
- **`thinkos-recent.sh --worklog` mode** (`scripts/thinkos-recent.sh`). Read-only, `--days N --json`, newest-first, handles dated H2 and H3 entry headers (time-only H3s stay in the enclosing entry body), returns `[]` on a missing Work Log. The existing ledger mode is untouched.
- **Three on-demand skills** (`adapters/claude-code/skills/`): `thinkos-bridge` (the full claude.ai deferred-tool guide), `thinkos-shared-mode` (the full shared-mode spec; the resident core keeps redaction always-on), `thinkos-emergent-seeding` (save-flow mechanics). Installed to `~/.claude/skills/` and manifest-recorded by both `thinkos-setup.sh` and `thinkos-update.sh`. Full semantic coverage of the v0.9.2 resident originals, with one deliberate change: the shared-mode skill replaces a reference to a never-shipped classifier script with a `/thinkos-vitals` flow.
- **Markdown knowledge-graph conventions: `supersedes:` and `aliases:`** (`templates/04 Knowledge/Decisions.md`, `templates/03 People/People.md`, wired through `thinkos-capture.md`, `thinkos-decide.md`, `thinkos-decisions.md`, `thinkos-who.md`). Superseding a decision writes both edges — `Supersedes:` on the new entry, `Superseded-by:` patched onto the old via `find_replace` — and `/thinkos-decisions` now filters superseded entries from default answers, follows chains, and gates history behind explicit request. People entries get an `aliases:` line; `/thinkos-who` matches canonical names and aliases, reports which alias hit, and offers confirmed capture of new names. This is the deterministic, zero-LLM-cost answer to "temporal edge validity" and "entity resolution" from dedicated memory databases.
- **Tracked work folders — onboarding question + `track`/`untrack`** (`adapters/claude-code/INSTALL.md` Question 5, `setup/manifest.yaml`, `scripts/thinkos-setup.sh --tracked-projects`, `scripts/thinkos-vault.sh track|untrack`, `/thinkos-vault` Branch 7). Session capture only records Claude sessions inside registered vaults or `tracked_projects` paths — but nothing ever populated that list, so the v0.9.0 filter silently matched zero sessions on real installs (found live: 0/61 sessions matched for four weeks). The install wizard now asks "Which folders hold the projects you work in?" and wires the answer through `--tracked-projects`; existing installs add folders any time with `scripts/thinkos-vault.sh track <path>` (idempotent, prefix-matched, documented in `docs/continuous-capture/session-capture.md`). The INSTALL.md bundle descriptions also caught up with the v0.9.2 truth pass (Linear / Microsoft 365 removed — they were fixed on the site and manifest but missed in this copy).
- **`docs/why-files-not-a-database.md`** — the canonical answer to "shouldn't this be a vector/graph database?", steelmanned and number-checked against the research report. The one-line verdict: **the database migration reduces to a compact deterministic view plus an index fix — keep the files; zero of the ~9.7k tokens saved on the morning path required a database** (every lever was scoping, a call parameter, or a markdown anchor). Covers the hybrid index Basic Memory already derives from the files, the collapsed vendor benchmarks (Zep's 84% LoCoMo → 58.44% on re-run; plain files at 74.0% vs Mem0's graph variant at 68.5%), the 4–6-week migration cost that breaks git sync / offline / external editors / file-first, write-time extraction loss (~65.8% entity capture), and the honest "what a dedicated system does better" table with the v0.9.3 deterministic equivalents. Linked from the README's three-rules section. The Tasks template also gains the exact `## Today` anchor (with a do-not-rename comment) the scoped reads depend on.

### Research

This release is the implementation half of a 22-agent verified study (`.plans/2026-06-10-memory-architecture-research/report.md`): fan-out research and live measurement of the deployed system, adversarial verification, and two independent judges re-verifying every load-bearing figure. All token numbers above are measured, not estimated, and a competing migrate-to-a-database proposal was steelmanned and priced before being declined on the evidence.

### Why this matters

The research opened with a challenge — "markdown files? shouldn't this be a real memory database?" — and the honest answer turned out to be that the waste was never the files. It was *how* they were read: a 9.3k-token preamble re-sent every session, full-file reads where one section was needed, a search default 3× more expensive than the recall required, and freshness enforced by a sentence nobody executes. Every fix in this release is a parameter, a heading anchor, a shell extraction, or a hook — the same architecture with a smaller footprint. Meanwhile the one genuine database exhibit (the corrupted FTS index) argues *for* this design: it was a derived-cache bug, the markdown was never wrong, and one reindex repairs it from the files — which is exactly what doctor now detects. The footprint roughly halves; nothing about where truth lives changes.

## [v0.9.2] — 2026-06-10 — Verified fix sweep: stale-launchd self-healing, script hardening, and a truth pass across templates, playbooks, docs, and the website

A five-stream verified fix sweep (scripts, templates, adapters, docs, website), with every stream independently re-verified against the working tree before landing. The headline fix: moving the repo silently broke every installed launchd job, because each `com.thinkos.*.plist` bakes the script path in at install time — `/thinkos-update` now detects and regenerates stale jobs automatically. Around it: argv/XML-escaping hardening in the install scripts, an uninstaller that finally understands v2 manifests, doctor checks that no longer report clean when their own probes fail, the last retired `productivity:update` references removed, maintainer-specific content scrubbed from everything that ships to other people's machines, and a docs + website truth pass that brings published claims back in line with what the code actually does.

### Fixed

- **Stale launchd jobs after a repo move** (`scripts/thinkos-update.sh`). New `refresh_launchd_jobs()` step: reads the script path out of each `~/Library/LaunchAgents/com.thinkos.*.plist` via `plutil`, and when it no longer resolves inside the current repo, re-runs the matching installer (`install-sync-job.sh`, `install-session-capture.sh`, or `install-launchd-job.sh`) to regenerate and reload the job with the same label and schedule. Job-specific `--vault` args are recovered from the existing plist. Previously a repo move left every automation pointing at the old path — jobs kept "running" and failing silently until someone read `launchd` logs.
- **`catalog.sh` shell-interpolation into Python** (`scripts/lib/catalog.sh`). `catalog_resolve_preset` and `catalog_pretty` interpolated `$preset` / `$id` directly into the embedded Python program text; both now pass them as argv. Hostile or merely unusual input can no longer alter the program.
- **Doctor preset-name validation** (`scripts/thinkos-doctor.sh`). The bundle marker's preset name is validated against `^[a-z0-9_-]+$` before being handed to the catalog resolver, closing the same injection shape from the marker-file side.
- **`install-sync-job.sh` plist rendering now XML-escapes** `__REPO_ROOT__` / `__VAULT_PATH__` / `__LOG_DIR__` before substitution. A vault path containing `&` or `<` previously produced an invalid plist.
- **Uninstaller couldn't read v2 manifests** (`scripts/thinkos-uninstall.sh`). The manifest loader rejected anything with `version != 1` — every fresh install since the v0.9.0 auto-migration writes v2, so the uninstaller saw "no manifest" and skipped the managed-file teardown. It now accepts v1 and v2, rendering `managed_files` into the v1 line shape (block entries keep the "(block injected)" suffix). Supporting fix: the base64 decode helpers re-pad before decoding, because the `IFS='='` field split strips base64 padding.
- **Doctor false-clean fallbacks** (`scripts/thinkos-doctor.sh`). The drift-count, ledger-validation, and 24h-volume probes all defaulted to a clean-looking value (`0`) when their embedded python3 failed — a broken probe reported a healthy install. Each now falls back to `?` and emits an explicit `warn` ("check failed to run; state unknown"). `json_escape` also escapes newlines and carriage returns, so multi-line detail strings no longer corrupt `--json` output.
- **Vault sync sensitive-path guard widened** (`scripts/thinkos-git.sh`). The pre-stage guard only checked *untracked* files against the sensitive-path patterns (`.claude/`, `.ssh/`, `.gnupg/`, `.aws/`, `.docker/`); `git add -A` would happily stage a tracked-but-modified one. Both sides are now checked.
- **`render-instructions.sh` clobbered the caller's EXIT trap.** `install_marked_block()` now captures any pre-existing EXIT trap and restores it instead of `trap - EXIT`. Verified functionally on macOS bash 3.2.
- **Unguarded `*.md` globs** in the slash-command copy loops (`thinkos-setup.sh`, `thinkos-update.sh`) — an empty or missing `adapters/claude-code/commands/` directory now warns and skips instead of copying the literal glob string.
- **`/thinkos-reindex` resolved the wrong Basic Memory project.** The active-vault snippet printed the vault *id* instead of looking up its `bm_project` in `vaults.json` — reindex targeted a nonexistent BM project whenever the two differed. The lookup is fixed and the snippet python-parses.
- **`/thinkos-doctor` documented flags the script doesn't have.** The skill's flags table now matches `thinkos-doctor.sh`'s real argument parsing exactly — no more agents confidently passing phantom flags.
- **`/thinkos-capture-setup` source numbering** repaired (sources renumbered 1–7 with all cross-references reconciled), question-count wording reconciled, and `AskUserQuestion` preambles added before first use in the three skills that called it cold.
- **Work Log identifier standardized** across `adapters/` (same class of bug as the v0.8.4 `Decisions` fix — identifiers must match the note's `title` field), plus an append-fallback in `/thinkos-voice` and a corrected `find` path in the commands README.
- **Emergent-seeding spec gaps** (`templates/instructions/40-emergent-seeding.md`): the `n` response now explicitly clears the draft, first-write bootstrap uses `write_note` when the state note doesn't exist yet, and the rendered draft is shown for review before the replace — closing the "propose, never overwrite silently" loophole.
- **`thinkos-continue.sh`** wizard step renumbering (1, 3 → 1, 2).
- **Stale `[Unreleased]` changelog block removed.** It described the v0.4-era switch from remote scheduled triggers to local launchd jobs — accurate, but long since shipped and already reflected in the versioned entries that followed. Nothing in it was pending release.

### Changed

- **Retired `productivity:update` references fully removed.** v0.9.1 repointed the live skills; this sweep catches the stragglers (including `templates/01 Now/Tasks.md`'s footer) so no shipped file mentions the dead skill. `grep -r 'productivity:update'` over shipped content comes back empty.
- **Maintainer-specific content scrubbed from shipped files.** `templates/05 Profile/Business Brain.md` is fully genericized (placeholder org, fill-in sections with examples — no Think Company strategy, voice attributes, or Confluence source links); example names and home-directory paths in docs and playbooks now use neutral placeholders; duplicate `@maya` removed from both team schema examples (uniqueItems now satisfied). Only upstream repo URLs still carry the maintainer's GitHub handle, deliberately.
- **Docs truth pass.** `docs/continuous-capture/README.md` no longer claims session capture runs via a Claude Code Stop hook (it's the 2-hourly launchd job; the Stop hook is future work per `docs/automation-roadmap.md`); layer naming unified to Layer A/B/C everywhere (was a mix of Layer 1/2/3 and block numbers); `docs/emergent-seeding.md` corrected to the in-vault `90 System/Emergent State.md` state note (the old `~/.thinkos/emergent-state.json` path contradicted the shipped instructions); `docs/multi-vault-architecture.md` status updated to "partially shipped" with an honest still-future list; the skip-rule keyword list in the playbooks now matches `templates/instructions/00-think-os-priority.md` verbatim; `LIMITATIONS.md` restructured and expanded (platform / dependencies / enforcement model / scope); README command table updated with the six non-prefixed commands and corrected descriptions.
- **Website truth pass.** Version stamp single-sourced: new `website/src/lib/version.ts` reads the repo-root `VERSION` file at build time — Header, Footer, and TrustBar can no longer drift from the actual release. `ChangelogPreview` renders from the changelog content collection instead of a hardcoded snippet. Homepage claims corrected against reality: thirty-six slash commands (was "twenty-seven", table now has all 36 rows), ~500 lines of curated instructions (was ~280), bundle descriptions no longer list Linear / Microsoft 365 (removed from `index.astro` and `setup/manifest.yaml` descriptions to match the actual presets; catalog presets untouched). Stale "docs may lag the repo" disclaimer removed from all seven docs pages; DocsLayout nav gains the missing pages. `letterSpacing` token fixed in `tailwind.config.cjs` so the tracking utility actually emits CSS. PubMed recategorized `crm_analytics` → `research` in the plugin catalog (lint passes, JSON regenerated in sync).

### Added

- **`catalog:lint` doctor check.** `thinkos-doctor.sh` now runs `scripts/lib/lint-catalog.sh` on every invocation: exit 0 → `ok`, 1 → `fail` with the lint output, anything else → `warn`. Present in `--json` output. Catalog drift gets caught at doctor-time instead of at install-time.
- **`templates/90 System/Emergent State.md`** — the shared draft-state note that the emergent-seeding instructions have referenced since v0.7.6 but no template ever shipped. Valid fenced-JSON block, permalink matching the spec's hardcoded identifier. Installs automatically via `copy_templates()` on fresh installs; existing installs get it on first emergent-seeding write (the new `write_note` bootstrap above).
- **`/thinkos-vault` Rename branch.** The skill now covers renaming a vault, consistent with `thinkos-vault.sh`'s rename semantics, with the `INSTALL.md` pointer fixed to match.
- **Website: `404.astro`** — the site previously served the host's default error page.
- **Website: seven backfilled changelog entries** (`v0.7.1`–`v0.7.6`, `v0.9.1`) — the site's changelog collection had gaps that the repo CHANGELOG didn't; all match the collection schema, tone, and original release dates.

### Why this matters

This release is the difference between "the fixes were written" and "the fixes were verified." Every stream ran through an independent re-verification round against the working tree — the launchd refresh was exercised against a live install with ten stale plists, the uninstaller's manifest loader against synthetic v1/v2/v3 manifests, the XML escaping against a hostile vault path, and the doctor's new checks through a JSON round-trip. Three of the script fixes (stale launchd paths, v2-manifest uninstall, doctor false-cleans) share a theme worth naming: infrastructure that fails *silently* is worse than infrastructure that fails loudly, because the user's mental model says it's working. And the truth passes matter for the same reason at the documentation layer — a doc that describes a Stop hook that doesn't exist, or a homepage that claims twenty-seven commands when thirty-six ship, trains readers (and agents) to distrust everything else. All of it is now either true or deleted.

## [v0.9.1] — 2026-05-18 — `/thinkos-refresh` skill — connector sweep for `Tasks.md`

Closes a real gap surfaced today: `01 Now/Tasks.md` documented `productivity:update` as its refresh path, but that skill no longer exists in the `/thinkos-*` namespace. Six other skill files referenced it as a fallback. The fix is a new `/thinkos-refresh` command — portable across surfaces (Claude Code, Cowork, desktop agent) via the claude.ai bridge with native MCP fallback. Same job as the old `productivity:update` (Gmail / Slack / Calendar / ClickUp / Atlassian / Notion / Granola → rewrite `Tasks.md`), but lives where users actually look.

### Added

- **`/thinkos-refresh` skill** (`adapters/claude-code/commands/thinkos-refresh.md`). Connector sweep that rewrites `01 Now/Tasks.md` with a fresh `last_synced` timestamp. Modes: default comprehensive (all seven sources), `--quick` (Gmail / Slack / Calendar / ClickUp only, ~15s), `--source <name>` (single connector), `--dry-run` (preview diff without writing), `--days <N>` (override lookback). Parallel connector pulls in a single assistant turn. Applies the per-source filter rules from `Connectors.md` (ClickUp 90d stale filter, Atlassian Confluence-only, Notion on-demand). Preserves the `### Manually added` and `## Done (this week)` sections verbatim. Appends a capture-log event on every run. Graceful per-source degradation — one connector unavailable doesn't fail the whole sweep.
- **Registration** in `adapters/claude-code/commands/README.md` (commands table + new "Connector sync" section) and `adapters/claude-code/commands/thinkos-help.md` (Maintenance section).

### Changed

- **Cross-references updated** in six existing skills + two templates to point at `/thinkos-refresh` instead of `productivity:update`: `thinkos-plate.md`, `thinkos-morning.md`, `thinkos-stale.md`, `thinkos-reindex.md`, `templates/01 Now/Tasks.md`, `templates/90 System/OS Instructions.md`. The legacy `productivity:update` skill is explicitly retired in the README Connector-sync section.

### Versioning note (read this before the next bump)

This is a patch — not a minor — and the rule is being tightened. The earlier 2026-05-18 decision said "minor version bump for external contributions adding new contracts." Reading that literally would make every new skill a minor bump, and we'd be at v0.20.0 by month-end despite being nowhere near a v1.0 maturity bar. The refined rule (also captured in `04 Knowledge/Decisions.md` today):

- **Patch (0.X.Y+1)**: hotfixes AND small additive features that fit under the current milestone framing.
- **Minor (0.X+1.0)**: only when a coherent milestone ships — and the milestone gets a name at bump-time. v0.9.0 had one: "first external contribution + Dave's architectural fix." Avoid minor bumps for routine feature additions.
- **Major (1.0.0)**: feature-complete, stable, externally adoptable without warnings. Long way off.

`/thinkos-refresh` is genuinely additive but fits under the existing v0.9 "stable-with-external-contributors" framing. Patch.

## [v0.9.0] — 2026-05-18 — First external contribution: `tracked_projects` filter + auto-migrate to v2 manifest

**The first external pull request on Think OS.** Dave Drager (Technical Lead, Think Company) installed v0.8 today, hit the session-capture filter dropping all his sessions (because his code lives outside the vault — the typical case), diagnosed three v0.8 bugs of mine + landed an architectural improvement that retires the v0.8.2 recovery flow's hot path. Merged via `--rebase` to preserve his two commits' authorship; this changelog credits him explicitly.

PR: https://github.com/dhirajsapkal/think-os/pull/1
Commits: `1b961aa` (setup auto-migrate) + `c914a85` (tracked_projects filter + install fixes).

### Added

- **`tracked_projects[]` array in `~/.thinkos/vaults.json`.** Session-capture's default filter now accepts the union of `vaults[].path` and `tracked_projects[].path`. Lets users register code-repo roots without conflating them with vaults — the typical case where the vault holds notes and code lives at `~/Code/`. Backward-compatible: absent field reproduces today's behavior. Older script versions reading a newer `vaults.json` silently ignore the new array.
- **Visible no-match output in session-capture.** The Python filter now emits one stderr line per run (`filter: M/N sessions matched (K allowed paths)`), and the bash wrapper replaces the silent zero-match exit with a timestamped warning pointing the user at `tracked_projects` or `--all-projects`. The "Recent no-match events" surface in `/thinkos-autosave status` makes the new stderr useful instead of noisy.
- **`/thinkos-autosave` skill enhancements** (`adapters/claude-code/commands/thinkos-autosave.md`): new "Tracked projects" section explaining the registry; `status` output now lists allowed paths and recent no-match events; `now` captures stderr so filter warnings are visible; "didn't capture anything" FAQ rewritten to point at `tracked_projects` first.

### Fixed

- **`__REPO_ROOT__` substitution missing in `install-session-capture.sh`** (Dave's catch). The plist template referenced `__REPO_ROOT__` (added in v0.8 WP-38) but the install script never replaced it, so `WorkingDirectory` was set to the literal string `__REPO_ROOT__`. Harmless under launchd today (scripts use absolute paths) but ugly and a future footgun. Now substituted via the existing XML-escape pattern for `SCRIPT_PATH` / `LOG_DIR`.
- **`flock(1)` doesn't ship on macOS** (Dave's catch). v0.8 WP-41's session-capture ledger append assumed `flock(1)` existed. macOS uses fcntl and doesn't bundle BSD-flock by default — every run was printing `flock: command not found` to stderr before writing. Guarded with `command -v flock`; fallback is plain append. Safe because launchd serializes scheduled fires by job label (the lock was defense-in-depth, not load-bearing).
- **Setup now auto-migrates manifest v1 → v2 on fresh install** (Dave's architectural improvement). Fresh v0.8 installs landed at manifest v1, but `/thinkos-autosave`, `/thinkos-update`, and `/thinkos-capture-setup` all expect v2 fields (`repo_path`, `managed_files`). Result: post-install, those commands couldn't resolve the repo — which is exactly the bug Chris hit on his pre-v0.8 install and that v0.8.2 added a recovery flow for. Setup now invokes the existing idempotent v1→v2 migrator after writing v1. Failure logs a warning + points at manual recovery rather than blocking setup. **This makes v0.8.2's recovery flow the cold path instead of the hot one** — fresh installs no longer hit the bug; the recovery flow remains for upgrading stale pre-v0.8 installs.

### Why this matters

Three of Dave's catches (filter default wrong for typical users, `__REPO_ROOT__`, `flock`) were silent regressions I shipped in v0.8 that nobody hit during my testing because my install happens to match the assumptions I baked in (vault holds the work directory; `flock` exists in my development environment). Dave's install didn't match those assumptions — and the bugs surfaced within an hour.

This is exactly the case for landing v0.9.0 instead of v0.8.5. New `tracked_projects[]` is genuinely additive contract, not a fix for a regression. And it's the first external contribution: the project now has a real second contributor, with proper authorship preserved via rebase.

One known item for v0.9.1 or v1.0: Dave's no-match warning fires on every launchd run with zero matched sessions — could grow `session-capture.err` over time. Mitigation already in place (single-line timestamped messages, surfaced usefully in `status`). Worth folding into the log-rotation work added in v0.7-era if it becomes annoying in practice.

## [v0.8.4] — 2026-05-18 — Hotfix: `/thinkos-capture` and `/thinkos-decisions` referenced wrong Basic Memory identifier

Caught during a real `/thinkos-capture` run in session-recap mode today. The decision-mode write template used `identifier="Standing Decisions"` — but the actual note in the vault has title `Decisions` (with `Standing Decisions` only as the H1 heading inside the file body). Basic Memory's `edit_note` matches on title, not on H1, so the prepend call **created a new orphan note** at `Standing Decisions.md` instead of prepending to the canonical `04 Knowledge/Decisions.md`. Caught it mid-session, deleted the orphan, and re-prepended to the correct identifier — but the underlying skill template was still wrong and would have repeated the bug on the next session-recap.

### Fixed

- **`adapters/claude-code/commands/thinkos-capture.md:51`** — decision-mode write: `identifier="Standing Decisions"` → `identifier="Decisions"`.
- **`adapters/claude-code/commands/thinkos-decisions.md:9`** — decisions-read fallback: `mcp__basic-memory__read_note("Standing Decisions")` → `mcp__basic-memory__read_note("Decisions")`. (Less destructive than the capture bug — a missing-note read just returns "not found" — but same root cause and worth fixing in the same pass.)

### Why this matters

Basic Memory identifiers match on the note's title field (in frontmatter), not on the H1 heading inside the body. The Decisions file has frontmatter `title: Decisions` and a body that opens with `# Standing Decisions` — easy to confuse for a human writing the skill template. The fix is one-character per file (`"Decisions"` instead of `"Standing Decisions"`). The underlying lesson is broader: any Basic Memory identifier in a curated skill should be cross-checked against the actual note's `title` field rather than copied from the body. Worth keeping in mind for the other slash commands that reference vault notes by name.

## [v0.8.3] — 2026-05-18 — Hotfix: Slack local install path is broken; introduce `requires_bridge`

Dave Drager (Think Co) installed Think OS via the `pm` bundle. His other connectors (Gmail, Calendar, Drive, Granola) routed cleanly through the claude.ai bridge. Slack didn't — the bridge wasn't enabled for Slack on his claude.ai account, so the installer fell through to the local install path, which attempted `claude mcp add slack https://mcp.slack.com/mcp`. On first OAuth, his Claude Code surfaced this:

> Slack's auth server doesn't support Dynamic Client Registration. Only accepts pre-registered OAuth clients tied to a specific Slack App.

His diagnosis was correct. Claude Code's MCP client for `mcp_remote` endpoints uses RFC 7591 Dynamic Client Registration to bootstrap OAuth. Slack's official endpoint at `https://mcp.slack.com/mcp` requires pre-registered clients (you create a Slack App in api.slack.com, install it to your workspace, and use its tokens). DCR isn't supported. The local install path was always going to fail.

It worked for him on the bridge because claude.ai's Slack connector ships with a pre-registered OAuth App that handles auth on the user's behalf — that's what `mcp__claude_ai_Slack__*` is. So the catalog assumption "if the bridge isn't there, install locally" was wrong specifically for Slack.

### Fixed

- **`scripts/thinkos-install-bundle.sh` items-resolution bug.** Pre-existing bug found while testing the v0.8.3 changes: `--items <single-id>` produced "No items resolved" because the items-resolution loop's `printf '%s' "$ITEMS_RAW" | tr ',' '\n'` lacked a trailing newline, so `IFS= read -r id` dropped the last (and only) entry. One-line fix: `printf '%s\n' "$ITEMS_RAW"`. Multi-item invocations were also losing their last entry silently.

### Added

- **`requires_bridge` field on catalog entries.** New optional boolean in `data/plugin-catalog.yaml`'s `claude_code` block. Set to `true` when the vendor's MCP endpoint requires a pre-registered OAuth client and doesn't support RFC 7591 Dynamic Client Registration — i.e. when the local install path is fundamentally broken on Claude Code's auth model. Schema documented at the top of the YAML. Confirmed cases: `slack`. The field is conservative on purpose — only flag entries whose local install has been confirmed broken via a failed OAuth attempt, not anything that *might* be broken.

- **Installer REQUIRES BRIDGE status.** When an entry has `requires_bridge: true` AND the bridge isn't detected, `thinkos-install-bundle.sh` now prints a `REQUIRES BRIDGE: enable '<name>' in claude.ai` status instead of attempting the doomed local registration. A new section in the install summary (Phase 6.6) tells the user exactly which connectors need claude.ai bridge enablement and links to https://claude.ai/settings/connectors. OAuth checklist excludes these (filter is already `status == OK`).

### Why this matters

The catalog was implicitly assuming every `mcp_remote` entry supports DCR for local install. Slack breaks that assumption, and any future vendor with a hard-coded OAuth App model will too. The new `requires_bridge` field is the declarative escape hatch: an entry can ship as "bridge-only" without losing its catalog presence, the installer routes around the broken path, and the user gets a clear single-line action ("enable this in claude.ai") instead of a Claude Code error message ten minutes later.

Three back-to-back hotfixes in a few hours across two users' installs — v0.8.1 and v0.8.2 came out of Chris Nappi's install (leaked plist templates, then `/thinkos-update` dead-ending on his pre-v0.8 manifest); v0.8.3 came out of Dave Drager's install (Slack DCR failure plus the items-parser bug found while testing the fix). Each surfaced a different layer of the same general gap: the install path made assumptions that didn't have graceful escape hatches when they broke. All three are now closed.

Audit-the-others work is intentionally not in this release. The new field is documented; future cases get added one at a time as users report failed local OAuth, rather than speculatively flagging entries that might still work.

## [v0.8.2] — 2026-05-18 — Hotfix: `/thinkos-update` dead-ends when the repo can't be found

Same user (Chris) hit a second snag right after the v0.8.1 fix. After cleaning up the leaked plists and being told to "run `/thinkos-update --pull` to pick up the fix," his agent reported: "The install manifest doesn't have a `repo_path` and I can't find a checkout anywhere. Where's the Think OS repo I should clone from?"

The v0.8.1 advice was right for someone on v0.8.x. For Chris — installed on v0.7.x with a v1 manifest that has no `repo_path`, and a checkout that has since been deleted — `/thinkos-update` had no way to find the repo, and the skill told the agent to "stop" instead of guiding through recovery.

### Fixed

- **`/thinkos-update` Step 0 — broader path resolution.** Previously tried `repo_path` from the manifest, then fell back to a single default (`~/code/think-os`), then stopped. Now scans four common locations (`~/Code/think-os`, `~/code/think-os`, `~/Documents/think-os`, `~/Documents/Think/think-os`) before declaring "no repo found." Also explicitly checks for `.git/` to distinguish a real checkout from a tarball drop.

### Added

- **`/thinkos-update` Step 0a — recovery flow.** When no valid checkout is found, the skill now walks the user through a clone + re-run setup, with `AskUserQuestion` chips for the clone target (`~/Code/think-os` recommended, `~/Documents/think-os` alternative, custom path, cancel). Setup is idempotent — it rewrites the `~/.claude/CLAUDE.md` block to the latest content, re-copies all slash commands (including any new ones), and writes a fresh v2 manifest with `repo_path` set correctly. The user's vault is untouched throughout. After successful recovery, the skill explicitly tells the user to restart Claude Code (Cmd+Q) and that `/thinkos-update` will then work normally for future releases.

### Why this matters

The v0.8.1 hotfix message I sent Chris ("run `/thinkos-update --pull`") was inadvertently bad advice for his specific install state — he couldn't run that command because there was no repo to pull into. This wasn't a bug in v0.8.1; it was a pre-existing gap in `/thinkos-update`'s no-repo handling that v0.7.x users had been quietly hitting. v0.8.2 closes that gap with a real recovery flow rather than a "sorry, stop" dead-end.

Three releases in a single day driven by a single user's bug report cascade (the install confused his agent → my fix message confused his agent → the update flow didn't handle the recovery path). Each one closes the specific failure he hit AND the broader pattern it represents. The next user in any pre-v0.8 state will get walked through recovery by the skill instead of needing the maintainer's intervention.

## [v0.8.1] — 2026-05-18 — Hotfix: LaunchAgent plist templates leaking into the vault

A user installed v0.8.0 and his agent told him session capture was broken. It wasn't — but the agent saw three plist templates with unresolved `__SCRIPT_PATH__` / `__LOG_DIR__` / `__REPO_ROOT__` tokens sitting in his vault at `~/ThinkOS/vault/LaunchAgents/` and reasonably concluded the install was incomplete. The install was fine; the agent's diagnosis was wrong but the symptom was real.

### Fixed

- **`copy_templates()` in `scripts/thinkos-setup.sh` now excludes `LaunchAgents/`.** The function had explicit `continue` clauses for `instructions/` and `team/` (the other two non-vault template directories) but missed `LaunchAgents/`. Every v0.8.0 install copied all three `*.plist.template` files into the vault at `<vault>/LaunchAgents/`. They never belonged there — those templates exist to be processed by `scripts/install-launchd-job.sh`, `install-session-capture.sh`, and `install-sync-job.sh`, which read from the repo and write resolved plists into `~/Library/LaunchAgents/`. One-line fix per loop (two loops in the function); both now skip the directory.
- **`/thinkos-autosave` skill: explicit `$REPO_ROOT` resolution.** Previously said "resolved from the vault path or `~/.thinkos/install-manifest.json`" without giving the exact command. Now the skill writes `REPO_ROOT="$(python3 -c "...['repo_path']")"` inline for every script invocation in all four subcommands (`on`, `off`, `now`). Also adds an explicit "never look inside the vault for install scripts" sentence so future agents don't repeat the diagnostic error.
- **`/thinkos-capture-setup` skill: same `$REPO_ROOT` pattern applied to all seven `install-launchd-job.sh` invocations.** Was previously `bash scripts/install-launchd-job.sh <task>`, which only worked if the CWD happened to be the repo. Now `bash "$REPO_ROOT/scripts/install-launchd-job.sh" <task>`. The Step 0 preflight resolves `$REPO_ROOT` once at the top.

### Added

- **`thinkos-doctor.sh` check for leaked plists.** Detects `*.plist` or `*.plist.template` files under `<vault>/LaunchAgents/` and warns with the exact `rm -rf` command to clean them up. Existing v0.8.0 installs can run `bash scripts/thinkos-doctor.sh` to see the warning and apply the cleanup themselves. The check is silent if the directory doesn't exist (which is the new-install default).

### Migration for existing installs

If you installed v0.8.0 or earlier and see `<vault>/LaunchAgents/` in your file browser, it's safe to delete:

```bash
rm -rf "$HOME/ThinkOS/vault/LaunchAgents"
```

(Adjust the path if your vault is somewhere else.) The doctor command will tell you whether you have leaked plists and exactly what to delete.

### Why this matters

The bug is small — three orphan files in a vault. The downstream effect was much bigger: a Claude session reading the vault to help a user set up Think OS saw the orphan templates, decided the install was incomplete, and told the user the feature wasn't shipped. The user reported back to the maintainer. The actual install path (`/thinkos-autosave on` → reads skill → calls `install-session-capture.sh`) was always functional; the agent never got there because the leaked artifacts derailed its diagnosis.

Two fixes prevent recurrence: the file leak is closed at the source, and both relevant skills now spell out `$REPO_ROOT` resolution explicitly so a future agent can't make the same wrong inference even if some other infrastructure file leaks somewhere.

## [v0.8.0] — 2026-05-18 — Comprehensive hardening release

A planned multi-stream code review caught 113 issues — 23 P0, 42 P1, 36 P2, 12 P3 — across bugs, security, agent traps, redundancy, drift, and deploy-readiness. 96 are fixed in this release across 43 work packages executed by 21 parallel Sonnet agents. The remaining 13 P2/P3 defer to v0.9. Four findings require human input (legal, IT, security governance) and are documented as known v0.8 gaps. Full review with per-finding fix instructions at `.plans/2026-05-18-comprehensive-review/plan.md`.

### Fixed — security (ship-blockers for company rollout)

- **Shell injection in `scripts/lib/catalog.sh`** (F-S-001, F-S-005, F-S-008). Three functions — `catalog_get_field`, `catalog_filter_by_target`, `catalog_oauth_items` — interpolated shell variables directly into Python source via heredoc string interpolation. User-supplied `--items` values could break out of the literal and execute arbitrary Python. The fix passes values via `sys.argv` and via bash-collected stdin; the unused `catalog_yq` eval-based helper is removed entirely. Same security outcome with no API change for in-tree callers.
- **Non-atomic CLAUDE.md write** (F-S-002). `install_marked_block()` in setup.sh and update.sh wrote directly to `$target` with `> "$target"`, truncating before the new content was assembled. SIGTERM, disk-full, or a Python error mid-render would leave `~/.claude/CLAUDE.md` empty. Replaced with the `mktemp → mv` atomic pattern in both scripts (and now in the new shared lib).
- **`eval "$extracted"` in uninstaller** (F-S-003). `_load_manifest()` ran a Python snippet that printed shell assignments, then `eval`'d them. A tampered `~/.thinkos/install-manifest.json` could inject commands. Replaced with explicit per-key parsing using base64-encoded values so the bash side never sees an unquoted shell string.
- **Three more unanchored grep silent-skips** (F-S-004, F-S-014, F-S-022). The v0.7.4 fix was incomplete: the same loose substring pattern lived in `scripts/thinkos-setup.sh:317` (basic-memory registration), `scripts/thinkos-doctor.sh:365` (bundle health check), and `scripts/thinkos-uninstall.sh:504` (MCP removal). All three now use anchored `^<name>:` matches. Also added `set -o pipefail` to doctor.sh.
- **LaunchAgent logs at 644** (F-X-001). `~/Library/Logs/ThinkOS/*.log` files captured `claude -p` cron output (morning briefs, Granola summaries, Slack summaries) at world-group-readable permissions — local-admin readable on multi-admin Macs. Install scripts now `chmod 700` the log dir; `umask 0077` set at the top of `thinkos-cron-run.sh` and `thinkos-session-capture.sh`.
- **`install-manifest.json` at 644** (F-X-002). Leaked vault path, bundle, and MCP list to any local group member. Now `chmod 600` after write in both `_write_install_manifest()` and the v1→v2 migration script.
- **No root-invocation guard on five entry points** (F-X-009). Added `id -u == 0` exit at the top of `thinkos-setup.sh`, `thinkos-uninstall.sh`, `thinkos-install-bundle.sh`, `thinkos-update.sh`, and `install-launchd-job.sh`.
- **`uvx granola-mcp` unpinned** (F-X-004). Up to 14 PyPI fetch-and-executes per day with full user permissions. Pinned to `granola-mcp>=0.1`. Exact-version pinning deferred to v0.9 pending vendor audit (documented in catalog notes and `docs/setup-basic-memory.md`).
- **Shared-mode coverage gaps** (F-X-003). `60-shared-mode.md` only specified `search_notes` and `read_note`. `build_context` (graph traversal) and `recent_activity` (write feed) could leak `tier: sensitive` notes even with shared-mode on. Both are now explicitly covered. Added a new section to the same block clarifying that shared-mode is an agent-behavioral instruction, not an OS-level control.
- **Vault sync sensitive-path pre-check** (F-X-006, F-X-016). New `templates/.gitignore` ships `.private/`, `.vault/`, `*.tmp`, etc. `cmd_sync_vault` in `thinkos-git.sh` now aborts before `git add -A` if `.claude/`, `.ssh/`, `.gnupg/`, `.aws/`, or `.docker/` would be staged.
- **`thinkos-update.sh --pull` stopgap** (F-X-008). Surfaces the new commit SHA, prints a diff command, and warns about deferred GPG verification. Full signed-commit verification is a v0.9 item gated on key-management governance.
- **XML injection in install-session-capture plist write** (F-S-013). Vault path interpolated verbatim into XML; a path with `<` or `&` produced a malformed plist or could inject keys. Now uses `xml.sax.saxutils.escape()` plus `plutil -lint` validation before `launchctl load`.

### Fixed — agent traps and behavioral correctness

- **Bridge-misframing propagation** (F-I-001, F-I-024). Same "connectors live in desktop agent" issue we fixed in v0.7.5 for `/thinkos-mcp-help` lived in four more slash commands: `/thinkos-plate`, `/thinkos-morning`, `/thinkos-reindex`, `/thinkos-stale`. Each now carries the bridge clause. `/thinkos-morning`'s Calendar bullet checks `mcp__claude_ai_Google_Calendar__list_events` via `ToolSearch` before redirecting to desktop agent.
- **`/thinkos-capture` decision ordering** (F-I-002). Decision mode said "newer at top" but used `operation="append"` which put new entries at the bottom. Switched to `operation="prepend"` in decision mode and in the session-recap mode's table.
- **`/thinkos-voice` description mismatch** (F-I-003). Frontmatter said "Rewrite a draft" but the command logs training samples. Description corrected to match behavior.
- **Linear vs Jira disambiguation in `/thinkos-capture-setup`** (F-I-004, F-I-025). The Linear setup path tried the Atlassian MCP and labeled the resulting Jira data as "Linear via JQL" — a wrong-service claim that would silently ingest the wrong data. Split into two independent paths: a Linear path (only if `mcp__claude_ai_Linear__*` exists, installs `com.thinkos.linear`) and a Jira path (only if Atlassian's JQL tool exists, installs `com.thinkos.jira`).
- **Hardcoded `--project think-os` in `/thinkos-reindex`** (F-I-006). Broke multi-vault. Now resolves the active vault's `bm_project` from `~/.thinkos/active-vault` → `vaults.json` default → fallback.
- **Adapter `instructions.md` exception clauses** (F-I-005). The "Always Available: Basic Memory MCP" section listed 7 queries with no exception clauses — read alone, it created an unconditional 7-query mandate that contradicts the priority preamble. Added a sentence pointing at the preamble's exception rules.
- **Dead-reference cleanup** (F-I-007, F-I-008, F-D-004): 6 missing slash command files created (`thinkos-doctor`, `weekly-review`, `quarterly-review`, `recent-log`, `draft-reply`, `validate-os`, `index-projects`). Routing table entries that pointed at them now resolve. `MAINTENANCE.md` references work end-to-end. Templates that mention `/weekly-review` and `/quarterly-review` are no longer lying.
- **Skill routing table missing native skills** (F-I-027). Added explicit routing triggers for `decisions`, `draft-reply`, `morning`, `who`, `project`, `weekly-review`.

### Fixed — drift between claimed and actual state

- **Linear launchd task didn't exist** (F-D-001). `/thinkos-capture-setup` told users it installed `com.thinkos.linear`; the dispatcher had no `linear` case. Now wired end-to-end: install-launchd-job.sh case, thinkos-cron-run.sh dispatcher, new `scripts/cron-prompts/linear.txt`.
- **Slack `--slack-handle` flag** (F-D-002). The command passed it to install-launchd-job.sh which silently ignored it. Now parsed, with the handle persisted to `~/.thinkos/slack-handle` (mode 600).
- **Session-capture writing to deprecated path** (F-D-003, F-X-010). `thinkos-session-capture.sh` still wrote to the pre-v0.4.2 `~/.thinkos/capture-log.jsonl` location while every other component used the vault note `90 System/Capture Log.md`. The dual-write meant `/thinkos-recent`, `/thinkos-vitals`, and the audit trail all missed session-capture events for every autosave user. Refactored to write only to the vault note, with vault path resolved via `vaults.json`. The legacy JSONL path is now removed from the script entirely.
- **operations skill bundle dropped silently** (F-D-009, F-C-011). `ops` preset included `operations` but the catalog entry has no `claude_code` block — installer dropped it with a confusing "Skipped (not available)" message. Removed from preset; catalog notes explain it's pending marketplace availability.
- **manifest.yaml + AGENTS.md missing `70-claude-ai-bridge.md`** (F-D-006, F-D-007). The v0.7.5 bridge block was added to scripts and to `00-think-os-priority.md`'s pointer, but `setup/manifest.yaml`'s `composed_with` list and `AGENTS.md`'s curated list both stopped at `60`. Both now list all 9 blocks.

### Fixed — catalog and templates

- **10 unverified MCP URLs removed from active presets** (F-C-001..F-C-010, F-D-012). `ms365`, `linear`, `asana`, `monday`, `fireflies`, `otter`, `amplitude`, `pendo`, `similarweb`, `intercom` all had placeholder URLs with `TODO: verify` comments. Each is now `available: false` with `url_verified: false` and an explanatory note. `linear` is out of `pm`/`eng` presets; `ms365` is out of `ops`. A new `url_verified` boolean field survives JSON serialization (replacing the YAML-only TODO comments) and is enforced by the new lint.
- **`trust_level` field added to every catalog entry** (F-X-014). Values: `anthropic-official` (skill bundles), `vendor-provided` (HTTP MCP endpoints), `third-party-unverified` (granola pending audit). The installer's confirmation table will eventually surface this; for v0.8 it's a declarative field that downstream tools can read.
- **New `scripts/lib/lint-catalog.sh`** (F-X-005). Fails if any URL contains `TODO`, if any `url_verified: false` entry is in a preset, if YAML and JSON drift, or if a preset references a nonexistent catalog id. Run by `thinkos-doctor.sh` and intended for CI.
- **Personal-name leak in 4 team-vault example files** (F-C-018). `@dhiraj` and `@sarah` appeared as realistic-looking handles in shipped example files. Replaced with the neutral fictional handles `@alex` and `@maya`. The fourth file (`05 Learnings/_example-2026-05-12-rate-limiting-pattern.md`) wasn't in the original spec — the agent found it during the scrub.
- **Maintainer paths/dates in templates** (F-C-019, plus an agent find): `templates/05 Profile/Business Brain.md` had `~/Documents/Think/Claude OS/business-brain.md` hardcoded as a "maintainer's reference copy" path, plus a hardcoded `2026-05-13` date in `last_reviewed` and the footer. Both replaced — the path becomes a neutral prompt, the date becomes `{{YYYY-MM-DD}}` substituted at install.
- **`90 System/Capture Log.md` missing as a template** (F-C-021). 8 cron prompts and 4 scripts wrote to or read this file, but no template shipped, so fresh installs would hit "note not found" on first capture. Template added; `thinkos-setup.sh` copy_templates initializes it; `thinkos-cron-run.sh` bootstraps it on first append.
- **session-capture plist hardening** (F-C-013, F-C-014, F-C-015, F-S-013, F-X-019). Renamed to `.plist.template` for consistency with the other two plists. Added `EnvironmentVariables` block with PATH (was missing — caused silent failure on Apple Silicon where python3 is at `/opt/homebrew/bin/python3`). Added `WorkingDirectory`. Split `StandardErrorPath` to its own `.err` file. XML-escapes paths in the substitution. `plutil -lint` validation added before `launchctl load`.
- **CODEOWNERS template** (F-C-020, F-C-022). `templates/team/CODEOWNERS` had `{{TEAM_LEAD}}` tokens but no `.template` suffix — install scripts treated it as a literal file. Renamed to `.template`. `thinkos-vault.sh`'s vault-creation pass now substitutes all 9 documented template tokens (`PROJECT_NAME`, `PROJECT_LABEL`, `BM_PROJECT_NAME`, `UID`, `CREATED_AT`, `TEAM_LEAD`, `TEAM_LEAD_NAME`, `TZ`, `EXPORT_REPO_URL`) recursively, then renames `CODEOWNERS.template` → `CODEOWNERS`.

### Fixed — token efficiency

- **Adapter `instructions.md` from 122 → 83 lines** (F-I-013..F-I-018). Removed 5 redundant sections that duplicated content already in the priority preamble or `30-think-os-write-targets.md` (capture habit, write targets table, fallback, draft-never-send, freshness). Net savings: ~40 lines / ~600 tokens per session, with no behavioral change.
- **Shared bash functions extracted to `scripts/lib/render-instructions.sh`** (F-S-021, WP-28). `curated_instruction_files()`, `render_template()`, `render_think_os_block()`, `install_marked_block()` were copy-pasted between setup.sh and update.sh. The v0.7.4 drift bug was a direct consequence of this duplication. Both scripts now source the shared lib; each function defined exactly once.

### Fixed — robustness and miscellaneous

- **`thinkos-cron-run.sh ledger_append` no longer builds JSON via string concat** (F-S-017). Now invokes `python3 -c "import json; print(json.dumps(...))"`.
- **`thinkos-cron-run.sh run_deterministic` no longer uses `bash -c "$cmd"`** (F-S-009). Takes args as an array; uses `"$@"`. Same defense applied to `flock`-protected ledger appends in cron-run and session-capture (F-S-023).
- **`thinkos-index.sh` no longer pipe-delimits folder paths** (F-S-019). Pipe delimiter broke on folder names containing `|`. Now passes folders as separate argv.
- **`thinkos-vault.sh` predictable `/tmp/thinkos-migrate-bm-warn` path** (F-S-011). Replaced with `mktemp`-generated path.
- **`thinkos-vault.sh` `cmd_create_project` vault.json write atomic** (F-S-018). Uses the `mkstemp + os.replace + chmod 600` pattern from the registry.
- **`thinkos-vitals.sh` Python errors no longer produce JSONDecodeError cascades** (F-S-026). Top-level try/except returns valid error JSON; bash guards against empty output.
- **`thinkos-migrate-manifest-v1-to-v2.sh` cleans up temp file on failure** (F-S-010). Added `trap 'rm -f "$TMP"' EXIT`.
- **`thinkos-capture-rotate.sh` deprecation header + flock** (F-D-010, F-S-023). Script is now self-documenting as deprecated and exits early if the legacy JSONL path isn't found. The gzip+truncate sequence is now `flock`-protected against concurrent appender writes.
- **Subshell scope bug in `cmd_list`** (F-S-027). Changed pipe to process substitution.
- **awk-based `render_template` had metacharacter bug** (F-S-025). A vault path containing `&` would have corrupted template substitution. Replaced with Python `str.replace()` which doesn't interpret replacement metacharacters.

### Added

- **Data disclosure phase in `setup/manifest.yaml`** (F-X-011 partial). One-paragraph explanation of which cron tasks send vault content to Anthropic via `claude -p` and which run fully local. The full opt-out path (`--local-only` flag, DPA review) is a v0.9 item.
- **`THINKOS_MASK_CWD=1` env var support in session-capture** (F-X-020). For consultancies where directory names encode client names, set this to mask CWD to its basename only in the ledger.
- **Session-capture project filter** (F-X-015). Now defaults to capturing only sessions whose `cwd` is under a registered vault path from `vaults.json`. `--all-projects` flag preserves the old behavior.
- **Log rotation cap** (F-X-007). LaunchAgent log files rotate when they exceed 1MB.
- **Uninstall cleanup completeness** (F-X-013). `thinkos-uninstall.sh` now calls the three `uninstall-*.sh` helpers for every known task id, removes `~/Library/Logs/ThinkOS/` (unless `--keep-logs`), removes the legacy capture-log artifacts, and conditionally removes `~/.thinkos/backups/` with `--remove-backups`.
- **`thinkos-doctor.sh` plist-path check** (F-X-019). Iterates installed `com.thinkos.*.plist` and warns if any references a script that no longer exists on disk.
- **Basic Memory privacy section in `docs/setup-basic-memory.md`** (F-X-018 partial). Documents `--local --default`, the config.json verification command, the `lsof` audit command, and the IT-review pointer.

### Deferred to v0.9

13 P2/P3 findings tracked but not addressed in v0.8; see `.plans/2026-05-18-comprehensive-review/plan.md` §10. The four human-input gates (F-X-011 legal/DPA, F-X-012 enterprise mode, F-X-018 IT review process, F-X-008 full GPG signing) are documented in §9 as company-rollout prerequisites.

### Why this matters

The bug class that produced v0.7.4 through v0.7.6 was systemic, not localized. Each prior release fixed one instance of a pattern — silent skip, agent trap, claimed-but-unwired — while three more instances of the same pattern sat in the codebase waiting to surface. v0.8 is the release that goes wide instead of going deep: 5 parallel reviewer agents found the rest, 21 parallel executor agents fixed them, and the result is a codebase where the three pattern classes are now linted, tested, and documented.

The security findings move Think OS from "fine for a personal install" to "deployable to ~100 colleagues at a consultancy with caveats." The four caveats — DPA, MDM/enterprise mode, IT review of Basic Memory, GPG signing — are documented as v0.9 gates rather than buried as risks. Anyone can install the v0.8 release on their own machine without any of those being resolved.

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
