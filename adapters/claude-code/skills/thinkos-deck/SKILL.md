---
name: thinkos-deck
description: Build or improve a Google Slides deck, sourcing content from the Think OS vault and matching the user's voice. Use when the user asks to make, improve, redesign, polish or restyle a deck, mentions a docs.google.com/presentation URL with a request to change it, or asks for a workshare / readout / presentation from work already recorded in the vault.
---

# Think OS — decks

Drive the Google Slides API from a Python script, sourcing content from the vault
rather than asking the user to re-explain work they already recorded.

**What makes this different from a generic slides helper:** Think OS already knows
what they did. A workshare deck about a project should be built from that project's
Work Log entries, meeting notes, Decisions and Learnings — not from an interview.
Ask what the deck is *for*; derive what goes *in* it.

---

## Before anything: is this a build or an improve?

- **Build** — no deck exists. Source from the vault, draft an outline, confirm, then create.
- **Improve** — a deck exists. Read it, propose changes, apply incrementally.

Both paths share the script mechanics below. Only the sourcing differs.

---

## Discovery — three questions, not twenty

1. **What is this deck for, and who is in the room?** An internal workshare, a client
   readout and a conference talk are different artifacts.
2. **What is it about?** Take a project slug, a date range, or a topic. Then find the
   material yourself (next section) — don't make them paste content.
3. **How long?** Minutes, not slide count. 30 minutes with Q&A is ~12–15 slides.

Only ask a fourth question if branding is genuinely unknown. Default to Think Company's
identity from `05 Profile/Identity.md` and whatever brand assets the vault records.

---

## Sourcing from the vault

Search, in this order, scoped to the project or date range:

| Source | What it gives |
|---|---|
| `04 Knowledge/Meetings/*.md` | What was actually said and decided, verbatim |
| `01 Now/Work Log.md` | What was done, when — the spine of a "what we did" deck |
| `04 Knowledge/Decisions.md` | Why choices were made — the strongest slide material |
| `04 Knowledge/Learnings.md` | The "what we'd do differently" slide |
| `02 Projects/<slug>.md` | Scope, stakeholders, constraints |
| `01 Now/Current Focus.md` | Where it stands now |

Use `mcp__basic-memory__search_notes` scoped by project tag or `after_date`. Never read
the full Work Log — it is ~9k tokens; use `scripts/thinkos-recent.sh --worklog --days N --json`.

**Decisions and Learnings are the differentiator.** Anyone can list what happened. A deck
that says *why* a choice was made, quoting the decision record, is the one worth sitting
through.

**Quote rather than paraphrase** where a meeting note has the actual words. Attribute it.

### Privacy

Vault content includes `tier: sensitive` notes and meeting transcripts carrying
compensation, health and personnel discussion. Apply the word-boundary tiered rules from
`scripts/cron-prompts/granola.txt` Step 4b before putting anything on a slide. When
shared-mode is on, exclude sensitive notes entirely — a deck is by definition shared.

Client names: per the user's Identity guardrails, never name a client in a deck unless
this deck is explicitly for or about them.

---

## Voice

Read `05 Profile/Voice Profile.md` and match it. It is long; read the **Hard rules** and
the channel section closest to a presentation.

From the user's Identity, non-negotiable in any draft: **no consultancy-speak.** Never
"leverage", "synergies", "best-in-class", "unlock value", "robust solution", "end-to-end",
"double down", "north star". Plain words. Clients and execs can tell.

Slide copy is tighter than prose: a headline that states the claim, then evidence. If a
bullet needs a comma splice it is two bullets, or it is speaker notes.

---

## Required tools

- `pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib`
- OAuth desktop-app credentials at `~/.claude/google-oauth/credentials.json`, Slides API
  enabled on the GCP project
- Token cached at `~/.claude/google-oauth/slides_token.json`, created on first run

If credentials are missing: console.cloud.google.com/apis/credentials → create an OAuth
2.0 Client ID of type **Desktop app** → download to that path. First run opens a browser
for consent.

Copy `script_template.py` beside the deck's working files, fill the constants block, run
by phase.

---

## Workflow

### 1. Read the deck (improve path only)

`presentations.get` for structure; the Drive text export for a readable pass. Note slide
count, which have titles, which are placeholder-empty.

### 2. Back up before touching anything

`drive.files.copy` to `<name> — backup <YYYY-MM-DD>`. Report the backup URL **before**
the first write. Non-negotiable: Slides has no undo you can drive from the API, and the
user has already lost a deck to an un-undoable automated pass.

### 3. Plan, then confirm

Show the outline — slide by slide, one line each, with its vault source. Wait for
confirmation before writing. For an improve, show what changes and what stays.

### 4. Dry-run, then apply per phase

`--dry-run` prints the request payloads without sending. Then apply **one phase at a
time**. Never one 100-request `batchUpdate`: a single bad request rolls back the whole
batch.

### 5. Render and verify every slide you touched

Export each touched slide as a thumbnail and look at it. Text running off the bottom,
centered card text, a missing icon — none of these appear in the API response. They only
appear in the render.

### 6. Ledger it

Append one event to `90 System/Capture Log.md` via
`mcp__basic-memory__edit_note(identifier="Capture Log", operation="append", ...)`.
**End the line with a newline, and never shell out with `>>`.** A bare append
onto a file that does not already end in `\n` glues this event onto the previous
one and makes both unparseable — see
[capture-log-schema.md](../../../../docs/continuous-capture/capture-log-schema.md#appending-safely).

```json
{"ts":"<ISO8601 UTC>","source":"deck","detail":{"deck_id":"<id>","title":"<name>","phases":[...],"slides_touched":<n>,"backup_url":"<url>"},"output":"<deck url>","mode":"update","bytes":0}
```

---

## Idempotency

Every phase is safe to re-run; a failed run resumes rather than duplicating.

- Text replacement: no-op when the old string is absent.
- Titles: skip slides that already have title text.
- New slides: skip when a slide with that exact title exists.
- Body styling: `updateTextStyle` fails on empty text — guard it.
- Icons: skip slides that already carry an image.

---

## Failure modes

Carried from hard-won experience. Read before writing request builders.

| Failure | Cause | Fix |
|---|---|---|
| Whole batch rolled back | One bad request in a large `batchUpdate` | Per-phase batches; per-icon batches for images |
| `createImage` 400 "image not found" | Icon slug does not exist | curl-probe the URL first; only use verified slugs |
| `createImage` 400 "problem retrieving" | Fetcher flake on a valid URL | Retry 3× with backoff, then swap slug |
| `updateTextStyle` 400 "no text" | Placeholder is empty | Guard with a has-text check |
| Anchor slide not found | Title differs after an edit or reorder | Re-fetch the deck before each insertion; match on exact title |
| Card text centered or ragged | `ROUND_RECTANGLE` defaults to CENTER | `updateParagraphStyle` `alignment: START` |
| Text runs off the slide | Font too large or too many lines | Render the thumbnail; drop the pt or split the slide |
| TOC links break after reorder | Linked by `slideIndex` | Link by `pageObjectId` |
| Substring replace corrupts text | `replaceAllText("PEC.md","SPEC.md")` matches inside `SPEC.md` | Check for substring overlap before replacing |
| `&#11;` / `&#9;` in a Drive export | Real soft line breaks and tabs | Leave them — stripping destroys intended breaks |
| `ValueError: invalid literal for int()` | A 3-digit CSS hex like `#EEE` | Expand shorthand in `hex_to_rgb` |
| New slides look unbranded | Styling phase ran before the slides existed | Style new slides in their own batch, after creation |

---

## Slide patterns

- **Prose → cards.** A dense paragraph becomes 2–4 rounded rectangles with a bold lead
  and one supporting line. Column cards for parallel items; an X-vs-Y split for a
  comparison; a 2×2 for a matrix.
- **Real tables**, not tab-delimited text in a box.
- **Linked table of contents** for anything over ~15 slides, linked by `pageObjectId`.
- **Example slides beat assertion slides.** A screenshot of the thing, annotated, is
  worth three bullet slides about the thing.

---

## Guardrails

- **Back up first.** Always. Report the URL before writing.
- **Never write without showing the outline and getting confirmation.**
- **Never invent content.** Every claim traces to a vault note, a meeting record or
  something the user said in this conversation. A deck is presented to other humans —
  a fabricated number is worse here than anywhere else.
- **Attribute numbers.** If a figure comes from a source whose methodology is unclear,
  say so on the slide or cut it. (Observed case: a 2.3× figure was estimated-vs-actual
  from a sales sheet, not the AI-vs-manual comparison the deck implied.)
- **Render before declaring done.**
- **Never share or change permissions** on a deck.
