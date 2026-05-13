---
description: Install a Think OS plugin/connector bundle into Claude Cowork
permalink: think-os/adapters/claude-cowork/commands/thinkos-bundle
---

You are helping the user install their Think OS tool stack in Cowork. Cowork's plugins and connectors are UI-managed — your job is to ask which items they want, surface install cards via the appropriate tools, then tell them which items still need OAuth authorization.

---

## Step 1 — Check for setup-script handoff

Before asking the user anything, check `~/.thinkos/claude-cowork-bundle.json` (use a bash tool or file read). If it exists, load it. Shape:

```json
{
  "preset": "pm",
  "items": ["slack", "gmail", "notion", "granola", "figma", "productivity", "product-management", "anthropic-skills"]
}
```

If the file exists and `items` is non-empty, skip Step 2 entirely and proceed to Step 3 using those ids. Tell the user: "I found your bundle config from the setup script (preset: `<preset>`). Installing those items now."

If the file is missing or empty, fall through to Step 2.

---

## Step 2 — Ask the user (interactive path only)

Use `AskUserQuestion` with the following two questions.

**Question 1 — preset picker** (`multiSelect: false`):

```
header: "Pick a starter bundle"
options:
  - pm      — Product management: Slack, Gmail, Notion, Granola, Figma + PM and Productivity skills
  - eng     — Engineering: Slack, Gmail, Atlassian Rovo + Engineering and Productivity skills
  - design  — Design: Slack, Gmail, Notion, Figma, Granola + Design and Productivity skills
  - ops     — Operations: Slack, Gmail, Notion, QuickBooks + Productivity skills
  - custom  — Choose individual items from the full catalog
  - skip    — I'll set this up later
```

If the user picks `skip`, say: "OK — run `/thinkos-bundle` any time to come back to this." Then stop.

**Question 2 — custom picker** (only if Q1 = `custom`):

Ask one `AskUserQuestion` per category (skip categories with zero Cowork-available items). `multiSelect: true`. Use display names as option labels; map back to catalog ids afterward.

Categories and their Cowork-available items:
- **Communication**: Slack (`slack`), Gmail (`gmail`)
- **Docs / Knowledge**: Notion (`notion`), Google Drive (`google-drive`), Airtable (`airtable`)
- **Trackers**: Atlassian Rovo — Jira + Confluence (`atlassian-rovo`), ClickUp (`clickup`)
- **Meetings**: Granola (`granola`), Zoom for Claude (`zoom-claude`)
- **Design**: Figma (`figma`), Canva (`canva`)
- **CRM / Analytics**: HubSpot (`hubspot`), ZoomInfo (`zoominfo`), PubMed (`pubmed`)
- **Finance**: Intuit QuickBooks (`quickbooks`)
- **Calendar**: Google Calendar (`google-calendar`)
- **Skill Bundles** (plugins, not connectors): Productivity Skills (`productivity`), Product Management Skills (`product-management`), Engineering Skills (`engineering`), Design Skills (`design`), Anthropic Core Skills (`anthropic-skills`)

Collect all checked ids across all category questions.

---

## Step 3 — Resolve to a final list of Cowork-installable ids

For named presets, resolve via the catalog lib (if you have bash access):

```bash
source scripts/lib/catalog.sh
catalog_resolve_preset pm | catalog_filter_by_target cowork
```

If you don't have shell access, read `data/plugin-catalog.yaml` directly: find the preset under `presets:`, then keep only the ids whose catalog entry has `cowork.available: true`.

Resolved Cowork-available ids per preset (for reference — use the script if you can, fall back to these):

| Preset | Resolved ids |
|--------|-------------|
| pm | slack, gmail, notion, granola, figma, productivity, product-management, anthropic-skills |
| eng | slack, gmail, atlassian-rovo, productivity, engineering, anthropic-skills |
| design | slack, gmail, notion, figma, granola, productivity, design, anthropic-skills |
| ops | slack, gmail, notion, quickbooks, productivity, anthropic-skills |

---

## Step 4 — Split by kind

For each id, check `cowork.kind`:
- `kind: connector` → use `mcp__mcp-registry__suggest_connectors`
- `kind: plugin`    → use `mcp__plugins__suggest_plugin_install`

Quick reference: all skill bundle items (`productivity`, `product-management`, `engineering`, `design`, `anthropic-skills`) are `plugin`; everything else is `connector`.

To look up programmatically: `catalog_get_field <id> cowork.kind`

---

## Step 5 — Surface install cards

First, load the tool schemas so you know the exact parameter shape:

```
ToolSearch: select:mcp__plugins__suggest_plugin_install,mcp__mcp-registry__suggest_connectors
```

Then:

- Call `mcp__mcp-registry__suggest_connectors` once with the full list of connector `registry_id` values.
- Call `mcp__plugins__suggest_plugin_install` for each plugin id (or batched if the schema supports an array — check after loading).

The user clicks each install card that surfaces. You do not need to poll or wait — installation is asynchronous from your view. Tell the user: "Click each install card above to add it to Cowork. Come back here when you've clicked them all."

---

## Step 6 — OAuth and next-steps checklist

After surfacing the cards, print:

```
Now do this in Cowork:
```

For each connector that has `oauth: true` in the catalog, print:
```
→ Cowork → Settings → Connectors → <Name> → Authorize
```

OAuth-required connectors in the catalog: Slack, Gmail, Notion, Google Drive, Airtable, Atlassian Rovo, ClickUp, Zoom for Claude, Figma, Canva, HubSpot, ZoomInfo, Intuit QuickBooks, Google Calendar.
(Granola and PubMed do not require OAuth.)

Then print:
```
→ Restart Cowork (quit + reopen — not just close the window) so new MCPs and plugins load.
```

---

## Step 7 — Failure modes

If `mcp__mcp-registry__suggest_connectors` or `mcp__plugins__suggest_plugin_install` are not available (e.g., older Cowork version without plugin tools):

Print a manual install checklist instead:

```
These tools aren't available in this version of Cowork. Install manually:

Connectors (Cowork → Settings → Connectors → Browse):
  <list connector names>

Plugins (Cowork → Settings → Plugins → Browse):
  <list plugin names>

After installing each, complete OAuth for any that require it (see Step 6 list).
Then restart Cowork.
```

Reference connector names match the `name` field in `data/plugin-catalog.yaml`.
