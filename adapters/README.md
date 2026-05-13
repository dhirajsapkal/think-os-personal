# Product Adapters

Think OS core is tool-agnostic: markdown files in `{{OS_HOME}}`, indexed and edited through Basic Memory MCP.

Adapters explain how to wire that core into specific agentic products.

For first-run setup, agents should follow [`../docs/agent-setup-playbook.md`](../docs/agent-setup-playbook.md) and use `scripts/thinkos-doctor.sh` / `scripts/thinkos-setup.sh` instead of manually probing the machine.

| Adapter | Use when | Setup |
|---|---|---|
| Claude Cowork | You use Claude's desktop Cowork environment and want Think OS available in every Cowork task. | [`claude-cowork/README.md`](claude-cowork/README.md) |
| Claude Code | You use Claude Code CLI and want user-scope MCP access plus slash commands. | [`claude-code/README.md`](claude-code/README.md) |
| Codex | You use OpenAI Codex and want global MCP access plus AGENTS instructions. | [`codex/README.md`](codex/README.md) |

Add more adapters by following the same pattern:

1. Register `basic-memory mcp --project think-os` globally or at the broadest safe scope the tool supports.
2. Add global instructions that tell the agent when to query Think OS and when to skip it.
3. Verify from a fresh session outside `{{OS_HOME}}`.
4. Document the product's permission model and fallback path.
