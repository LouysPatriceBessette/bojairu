# Bojairũ Entitlement — Audit Checklist

Runnable counterpart to OpenSpec `entitlement-server` task **5.4**. Use this
alongside [`relay-audit-checklist.md`](./relay-audit-checklist.md) when auditing
the combined stack on the VPS. Replace `$ADMIN_HOST` with the bastion/VPS
hostname. Entitlement is **loopback-only** — do not expose it through Apache.

Tools: `curl`, `jq`, `docker`, SSH. No proprietary tooling.

Product context: [`entitlement/README.md`](../entitlement/README.md),
[`docs/stack-deployment.md`](./stack-deployment.md).

---

## E.1 Service is reachable only on loopback

```bash
ssh $ADMIN_HOST 'ss -ltn | grep -E ":8081\\b" || true'
curl -s -o /dev/null -w "%{http_code}\\n" --connect-timeout 3 \
  https://$RELAY_HOST:8081/healthz || echo "unreachable_from_public"
```

**Expected:** host bind is `127.0.0.1:8081` (or Docker published to loopback
only). Public HTTPS to port 8081 fails or is refused. Required by
`entitlement-server` / private introspection topology.

---

## E.2 Health and readiness

```bash
ssh $ADMIN_HOST 'curl -sS http://127.0.0.1:8081/healthz | jq .'
ssh $ADMIN_HOST 'curl -sS -o /dev/null -w "%{http_code}\\n" http://127.0.0.1:8081/readyz'
```

**Expected:** `/healthz` returns JSON with a healthy status; `/readyz` is
**200** when Postgres is up.

---

## E.3 Compose services and non-root

```bash
ssh $ADMIN_HOST 'cd /srv/compartarenta-relay && docker compose -f source/deploy/compose.production-stack.yml ps'
ssh $ADMIN_HOST 'docker inspect compartarenta-relay-entitlement-1 --format "{{.Config.User}}" 2>/dev/null || docker inspect $(docker ps -qf name=entitlement) --format "{{.Config.User}}"'
```

**Expected:** entitlement + entitlement-postgres containers are up; entitlement
process user is non-root (matches compose). Image digests match the tagged
release under audit (record digest in the audit log).

---

## E.4 No secrets in the repository / image

```bash
cd /path/to/repo
git grep -nE 'ENTITLEMENT_INTERNAL_TOKEN=|LICENSE_|sk_live' -- \
  entitlement/ deploy/env.stack.example entitlement/.env.example || true
```

**Expected:** examples use placeholders only. Live tokens exist only in
`/srv/compartarenta-relay/env/.env` (mode `0600`) on the VPS — not in git.

---

## E.5 Introspection deny path (relay-facing)

With a known plan that has **no** roster for a participant, or with
`ENTITLEMENT_ENABLED=true` and a forged gate:

```bash
ssh $ADMIN_HOST 'curl -sS -X POST http://127.0.0.1:8081/v1/introspect/envelope \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ENTITLEMENT_INTERNAL_TOKEN" \
  -d "{\"module\":\"housing\",\"plan_id\":\"audit-missing-plan\",\"participant_installation_id\":\"audit-missing-inst\",\"envelope_kind\":7,\"operation\":\"housing_realized_expense_propose\"}" | jq .'
```

**Expected:** allow=false (or explicit deny) for unknown plan/installation.
Relay gated POSTs for kinds 5–9 must fail closed when introspection denies
(see relay unit tests and operator metrics).

---

## E.6 Relay env alignment

On the VPS `.env` used by compose:

| Variable | Expected |
|----------|----------|
| `ENTITLEMENT_ENABLED` | `true` when gating is on for production QA |
| `ENTITLEMENT_INTROSPECT_URL` | private Docker URL (e.g. `http://entitlement:8080`) |
| `ENTITLEMENT_INTERNAL_TOKEN` | matches entitlement service secret |

```bash
ssh $ADMIN_HOST 'grep -E "^ENTITLEMENT_" /srv/compartarenta-relay/env/.env | sed "s/=.*/=***redacted***/"'
```

**Expected:** three keys present; introspect URL is **not** a public hostname.

---

## E.7 Schema / migrations

```bash
ssh $ADMIN_HOST 'docker exec $(docker ps -qf name=entitlement-postgres) \
  psql -U entitlement -d entitlement -c "\\dt"'
```

**Expected:** tables match `entitlement/internal/store/schema/` (installations,
housing plans / rosters, license status, expense decisions as shipped). No
plaintext user message content.

---

## E.8 Out of scope for this checklist (Phase B+)

Do **not** treat as audit failures for Phase A:

- Google Play `LicenseVerifier` (OpenSpec **5.2**)
- Apple Store validation / `docs/store-mapping.md` (**5.3**)
- Signed assertions verified locally by relay (**5.5**)

---

## How to record findings

Append findings to [`relay-audit-log.md`](./relay-audit-log.md) (or a dated
entitlement subsection) with checklist id (`E.1`…), observed vs expected, and
resolution state — same rules as the relay checklist.
