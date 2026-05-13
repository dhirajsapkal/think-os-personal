# Think OS — Write Targets

Where new content goes. Memorize this — these are the defaults the user expects without asking.

## Content-type routing

| Content type | Destination |
|---|---|
| Reusable insight / cross-project learning | `04 Knowledge/Learnings.md` |
| Standing decision (architectural, process, policy) | `04 Knowledge/Decisions.md` |
| New person mentioned (colleague, client, vendor) | `03 People/People.md` |
| New task / inbox item | `01 Now/Tasks.md` |
| New project surfaces | `02 Projects/Project Index.md` + new stub at `02 Projects/<slug>.md` |
| Manual work-log entry (`/log`) | `01 Now/Work Log.md` (personal hub only) |
| Voice / tone artifact | `05 Profile/Voice Profile.md` |
| Identity / role updates | `05 Profile/Identity.md` |
| Current-week priorities | `01 Now/Current Focus.md` |
| Agent meta-rules updates | `90 System/OS Instructions.md` |

## Capture habit

When the user makes a reusable decision or shares a learning, offer once:

> Worth logging in Learnings? I can add it with tags [suggested].

If they confirm, append via `mcp__basic-memory__edit_note` (operation: `append`). Don't capture silently; the offer-then-confirm pattern is intentional.

## Multi-vault routing rules

If `~/.thinkos/vaults.json` exists, the active vault matters (see `docs/multi-vault-architecture.md` §8):

- **Personal markers always go to the personal hub.** First-person reflection, or any of: comp, salary, HR, health, family, performance review, 1:1 notes. If the active vault is a project vault, route to personal hub anyway and tell the user: `"This sounds personal — routing to your personal hub instead of the project vault."`
- **Schema mismatch → personal hub.** If the active vault's schema has no slot for this content type, write to personal hub.
- **Team activity → active project vault.** Meeting notes, project decisions, team-shared learnings.
- **Ambiguous → ask.** Don't guess on borderline content.
- If `<vault>/.thinkos/schemas/` exists, validate writes against the destination vault's schema for that content type before committing.

## Hard rules

- **Never write above project folders.** `~/Documents/` root, `~/Desktop/`, anywhere outside the vault structure is off-limits unless explicitly told.
- **Never overwrite the user's content silently.** When editing an existing note, show the diff or describe the change before committing. For appends to logs/lists, summarize what was appended.
- **Project work goes in the project's subfolder**, not at the vault root.
