# Scheduled housing payment reminders (relay cron)

Schema migration `0003_scheduled_notifications.sql` adds the fifth relay data
category: **scheduled notification housekeeping** (`scheduled_notification_targets`,
`scheduled_notification_fires`, `recipient_notification_timezone`).

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `REMINDER_CRON_ENABLED` | `false` | When `true`, the relay runs the reminder cron alongside the sweeper. |
| `REMINDER_CRON_INTERVAL` | `5m` | Cadence for claiming due `scheduled_notification_fires` rows. |

Payment reminder reconciliation uses the existing scheduling HTTP API:

- `POST /v1/scheduling/timezone` — upsert recipient IANA timezone (recomputes pending housing fires).
- `POST /v1/scheduling/housing/reconcile` — upsert/cancel housing payment targets (domain `housing_payment`).
- `POST /v1/scheduling/housing/cancel` — partial cancel by scope/period.
- `POST /v1/scheduling/fires/upsert` — authenticated client wall-clock `fires[]` upsert for domains `contacts_invitation_expiry`, `housing_proposal_deadline`, and `vehicle_sharing_deadline` (past `fire_at` skipped server-side).
- `POST /v1/scheduling/fires/cancel` — cancel pending fires by domain + `scope_key`(s).
- `GET /v1/scheduling/pending-deliveries` — client fetch after wake push.
- `POST /v1/scheduling/ack-delivery` — mark a fired row consumed.

When a fire is due, the cron marks it `fired`, dispatches a wake push
(`kind=wake_for_inbox`), and exposes the row via `pending-deliveries`. The
mobile client builds the localized notification.

## Operator checklist

1. Deploy relay with migration `0003` applied (schema version 3).
2. Set `REMINDER_CRON_ENABLED=true` only after client reconciliation paths are deployed.
3. Verify `POST /v1/scheduling/timezone` returns 200 for an authenticated routing identity.
4. Confirm due fires move from `pending` to `fired` within one cron interval (see relay logs / metrics).
5. Cross-reference audit items in [`relay-audit-checklist.md`](./relay-audit-checklist.md) for scheduled-notification tables.

Client domains that supply wall-clock `fires[]` (same schema as housing payment):

| Domain | Who registers | Cancel when |
|--------|---------------|-------------|
| `contacts_invitation_expiry` | Inviter on invitation create | used / revoked / extend (re-register) |
| `housing_proposal_deadline` | Proposer on proposal dispatch | response / invalidate / expire |
| `vehicle_sharing_deadline` | Propriétaire on offer / reactivate dispatch | accept |