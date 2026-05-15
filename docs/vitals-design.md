# Vitals Design

Status: shipped · Target: v0.6.0 · Author: maintainer

## Rationale — why separate from doctor

`thinkos-doctor.sh` checks **install and setup state**: is the vault path present, is Basic Memory registered, are managed files in sync? It is cheap, safe to run in CI-like flows, and its status idiom (ok / warn / fail per named check) is designed for that purpose.

`thinkos-vitals.sh` checks **vault content health**: are HOT files freshly reviewed, are ledger entries accumulating, are cross-links intact? It is potentially expensive (ledger scan, link-graph walk) and its output is a per-file table rather than a check list.

Mixing them would force doctor to learn about vault content (an architectural smudge), make the `--strict` exit-code contract ambiguous, and obscure the fast-cheap / slow-expensive distinction. Both surfaces stay sharper when kept separate. See `spec.md` §3 and `open-questions.md` Q6.

## JSON schema (`--json` output)

```json
{
  "vault": "/path/to/vault",
  "as_of": "YYYY-MM-DD",
  "hot_files": [
    {
      "file": "01 Now/Current Focus.md",
      "last_reviewed_age_days": 4,
      "covers_week_expired": false,
      "lines": 87,
      "budget": 200,
      "status": "ok"
    }
  ],
  "warm_files": [
    {
      "file": "04 Knowledge/Decisions.md",
      "mtime_age_days": 12,
      "status": "ok"
    }
  ],
  "unreviewed_autocaptures": 12,
  "ledger_volume": { "7d": 47, "30d": 198 },
  "ledger_status": "ok",
  "broken_links": [
    { "from": "02 Projects/Acme.md", "to": "03 People/Jordan-Wells.md", "reason": "missing" }
  ],
  "section_ages": [
    { "section": "Decisions", "last_appended_days": 1, "status": "ok" },
    { "section": "Learnings", "last_appended_days": 22, "status": "ok" },
    { "section": "Work Log",  "last_appended_days": 3,  "status": "ok" }
  ]
}
```

### Status values

| Value | Meaning |
|---|---|
| `ok` | Within thresholds |
| `stale` | Past freshness threshold |
| `stub` | File exists but contains `<!-- thinkos:stub -->` marker — never seeded |
| `missing` | File does not exist at all |
| `no_entries` | File exists but has no date-headed entries (section ages) |
| `no_ledger` | Capture Log does not exist; unreviewed count returns 0 |
| `error` | File could not be read |

## Heuristic catalog

### HOT file freshness

HOT files are Identity, Current Focus, Project Index, and People. These are the files the agent loads every session from Basic Memory.

| Heuristic | Threshold | Source field |
|---|---|---|
| `last_reviewed_age_days` | Parse `last_reviewed:` frontmatter (ISO date), compare to today | `last_reviewed:` |
| `covers_week_expired` | Parse `covers_week: YYYY-MM-DD-to-YYYY-MM-DD`, check if end date < today | `covers_week:` |
| Stale status | Either `last_reviewed_age_days > 7` OR `covers_week_expired == true` | — |

If `last_reviewed` is absent or still a template placeholder, `last_reviewed_age_days` is `null`. The file is not flagged stale on that basis alone — it is either a stub (detected by `<!-- thinkos:stub -->`) or "unknown age."

People.md is listed as HOT in the `hot_files` array even though its template marks it WARM tier; it is included because the agent loads it every session and its freshness matters.

### Line budgets

| File | Default budget | Override |
|---|---|---|
| Current Focus | 200 lines | `budget:` frontmatter field |
| Project Index | 200 lines | `budget:` frontmatter field |
| Identity | 150 lines | `budget:` frontmatter field |
| People | 300 lines | `budget:` frontmatter field |

Line count is raw line count (`wc -l` equivalent). Budget is informational — vitals does not fail on over-budget files, it reports the ratio. Over-budget is a signal to run `/quarterly-review`.

### WARM file freshness

WARM files (Decisions, Learnings, People, OS Instructions) use mtime rather than frontmatter date. Threshold: **30 days**. Rationale: these files grow by append; the last time *any* change was made is the best proxy for engagement without parsing entry dates.

### Unreviewed autocaptures

Count of entries in `90 System/Capture Log.md` from the **last 30 days** where `source` is not `"manual"` and the entry does not have `"reviewed": true`. The 30-day window aligns with Q9's emergent-seeding cadence (3 deferrals → vitals resurfaces the prompt). If the ledger does not exist, count is 0 and `ledger_status` is `"no_ledger"`.

### Ledger volume

Raw count of JSONL entries within the 7-day and 30-day windows. Any source counts. Used to detect automation stalls — a 7d volume of 0 during an active week is a signal that session-capture or a connector is broken.

### Broken links — definition and scope

A link is considered broken if its target does not exist on the filesystem relative to the vault root (for wikilinks) or relative to the source file's directory (for markdown links).

**In scope**: wikilinks (`[[Target]]`, `[[Target|Alias]]`, `[[Target#section]]`) and markdown links (`[text](path)`) in HOT files and `02 Projects/*.md` only.

**Out of scope**: external URLs (`http://`, `https://`, `mailto:`), anchor-only links (`#section`), and all files outside the bounded scan set. Full vault link-graph walk is deferred to a future release.

**Resolution logic**:
1. Strip anchors and aliases from wikilinks.
2. Check if the target is an exact file path relative to vault root (with or without `.md` extension).
3. Fall back to a basename-only case-insensitive match across the entire vault.

Wikilinks referencing people names (e.g., `[[Jordan Wells]]`) resolve if any file named `Jordan Wells.md` or `Jordan-Wells.md` exists anywhere in the vault.

### Section ages

For append-only logs (Decisions, Learnings, Work Log), the script finds the most recent `## YYYY-MM-DD` heading and computes days since. If no date heading is found, status is `no_entries`. Older date-format variants (e.g. `## 2024 Dec 15`) are not matched — only ISO 8601 `## YYYY-MM-DD` is recognised.

## Robustness rules

- **Missing files**: every check returns `"status": "missing"` instead of failing. The script never calls `exit 1` on a missing vault file.
- **Stubs-only vault**: a fresh install with all stub templates produces a well-formed JSON document with all statuses as `"stub"` and counts at 0. The human output renders "STUB" for each row.
- **Unreadable files**: caught by `try/except OSError`; returns `"status": "error"` for that file.
- **Template placeholders**: frontmatter values like `{{YYYY-MM-DD}}` do not parse as dates; treated as absent.

## Future scope

- **Full vault link-graph walk** (deferred from v0.6.0): extend `broken_links` to scan all `.md` files, not just the bounded HOT + Projects set. Requires a smarter walk to stay within acceptable latency.
- **Trend tracking**: persist the JSON snapshot to `90 System/Vitals Log.md` (append-only) so `/thinkos-vitals` can show delta ("3 more stale files than last week").
- **Budget alerts**: surface files significantly over budget (e.g. >150% of budget) as a dedicated section rather than just a ratio in the table.
- **Stale connector data**: cross-reference ledger source fields against the connector install list from `~/.thinkos/install-manifest.json` to flag connectors that have gone silent.
