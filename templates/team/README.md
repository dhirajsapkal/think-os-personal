---
uid: {{UID}}
type: readme
project: "{{PROJECT_NAME}}"
created: "{{CREATED_AT}}"
---

# {{PROJECT_NAME}} — Team Vault

This is a **Think OS project vault**: a shared, git-backed knowledge base for the team. It stores decisions, work activity, specs, and learnings — everything the team needs to stay aligned without leaking individual personal context into a shared repo.

Think OS export repo: `{{EXPORT_REPO_URL}}`

## What lives here

| Directory | Purpose | Pattern |
|---|---|---|
| `00 Project Home.md` | Project mission, status, quick links | Single file, edited via PR |
| `01 Work/` | Activity log — standups, session notes, outcomes | One file per entry: `YYYY-MM-DD-<slug>.md` |
| `02 Decisions/` | ADR archive — immutable records of team decisions | One file per decision: `YYYY-MM-DD-<slug>.md` |
| `03 Specs/` | Owned reference docs — API contracts, data models | One file per topic, edited via PR |
| `04 Roster.md` | Team member list with roles and handles | Single file, owner-gated |
| `05 Learnings/` | Reusable patterns and lessons from this project | One file per learning: `YYYY-MM-DD-<slug>.md` |

## What does NOT live here

No personal content: no work logs, identity files, current-focus notes, or private reflections. Those stay in your personal Think OS vault. This repo enforces that boundary structurally — there are no slots for personal content.

## How to contribute

**Adding a work entry, decision, or learning**

1. Create a new file in the relevant folder following the `YYYY-MM-DD-<slug>.md` naming pattern.
2. Copy the frontmatter from the `_example-*` file in that folder and fill in the required fields.
3. Commit and push. No PR required for append-only folders (see `CODEOWNERS`).

**Editing a spec or single-file slot**

Open a pull request. The `CODEOWNERS` file routes review to the right person automatically.

**Adding a teammate to the roster**

Open a PR editing `04 Roster.md`. Tag @{{TEAM_LEAD}} — their approval is required before merge.

## Schema validation

Each content type has a JSON Schema at `.thinkos/schemas/`. A pre-commit hook (installed when the vault was created) validates frontmatter before every commit. If your commit is rejected, check that all required fields are present and correctly formatted.

Required field quick reference:

- **Work entry**: `uid`, `type: work-entry`, `date`, `author`
- **Decision**: `uid`, `type: decision`, `date`, `status`, `deciders`
- **Spec**: `uid`, `type: spec`, `owner`, `status`, `last_reviewed`
- **Learning**: `uid`, `type: learning`, `date`, `author`, `tags`

UIDs are ULIDs — generate one with `scripts/lib/uid.sh` from the Think OS export repo, or any ULID library.

## Joining the team

1. Clone this repo: `thinkos vault clone <git-url>` (or `git clone <git-url>`)
2. The CLI registers the vault and indexes it into Basic Memory automatically.
3. Open `00 Project Home.md` to orient yourself.
4. Add yourself to `04 Roster.md` via PR.
