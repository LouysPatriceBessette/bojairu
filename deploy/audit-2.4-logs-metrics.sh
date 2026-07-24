#!/usr/bin/env bash
# Audit §2.4 — logs and metrics. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
set -uo pipefail

PUBLIC_HOST="${PUBLIC_HOST:-sync.incoherences.org}"

fail() {
  echo FAILED
  exit 1
}

sample=$(docker logs --tail 1000 compartarenta-relay 2>&1) || fail
forbidden='"ciphertext"|"display_name"|"email"|"recipient_payload"|"sender_payload"|"avatar"'
hits=$(printf '%s' "$sample" | grep -E "$forbidden" || true)
[[ -z "$hits" ]] || fail

code=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}/metrics" || echo "000")
[[ "$code" -ge 400 && "$code" -lt 600 ]] || fail

metrics=$(curl -s http://127.0.0.1:9090/metrics) || fail
[[ -n "$metrics" ]] || fail
expected_metrics="relay_envelopes_accepted_total relay_envelopes_delivered_total relay_envelopes_expired_total relay_envelopes_queue_depth relay_envelopes_oldest_undelivered_age_seconds relay_sweeper_runs_total relay_http_requests_total"
for name in $expected_metrics; do
  printf '%s' "$metrics" \
    | grep -qE "^(# (HELP|TYPE) )?$name([[:space:]]|\{|$)" \
    || fail
done

echo PASSED
exit 0
