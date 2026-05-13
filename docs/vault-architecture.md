---
type: architecture-note
tags:
- obsidian
- vault
- ux
- architecture
permalink: think-os/vault-architecture
---

# Vault Architecture

Think OS is organized for two audiences at once:

1. **Humans opening the vault in Obsidian**
2. **Agents reading and writing through Basic Memory MCP**

The vault should feel like a small workspace, not a directory dump. The root stays quiet: `00 Home.md` plus numbered areas.

## Human Map

| Area | Human question it answers | Notes |
|---|---|---|
| `00 Home.md` | "Where do I start?" | Front door, first-fill checklist, vault map |
| `01 Now/` | "What matters this week?" | Current Focus, Tasks, Work Log |
| `02 Projects/` | "What am I working on?" | Project Index plus one note per project |
| `03 People/` | "Who is this person?" | Lightweight personal CRM |
| `04 Knowledge/` | "What have I already learned or decided?" | Standing Decisions and Learnings |
| `05 Profile/` | "Who am I, how do I sound, what business context matters?" | Identity, Business Brain, Voice Profile |
| `90 System/` | "How does the OS work?" | Agent instructions and connector inventory |
| `99 Archive/` | "What used to be active?" | Rotated logs and dormant notes |

## Why `Project Index.md`

The first structure had both `active-projects.md` and an `active-projects/` folder. That was technically useful but visually confusing in Obsidian.

The new structure makes the pattern explicit:

- `02 Projects/Project Index.md` is the map.
- `02 Projects/<slug>.md` is the deep project note.
- `_Project Template.md` is the copy/paste starting point for a new project.

## Agent Compatibility

Some old terms remain as frontmatter aliases or search phrases:

- `active-projects`
- `current-focus`
- `TASKS`
- `work-log`
- `os-instructions`

These are there for search compatibility, not as user-facing architecture. Agents can search familiar concepts while humans see clearer filenames.

## Design Rule

If a note is opened frequently by a human, it should live in a human-facing folder. If a note mostly exists to help the agent behave correctly, it belongs in `90 System/`.

When in doubt:

- Daily use goes in `01 Now/`.
- Project-specific context goes in `02 Projects/`.
- Reusable context goes in `04 Knowledge/`.
- Stable self/context/voice files go in `05 Profile/`.
