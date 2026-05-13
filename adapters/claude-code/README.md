# Claude Code Adapter

Use this adapter when Claude Code CLI is one of your primary tools. It wires Basic Memory at user scope, adds global Think OS instructions, and optionally installs Claude Code slash commands.

## Prereqs

- Basic Memory installed and indexed: see [`../../docs/setup-basic-memory.md`](../../docs/setup-basic-memory.md)
- Think OS vault at `{{OS_HOME}}`, recommended `~/ThinkOS/vault`
- Basic Memory project name: `think-os`
- Claude Code CLI installed and authenticated

## 1. Register Basic Memory MCP At User Scope

```bash
claude mcp add basic-memory --scope user -- basic-memory mcp --project think-os
```

Verify:

```bash
claude mcp list
```

If Claude Code cannot find `basic-memory`, use the full path:

```bash
claude mcp remove basic-memory --scope user
claude mcp add basic-memory --scope user -- "$(which basic-memory)" mcp --project think-os
```

## 2. Add Global Claude Code Instructions

Create or edit:

```bash
mkdir -p ~/.claude
$EDITOR ~/.claude/CLAUDE.md
```

Paste the contents of [`instructions.md`](instructions.md), replacing `{{OS_HOME}}` with your vault path.

If you already have global Claude Code instructions, put the Think OS section near the top.

## 3. Install Slash Commands

Optional but useful:

```bash
mkdir -p ~/.claude/commands
cp adapters/claude-code/commands/*.md ~/.claude/commands/
```

From this adapter folder, the same command is:

```bash
mkdir -p ~/.claude/commands
cp commands/*.md ~/.claude/commands/
```

## 4. Verify

Open a fresh Claude Code session outside `{{OS_HOME}}`:

```bash
cd ~
claude
```

Ask:

```text
Use Basic Memory to answer: who am I and what am I working on?
```

Expected:

- Claude Code can call Basic Memory tools.
- The answer references `05 Profile/Identity.md` and `01 Now/Current Focus.md`.
- Slash commands appear when you type `/`, if installed.

## Troubleshooting

- `basic-memory` not found: re-add the MCP with `$(which basic-memory)`.
- Tools appear but the vault is empty: keep `{{OS_HOME}}` at `~/ThinkOS/vault`, or grant the terminal app filesystem access if you chose a protected folder.
- Slash commands do not appear: restart Claude Code after copying command files.
