# Bojairũ Entitlement Service

Canonical server-side housing licensing state: trial consumption, accepted plan rosters, per-participant license coverage, Google Play purchase-token verification, and relay-facing allow/deny introspection.

Product semantics: OpenSpec changes `entitlement-server`, `licensing-trial-and-plan-entitlement`, `subscription-entitlement-minimal-server-state`.

## Status

Phase B: housing lifecycle plus Google Play `purchases.subscriptionsv2.get` when `PLAY_SERVICE_ACCOUNT_JSON_PATH` is set. Without that path, the Play verifier stays a stub and clients may still report license status (local/dev only). Apple (Phase C) is deferred.

Paid housing coverage requires Play `subscriptionState` = `SUBSCRIPTION_STATE_ACTIVE` and a documented catalog SKU (`docs/store-mapping.md`). Other Play states are stored as invalid, including `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` (Play billing-retry grace — not the product 7-day housing grace after trial) and `SUBSCRIPTION_STATE_CANCELED` (canceled but not expired). A valid bundle receipt grants every included module; the most favorable valid source wins.

The Play JSON must be a **new** service-account file, mounted separately from the relay FCM file. Do not reuse or overwrite `fcm-service-account.json`.

## Quick start (local)

```bash
cd entitlement
cp .env.example .env   # edit secrets
docker compose up --build
curl -s http://127.0.0.1:8081/healthz | jq .
```

Register an installation and roster, then introspect:

```bash
curl -s -X POST http://127.0.0.1:8081/v1/installations/register \
  -H 'Content-Type: application/json' \
  -d '{"participant_installation_id":"inst-alpha-device-001"}'

curl -s -X POST http://127.0.0.1:8081/v1/housing/plan-roster \
  -H 'Content-Type: application/json' \
  -d '{"plan_id":"plan-1","revision_id":"rev-1","participant_installation_ids":["inst-alpha-device-001","inst-beta-device-002"]}'

curl -s -X POST http://127.0.0.1:8081/v1/introspect/envelope \
  -H 'Content-Type: application/json' \
  -d '{"module":"housing","plan_id":"plan-1","participant_installation_id":"inst-alpha-device-001","envelope_kind":7,"operation":"housing_realized_expense_propose"}'
```

Upload a Play purchase token (requires `PLAY_SERVICE_ACCOUNT_JSON_PATH` in the running service):

```bash
curl -s -X POST http://127.0.0.1:8081/v1/licenses/play-token \
  -H 'Content-Type: application/json' \
  -d '{"participant_installation_id":"inst-alpha-device-001","product_id":"bojairu.housing","purchase_token":"PLAY_PURCHASE_TOKEN","platform":"google_play"}'
```

## Relay integration

When the relay runs with:

```env
ENTITLEMENT_ENABLED=true
ENTITLEMENT_INTROSPECT_URL=http://entitlement:8080
ENTITLEMENT_INTERNAL_TOKEN=<same as entitlement service>
```

gated housing envelope kinds (5–9) require `entitlement_gate` on `POST /v1/envelopes`. See `openspec/changes/entitlement-server/design.md`.

Connect both stacks on a shared Docker network, or run entitlement on `127.0.0.1:8081` and point the relay at that URL from the host.

## API summary

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/v1/installations/register` | Register installation identity |
| POST | `/v1/housing/plan-roster` | Set accepted roster for a revision |
| POST | `/v1/housing/license-status` | Report stub license state (rejected when Play verification is enabled) |
| POST | `/v1/licenses/play-token` | Upload a Play purchase token for `subscriptionsv2.get` |
| GET | `/v1/licenses?participant_installation_id=` | List stored Play receipts and server expiry times |
| POST | `/v1/housing/expense-decision` | Record accept/reject metadata |
| POST | `/v1/housing/active-use` | Explicit active-use event |
| POST | `/v1/introspect/envelope` | Relay allow/deny (internal token optional) |
| GET | `/v1/housing/plans/{plan_id}` | Plan lifecycle snapshot |
| GET | `/healthz`, `/readyz` | Liveness / readiness |

## Tests

```bash
cd entitlement && go test ./...
cd ../relay && go test ./...
```

Integration tests against PostgreSQL are optional (set `ENTITLEMENT_INTEGRATION_TEST_DSN` when added).
