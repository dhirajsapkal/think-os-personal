---
type: design-doc
tags:
- architecture
- memory
- token-efficiency
- evidence
permalink: think-os/docs/why-files-not-a-database
---

# Why Files, Not a Database

The canonical answer to the most common architecture challenge Think OS gets: *"Markdown files? Shouldn't this be a vector or graph database? Doesn't reading files make the agent hallucinate?"*

Short version: **you're already running a database — it's just derived from the files instead of replacing them.** The evidence says verbatim file reads are the *strongest* grounding this system has, the vendor benchmarks for memory databases collapsed under re-evaluation, and zero of the token savings shipped in v0.9.3 required a database. The full audit behind every number here is `.plans/2026-06-10-memory-architecture-research/report.md` (in the repo's planning history); load-bearing figures were re-verified by two independent judges.

---

## 1. Markdown is already fronted by a hybrid database

"Files vs a real database" is a false dichotomy for Think OS. Basic Memory — the MCP server every agent reads through — maintains, derived from the markdown:

- **SQLite FTS5 full-text index** (`search_index`, full note bodies indexed)
- **Local vector embeddings** (fastembed bge-small-en-v1.5, 384-dim, sqlite-vec — zero API calls, fully offline)
- **A typed entity/relation knowledge graph** built from wikilinks and categorized observations, traversed by `build_context` with recursive CTEs
- **Hybrid retrieval** as the default: BM25 + cosine score fusion

All of it is **derived and rebuildable** (`basic-memory reindex` recreates it from scratch). `read_note` streams the markdown from disk — always exact, always fresh. The files are canonical; the database is a cache. That's the architecture, stated precisely: *not* "no database," but "no database as the source of truth."

## 2. The evidence verdict

**No study ties hallucination to file format.** The 2025–2026 faithfulness literature locates hallucination in excessive/irrelevant context, missing context, and parametric override — all format-agnostic. Hallucination persists 6–28% even when *correct* context is provided (arXiv 2505.04847).

**On this system, measured live, the query-mode artifacts were the least trustworthy outputs** — the opposite of the "files cause hallucination" claim:

- Search snippets are undated mid-sentence fragments.
- `build_context` truncates bodies mid-word at 4,000 chars (inviting prior-completion) and double-injects observations.
- `recent_activity` returned duplicated, undated entries.
- The live FTS index was silently corrupted by a concurrent-writer race (§6).
- **Verbatim `read_note` of a markdown file returned exact, auditable file content in every measured case — zero hallucination surface.** Whole-file reads of small HOT files (Identity ~1.2k tokens, Current Focus ~1.65k) are the grounding; v0.9.3 deliberately does not optimize them away.

**The vendor benchmarks for dedicated memory databases did not survive re-evaluation:**

- Zep's headline 84% LoCoMo dropped to **58.44%** when re-run (zep-papers issue #5); no independent replication exists.
- In **Mem0's own paper** (arXiv 2504.19413), plain full-context beat every memory system on accuracy.
- A plain-file agent scored **74.0%** LoCoMo vs Mem0's graph variant at **68.5%** ("Is a Filesystem All You Need?").

The field converged the same way: Letta's git-backed markdown Context Repositories, Anthropic's file-based memory tool, and Claude Code dropping its vector index pre-launch ("agentic search generally works better").

## 3. What a migration would actually cost

Honest pricing, from the steelmanned migrate-to-a-DB proposal that lost the v0.9.3 bake-off:

- **4–6 weeks of work**, and it breaks four load-bearing properties:
  - the **git-syncable vault** (diffable, mergeable, multi-machine via `/thinkos-sync`),
  - the **offline/local-only** path (fastembed runs with zero API calls; Mem0/Zep-class systems want Qdrant/Neo4j/Postgres, Docker, API keys),
  - **external-editor and Obsidian writes** (anything that isn't the extraction pipeline becomes a second-class writer),
  - the **file-first philosophy** users adopted Think OS for.
- It **adds cost and hallucination at write time**: every capture pays LLM extraction calls (uncounted in vendor "efficiency" claims), and LLM-built knowledge graphs capture only **~65.8% of answer entities** (arXiv 2502.11371) — facts silently lost or distorted before retrieval even starts. Verbatim markdown writes lose nothing.

## 4. The attribution table — none of the savings needed a database

v0.9.3 cut the `/thinkos-morning` path from ~17.6k to ~8.2k tokens per session. Attribution of the ~9.7k saved:

| Saving | ~Tokens | Mechanism | Needs a DB? |
|---|---|---|---|
| Instruction-stack diet (9.3k → ~4.2k) | ~5.1k | Prose editing + skill conversion | No |
| Mandated search pair at `page_size=3` | ~1.1k | A call parameter | No |
| Drop redundant identity re-search in playbooks | ~0.75k | Playbook discipline | No |
| Tasks read scoped to the `## Today` section | ~2.5k | A markdown heading + deterministic extraction | No |
| Playbook trims | ~0.3k | Prose editing | No |

**Zero of the ~9.7k tokens saved require a vector or graph database.** Every lever was scoping, a parameter, or an anchor in a markdown file. The same holds for the other paths: `/recent-log` (20.2k → ~6.2k via date-window shell extraction from the file on disk) and capture dedup (full 6.5k ledger read → ~0.5k tail).

## 5. What a dedicated memory system genuinely does better

Credit where due — and the deterministic, zero-LLM-cost equivalents v0.9.3 ships instead:

| Dedicated-system capability | What it buys | v0.9.3 equivalent |
|---|---|---|
| Temporal edge validity (t_valid/t_invalid on relations) | Knowing which of two conflicting facts is current | `supersedes:` / `superseded-by:` convention on Decisions entries (`templates/04 Knowledge/Decisions.md`) |
| Automatic entity resolution | "AC", "@alexc", and "Alex Chen" resolve to one person | `aliases:` line per People entry (`templates/03 People/People.md`) |
| Auto-extraction from high-volume raw streams | Memory without manual capture | Not needed at personal-vault scale; continuous-capture jobs + the capture habit cover it deterministically |

None of the dedicated versions pays off at personal-vault scale; all of them import per-write LLM cost and extraction error.

## 6. The one real bug — and its actual fix

The strongest exhibit *against* the current setup is real: the live Basic Memory SQLite FTS index was found corrupted — 51/122/161 `search_index` rows vs 36/99/122 actual entities/observations/relations, duplicates up to 4×. Cause: multiple per-session Basic Memory servers racing delete+insert on an FTS5 table with no unique constraints. Consequence: duplicated/inflated search and `recent_activity` results until a reindex.

Note what this is: **a derived-cache bug, not a file bug** — the markdown was never wrong, and `basic-memory reindex` fully repairs the index from the files. In a database-as-truth design the same class of corruption would be unfalsifiable and unrecoverable.

The fix ships in layers:

- **Detection (v0.9.3):** `thinkos-doctor.sh` compares index rowcounts against actual entity/observation/relation counts and recommends `/thinkos-refresh` on mismatch; surfaced in `/thinkos-vitals`.
- **Long-term cure: single-shared-BM-server mode.** Run one Basic Memory server instance that all agent sessions connect to, instead of one server per session — a single writer cannot race itself. Documented here as the recommended posture once upstream supports it cleanly; not shipped as default in v0.9.3.
- **Upstream:** an issue with the live evidence and suggested fixes has been drafted for basicmachines-co/basic-memory (see `.plans/2026-06-10-memory-architecture-research/upstream-issue-draft.md`).

## 7. Bottom line

Think OS keeps markdown as truth not out of nostalgia but because the measurements say so: verbatim reads are the most grounded retrieval mode this system has, the hybrid index already provides the search a database would, the real waste was scoping (fixed mechanically in v0.9.3), and the migration on offer costs 4–6 weeks to break four things that work in exchange for write-time hallucination. When that calculus changes — genuinely high-volume streams, heavy multi-hop temporal queries — revisit. Until then: files are the source of truth; the database is a cache.
