---
uid: 01HZ4PQ6S8WLRCMJ9XNDYE2VB1
type: spec
owner: "@maya"
status: under-review
last_reviewed: "2026-05-13"
---

# Notifications API Contract

Owner: @maya. Reviewers: @alex, @maya. Edited via PR; changes require approval from owner.

## Purpose

Defines the HTTP API contract for the notifications service. Downstream consumers (web client, mobile, third-party webhooks) treat this as the stable interface. Breaking changes require a version bump and a migration window.

## Base URL

`/api/v1/notifications`

## Endpoints

### `GET /api/v1/notifications`

Returns the authenticated user's notifications, newest first.

**Query params**

| Param | Type | Default | Notes |
|---|---|---|---|
| `limit` | integer | 20 | Max 100 |
| `cursor` | string | — | Opaque pagination token from previous response |
| `unread_only` | boolean | false | Filter to unread only |

**Response (200)**

```json
{
  "items": [
    {
      "id": "01HXY...",
      "type": "mention",
      "read": false,
      "created_at": "2026-05-13T14:30:00Z",
      "actor": { "handle": "alex", "display_name": "Alex Park" },
      "subject": { "kind": "work-entry", "uid": "01HXY...", "title": "2026-05-13 Standup" },
      "body": "Alex mentioned you in a work entry."
    }
  ],
  "next_cursor": "eyJp...",
  "total_unread": 3
}
```

**Error responses**: 401 (not authenticated), 429 (rate limited — back off 60s).

---

### `POST /api/v1/notifications/{id}/read`

Marks a single notification as read.

**Response**: 204 No Content on success. 404 if notification does not belong to the authenticated user.

---

### `POST /api/v1/notifications/read-all`

Marks all notifications as read.

**Response**: 204 No Content.

## Rate limits

Endpoints are subject to the standard API rate limit: 300 requests per minute per user. The `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers are present on every response.

## Open questions

- [ ] Webhook delivery for third-party consumers: out of scope for v1, tracked in #issue-88.
- [ ] Push notifications (APNs / FCM): separate service, not part of this contract.

## Changelog

| Date | Change | Author |
|---|---|---|
| 2026-05-13 | Initial draft | @maya |
