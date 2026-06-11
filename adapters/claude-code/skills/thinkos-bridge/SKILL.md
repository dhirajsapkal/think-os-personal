---
name: thinkos-bridge
description: How claude.ai marketplace connectors (Gmail, Slack, Google Calendar, Drive, Notion, Atlassian, ClickUp, Granola, HubSpot, QuickBooks, ...) surface as deferred mcp__claude_ai_* tools in Claude Code. Invoke BEFORE telling the user any connector or external service is unavailable, when a mcp__claude_ai_* tool call fails with InputValidationError, or when deciding whether the agent can reach Gmail/Slack/Calendar/etc. directly.
---

# Claude.ai Marketplace Bridge — Runtime Tools

> Read this before you tell the user "X is unavailable" — the bridge is the most common reason X actually *is* available even though it doesn't show in your initial tool list.

## What the bridge is

When the user is signed into claude.ai with marketplace connectors enabled there (Gmail, Calendar, Drive, Slack, Notion, Atlassian, ClickUp, Granola, HubSpot, QuickBooks, etc.), Claude Code automatically surfaces those connectors as **deferred MCP tools** in this session. They show in `claude mcp list` with a `claude.ai *` prefix:

```
claude.ai Gmail: https://gmailmcp.googleapis.com/mcp/v1 - ✓ Connected
claude.ai Slack: https://mcp.slack.com/mcp - ✓ Connected
claude.ai Google Calendar: https://calendarmcp.googleapis.com/mcp/v1 - ✓ Connected
```

The tools land in the `mcp__claude_ai_<Service>__<tool>` namespace, e.g. `mcp__claude_ai_Slack__slack_send_message`, `mcp__claude_ai_Gmail__search_threads`, `mcp__claude_ai_Google_Calendar__list_events`.

## Deferred-tool loading — the part that trips agents up

Bridge tools are **deferred**: their full schemas are NOT loaded into your prompt at session start. Only their names appear in a deferred-tool list inside system reminders. If you try to call one without loading its schema you will get `InputValidationError`. Two ways to load:

- **Known tool name** → `ToolSearch select:mcp__claude_ai_Slack__slack_send_message` (comma-separate for multiple).
- **Discover by topic** → `ToolSearch query="slack send message" max_results=10`. Use broad queries; specific ones like `"+slack send"` can return nothing even when the tool exists.

Once loaded, they invoke exactly like any other tool.

## Vault index ≠ runtime tools — do not conflate them

This is the most common bridge-related failure mode for agents inside Think OS:

- **Vault index (Basic Memory, `mcp__basic-memory__*`).** Indexes only what's on disk in the vault. Does NOT pull from Gmail/Slack/Calendar — that's the desktop agent / continuous-capture's job. `/thinkos-mcp-help` documents this.
- **Runtime tools (claude.ai bridge, `mcp__claude_ai_*`).** Directly read Slack, send Gmail, query Calendar, etc. **Independent of the vault.** Work whether or not anything has been captured into the vault yet.

"The vault doesn't have your Slack messages yet" and "the agent can't reach Slack" are two completely different statements. The first one is often true; the second one almost certainly isn't if `claude mcp list` shows a bridge entry.

## Before telling the user "X is unavailable"

1. Run `claude mcp list` and check for `claude.ai <Service>: ✓ Connected`.
2. If present, run `ToolSearch query="<service-name>" max_results=20`. If that returns nothing, try the canonical tool name directly: `ToolSearch select:mcp__claude_ai_<Service>__<expected_tool>`.
3. Only after both fail should you tell the user the connector isn't reachable from this session — and even then, frame it as a session-level loading problem (which is unusual), not as "Think OS doesn't include Slack."

## When the bridge genuinely isn't available

If `claude mcp list` shows zero `claude.ai *` entries at all, the user is either not signed into claude.ai in this Claude Code install or hasn't enabled marketplace connectors. Two paths to fix:

1. Open Claude Code in a session signed into claude.ai with the relevant connectors enabled.
2. Install the connector locally: `bash <thinkos-repo>/scripts/thinkos-install-bundle.sh --target claude-code --items <id>`. See `data/plugin-catalog.yaml` for the id list.
