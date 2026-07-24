#!/usr/bin/env bash
# Audit §2.1 — public surface. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
set -uo pipefail

PUBLIC_HOST="${PUBLIC_HOST:-sync.incoherences.org}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/compartarenta-relay}"
VHOST_FILE="${VHOST_FILE:-/etc/apache2/sites-available/sync.incoherences.org.conf}"

fail() {
  echo FAILED
  exit 1
}

# DNS: at least one A or AAAA
a=$(dig +short A "$PUBLIC_HOST" | head -1)
aaaa=$(dig +short AAAA "$PUBLIC_HOST" | head -1)
[[ -n "$a" || -n "$aaaa" ]] || fail

# TLS SAN includes PUBLIC_HOST
san=$(echo | openssl s_client -connect "${PUBLIC_HOST}:443" -servername "$PUBLIC_HOST" 2>/dev/null \
  | openssl x509 -noout -text 2>/dev/null \
  | grep -A1 "Subject Alternative Name" || true)
echo "$san" | grep -qF "$PUBLIC_HOST" || fail

# Plain HTTP refused or redirect
http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${PUBLIC_HOST}/v1/envelopes" || echo "000")
case "$http_code" in
  301|308|000) ;;
  *) fail ;;
esac

# Path enumeration
code_root=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}/")
code_hz=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}/healthz")
code_rz=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}/readyz")
[[ "$code_root" == "200" && "$code_hz" == "200" && "$code_rz" == "200" ]] || fail

for path in /metrics /admin /debug /debug/pprof /pprof; do
  c=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}${path}")
  [[ "$c" -ge 400 ]] || fail
done

# Landing root: no ops leakage
if curl -s "https://${PUBLIC_HOST}/" \
  | head -c 200000 \
  | grep -qiE 'envelope_id|sender_identity|recipient_identity|relay_envelopes_|queue_depth|ttl_expires_at|operator_action|"build"|"schema_version"|/v1/'; then
  fail
fi

# Invite page: Bojairũ + bojairu://; no legacy names / schemes
invite=$(curl -sS "https://${PUBLIC_HOST}/contact/invite/" || true)
echo "$invite" | grep -q 'Bojairũ' || fail
echo "$invite" | grep -q 'bojairu://' || fail
if echo "$invite" | grep -qi 'Compartarenta'; then fail; fi
if echo "$invite" | grep -qi 'compartarenta://'; then fail; fi

# Vhost present and points at landing DocumentRoot
[[ -f "$VHOST_FILE" ]] || fail
grep -q 'DocumentRoot' "$VHOST_FILE" || fail
grep -q 'compartarenta-relay-landing' "$VHOST_FILE" || fail

# Postgres containers: no host port mapping
for ctn in compartarenta-relay-db compartarenta-entitlement-db; do
  ports=$(docker inspect --format '{{ json .NetworkSettings.Ports }}' "$ctn")
  if echo "$ports" | grep -q 'HostPort'; then
    fail
  fi
  mapped=$(docker port "$ctn" 2>/dev/null || true)
  [[ -z "$mapped" ]] || fail
done

echo PASSED
exit 0
