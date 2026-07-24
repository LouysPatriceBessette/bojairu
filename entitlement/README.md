# Bojairũ Entitlement Service

Canonical server-side housing licensing state: trial consumption, accepted plan rosters, per-participant license coverage (stub verifier in Phase A), and relay-facing allow/deny introspection.

Product semantics: OpenSpec changes `entitlement-server`, `licensing-trial-and-plan-entitlement`, `subscription-entitlement-minimal-server-state`.

## Status

Phase A: housing-only, stub license reporting, HTTP introspection for relay gating. Phase B adds Google Play receipt validation. Apple (Phase C) is deferred.

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
| POST | `/v1/housing/license-status` | Report stub license state |
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
