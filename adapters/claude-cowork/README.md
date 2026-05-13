# Claude Cowork Adapter

Use this adapter when Claude Cowork is your desktop agent. Cowork should use Basic Memory MCP as the read/write path to Think OS so you do not need to attach the vault folder to every task.

## Prereqs

- Basic Memory installed and indexed: see [`../../docs/setup-basic-memory.md`](../../docs/setup-basic-memory.md)
- Think OS vault at `{{OS_HOME}}`, recommended `~/ThinkOS/vault`
- Basic Memory project name: `think-os`

## 1. Register Basic Memory MCP

Cowork manages MCPs through its UI.

Open Cowork settings and add a custom MCP server:

| Field | Value |
|---|---|
| Name | `Basic Memory` |
| Command | `basic-memory` |
| Args | `mcp --project think-os` |
| Working directory | Leave default or use `$HOME` |

If Cowork cannot find `basic-memory`, use the full path:

```bash
which basic-memory
```

Then paste that path as the command.

Fully quit and reopen Cowork after saving. MCP servers usually load on app startup.

## 2. Add Global Instructions

Open Cowork's personalization / custom instructions area and paste the contents of [`instructions.md`](instructions.md), replacing `{{OS_HOME}}` with your vault path.

## 3. Verify

Start a fresh Cowork conversation in a project that is not the Think OS vault and ask:

```text
Use Basic Memory to answer: who am I and what am I working on?
```

Expected:

- Cowork can see Basic Memory tools.
- The answer references `05 Profile/Identity.md` and `01 Now/Current Focus.md`.
- The answer is specific, not generic.

## Troubleshooting

- `command not found`: use the full `which basic-memory` path in the MCP config.
- MCP exists but cannot read files: move the vault to `~/ThinkOS/vault`, or grant Cowork Documents Folder / Full Disk Access if you chose a protected folder.
- Search works but edits fail: verify `basic-memory project ls --name think-os` from the same app environment if possible.
