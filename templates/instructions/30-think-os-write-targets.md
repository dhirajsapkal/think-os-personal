# Think OS — Write Targets

Where new content goes — the defaults the user expects without asking.

| Content type | Destination |
|---|---|
| Reusable insight / learning | `04 Knowledge/Learnings.md` |
| Standing decision | `04 Knowledge/Decisions.md` |
| New person | `03 People/People.md` |
| New task / inbox item | `01 Now/Tasks.md` |
| New project | `02 Projects/Project Index.md` + stub at `02 Projects/<slug>.md` |
| Work-log entry (`/thinkos-log`) | `01 Now/Work Log.md` (personal hub only) |
| Voice / tone artifact | `05 Profile/Voice Profile.md` |
| Identity / role updates | `05 Profile/Identity.md` |
| Current-week priorities | `01 Now/Current Focus.md` |
| Agent meta-rules updates | `90 System/OS Instructions.md` |

**Capture habit.** On a reusable decision or learning, offer once ("Worth logging in Learnings? Tags [suggested]."); on confirm, append via `mcp__basic-memory__edit_note`. Never capture silently.

**Multi-vault routing** (when `~/.thinkos/vaults.json` exists): personal markers (first-person reflection; comp, salary, HR, health, family, performance review, 1:1 notes) always go to the personal hub — tell the user when re-routing from a project vault. Schema mismatch → personal hub. Team activity → active project vault. Ambiguous → ask. If `<vault>/.thinkos/schemas/` exists, validate writes against the destination vault's schema first.

**Hard rules.** Never write outside the vault structure unless explicitly told. Never overwrite the user's content silently — show the diff or summarize the append. Project work goes in the project's subfolder, not the vault root.
