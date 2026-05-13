# Product Adapters

Think OS core is tool-agnostic: markdown files in `{{OS_HOME}}`, indexed and edited through Basic Memory MCP.

This directory contains the Claude Code adapter, which wires Think OS into Claude Code CLI via user-scope MCP registration, global instructions in `~/.claude/CLAUDE.md`, and slash commands in `~/.claude/commands/`.

For first-run setup, agents should follow [`../docs/agent-setup-playbook.md`](../docs/agent-setup-playbook.md) and use `scripts/thinkos-doctor.sh` / `scripts/thinkos-setup.sh` directly rather than manually probing the machine.

See [`claude-code/README.md`](claude-code/README.md) for the Claude Code adapter documentation.

## Bundle installer

Think OS includes a plugin/connector bundle installer. After the basic setup, run:

```bash
scripts/thinkos-install-bundle.sh --target claude-code --preset pm --yes
```

Choose from `pm` / `eng` / `design` / `ops` presets or build a custom stack. See [`data/plugin-catalog.yaml`](../data/plugin-catalog.yaml) for the full catalog.
