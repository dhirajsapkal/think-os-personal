# Codex Adapter

Use this adapter when OpenAI Codex is one of your primary tools. It wires Basic Memory into Codex globally and adds Think OS guidance through Codex's global `AGENTS.md`.

## Prereqs

- Basic Memory installed and indexed: see [`../../docs/setup-basic-memory.md`](../../docs/setup-basic-memory.md)
- Think OS vault at `{{OS_HOME}}`, recommended `~/ThinkOS/vault`
- Basic Memory project name: `think-os`
- Codex CLI / desktop app installed and authenticated

## 1. Register Basic Memory MCP Globally

```bash
codex mcp add basic-memory -- basic-memory mcp --project think-os
```

Verify:

```bash
codex mcp list
codex mcp get basic-memory
```

If Codex cannot find `basic-memory`, use the full path:

```bash
codex mcp remove basic-memory
codex mcp add basic-memory -- "$(which basic-memory)" mcp --project think-os
```

## 2. Add Global Codex Instructions

Create or edit:

```bash
mkdir -p ~/.codex
$EDITOR ~/.codex/AGENTS.md
```

Paste the contents of [`AGENTS.md`](AGENTS.md), replacing `{{OS_HOME}}` with your vault path.

If `~/.codex/AGENTS.md` already has content, put the Think OS section near the top.

## 3. Optional: Trust The Vault Path

If your Codex config uses project trust entries, add your vault path as trusted. In `~/.codex/config.toml`:

```toml
[projects."{{OS_HOME}}"]
trust_level = "trusted"
```

This is not a substitute for macOS filesystem permissions. It only tells Codex the path is trusted if the app can read it.

## 4. Verify

Start a fresh Codex session outside `{{OS_HOME}}` and ask:

```text
Use Basic Memory to answer: who am I and what am I working on?
```

Expected:

- Codex can see the `basic-memory` MCP server.
- The answer references `05 Profile/Identity.md` and `01 Now/Current Focus.md`.
- Codex does not need the vault manually attached as a project.

## Troubleshooting

- `basic-memory` not found: re-add the MCP with `$(which basic-memory)`.
- Search works but file-list/edit operations fail: keep the vault at `~/ThinkOS/vault`, or grant Codex access if you chose a protected folder.
- New sessions ignore Think OS: confirm `~/.codex/AGENTS.md` contains the Think OS instructions.
