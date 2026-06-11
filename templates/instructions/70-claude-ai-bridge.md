# Claude.ai Bridge — pointer

Claude.ai marketplace connectors (Gmail, Slack, Calendar, Drive, Notion, ...) surface in Claude Code as **deferred** `mcp__claude_ai_*` tools — schemas load via `ToolSearch` (`select:<name>` or keyword query), then they invoke like any other tool. They are runtime tools, independent of the vault index. BEFORE declaring any connector or external service unavailable, invoke the `thinkos-bridge` skill.
