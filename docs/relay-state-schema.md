# Relay state schema (operator reference)

Canonical SQL migrations live under [`relay/internal/store/schema/`](../relay/internal/store/schema/). This document summarizes **durable** relay tables for audit review. Envelope ciphertext remains short-lived per `relay-sync-no-persistence`.

## Schema version

The relay refuses to start when the `schema_version` table does not match the binary's expected version (see [`relay/internal/store/schema/`](../relay/internal/store/schema/) and [`docs/relay-audit-checklist.md`](./relay-audit-checklist.md)).

## Envelope transport (existing)

| Table | Purpose | Retention |
| --- | --- | --- |
| `envelopes` | Encrypted ciphertext awaiting delivery | Until ack or `ttl_expires_at` (`expires_at` on POST, else 7 days) |
| `idempotency_entries` | Send deduplication | Configured idempotency TTL |
| `routing_relationships` | Admission graph for envelope routing | Active / disconnecting + inactivity TTL |

## Routing push tokens (`0002_routing_push_tokens.sql`)

Closed-app wake delivery stores **transport-only** device tokens:

| Column | Type | Notes |
| --- | --- | --- |
| `recipient_routing_id` | `BYTEA` | Opaque routing identity (PK part) |
| `provider` | `TEXT` | `fcm` or `apns` (PK part) |
| `push_token` | `TEXT` | Opaque provider token (PK part) |
| `expires_at` | `TIMESTAMPTZ` | Hard TTL; default 14 days from last refresh |
| `last_seen_at` | `TIMESTAMPTZ` | Updated on register/refresh; used only for aggregate daily stats |
| `country` | `TEXT` | Opt-in ISO code or `UNDISCLOSED` |

**Retention:** rows are purged when `expires_at <= now()` (sweeper + opportunistic reads). **No** envelope plaintext, amounts, or contact names are stored in this table.

**Configuration:** `ROUTING_PUSH_TOKEN_TTL_SECONDS` (default `1209600` = 14 days).

**Wake dispatch:** when `WAKE_PUSH_DISPATCH_ENABLED=true`, the relay sends a data-only payload `{ "v": 1, "kind": "wake_for_inbox", "recipient": "<routing-id>" }` after envelope persistence. Dispatch is best-effort and never blocks envelope delivery.

**Credentials:** FCM service account JSON (`FCM_SERVICE_ACCOUNT_JSON_PATH`); APNs auth key (`APNS_*` env vars). See [`docs/relay-deployment.md`](./relay-deployment.md).

## Daily operator metrics (`relay_day_metrics`)

Per-UTC-day counters: wake dispatch success/failure, routing push token purges. Consumed by the loopback stats endpoint and append-only JSONL file (see deployment runbook § Daily closed-app push statistics).

## Scheduled notifications (`0003_scheduled_notifications.sql`)

Housing payment reminders and related cron-fired wake schedules. Documented in the housing scheduled-payment-reminders change; timestamps only—no user-facing plaintext on the relay.
