---
uid: 01HW9KR2P4TLBQMF6NCYD7VX8A
type: learning
date: "2026-05-12"
author: "@maya"
tags:
  - backend
  - rate-limiting
  - redis
  - api
---

# 2026-05-12 — Sliding window rate limiting with Redis sorted sets

## Context

Implemented rate limiting on the public API endpoints during sprint 4. Evaluated token bucket, fixed window, and sliding window approaches before settling on sliding window via Redis sorted sets.

## Learning

**Pattern**: sliding window rate limiting with a sorted set per user key.

```
Key:   ratelimit:{user_id}:{endpoint}
Value: sorted set of { score: timestamp_ms, member: request_uuid }
```

On each request:
1. Remove members with score < `now - window_ms` (expire old requests).
2. Count remaining members.
3. If count >= limit, reject with 429 and set `Retry-After`.
4. Otherwise, add a new member with score = `now`.
5. Set key TTL = `window_ms` to clean up idle keys automatically.

The sorted set approach gives true sliding window semantics without the "boundary burst" problem of fixed windows. Memory cost is O(requests_in_window) per user — acceptable at our scale.

## What to watch out for

- The ZREMRANGEBYSCORE + ZCARD + ZADD sequence must be wrapped in a Lua script or a MULTI/EXEC block to avoid race conditions on high-concurrency keys.
- Use `NX` flag on the TTL set so you are not resetting the TTL on every hit.

## Applies to

Any stateful rate limiting on an HTTP API with Redis available. Especially useful when burst tolerance needs to be accurate rather than approximate.
