#!/usr/bin/env bash
# Audit §2.5 — entitlement. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
set -uo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/compartarenta-relay}"
PUBLIC_HOST="${PUBLIC_HOST:-sync.incoherences.org}"

fail() {
  echo FAILED
  exit 1
}

cd "$DEPLOY_ROOT" || fail
set -a
# shellcheck disable=SC1091
. env/.env
set +a

[[ -n "${ENTITLEMENT_INTERNAL_TOKEN:-}" ]] || fail
[[ -n "${ENTITLEMENT_POSTGRES_USER:-}" && -n "${ENTITLEMENT_POSTGRES_DB:-}" ]] || fail

# Loopback listen on 8081
ss_out=$(ss -ltn 2>/dev/null | grep -E ':8081\b' || true)
echo "$ss_out" | grep -qE '127\.0\.0\.1:8081' || fail

# Public HTTPS:8081 must fail / be unreachable (expect HTTP 000)
pub_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
  "https://${PUBLIC_HOST}:8081/healthz" 2>/dev/null || echo "000")
[[ "$pub_code" == "000" || -z "$pub_code" ]] || fail

hz=$(curl -sS --connect-timeout 3 http://127.0.0.1:8081/healthz) || fail
echo "$hz" | grep -qE '"status"[[:space:]]*:[[:space:]]*"ok"' || fail

rz=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 3 \
  http://127.0.0.1:8081/readyz) || fail
[[ "$rz" == "200" ]] || fail

# Required ENTITLEMENT_* keys present
env_file="$DEPLOY_ROOT/env/.env"
for key in ENTITLEMENT_ENABLED ENTITLEMENT_INTROSPECT_URL ENTITLEMENT_INTERNAL_TOKEN; do
  grep -qE "^${key}=" "$env_file" || fail
done

# Introspect URL must be Docker-internal, not a public hostname
introspect_url=$(grep -E '^ENTITLEMENT_INTROSPECT_URL=' "$env_file" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
[[ "$introspect_url" == "http://entitlement:8080" ]] || fail

resp=$(curl -sS -X POST http://127.0.0.1:8081/v1/introspect/envelope \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${ENTITLEMENT_INTERNAL_TOKEN}" \
  -d '{"module":"housing","plan_id":"audit-missing-plan","participant_installation_id":"audit-missing-inst","envelope_kind":7,"operation":"housing_realized_expense_propose"}') || fail
echo "$resp" | grep -qE '"allow"[[:space:]]*:[[:space:]]*false' || fail

expected_tables="housing_expense_decisions housing_plan_active_revision housing_plan_licenses housing_plan_rosters housing_plans installations license_receipts schema_version"
actual_tables=$(docker exec compartarenta-entitlement-db \
  psql -U "$ENTITLEMENT_POSTGRES_USER" -d "$ENTITLEMENT_POSTGRES_DB" -At -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" \
  | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
[[ "$expected_tables" == "$actual_tables" ]] || fail

echo PASSED
exit 0
