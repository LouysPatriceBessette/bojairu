#!/usr/bin/env bash
# Audit §2.6 — closed-app push and daily stats. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
set -uo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/compartarenta-relay}"
STACK_COMPOSE="${STACK_COMPOSE:-source/deploy/compose.production-stack.yml}"
SECRETS_COMPOSE="${SECRETS_COMPOSE:-docker-compose.secrets.yml}"
FCM_HOST_JSON="${FCM_HOST_JSON:-/srv/compartarenta-relay/secrets/bojairu-firebase-adminsdk-fbsvc-3f8e9288d7.json}"
STATS_JSONL="${STATS_JSONL:-/srv/compartarenta-stats/daily.jsonl}"

fail() {
  echo FAILED
  exit 1
}

cd "$DEPLOY_ROOT" || fail
[[ -f "$FCM_HOST_JSON" ]] || fail

# Host JSON is 0600/UID 65532; relay image is scratch — bind via Docker.
project_id=$(docker run --rm \
  -v "${FCM_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; print(json.load(open('/sa.json'))['project_id'])" 2>/dev/null) || fail
[[ "$project_id" == "bojairu" ]] || fail

env_file="$DEPLOY_ROOT/env/.env"
wake_line=$(grep -E '^WAKE_PUSH_DISPATCH_ENABLED=' "$env_file" | head -1 || true)
fcm_line=$(grep -E '^FCM_SERVICE_ACCOUNT_JSON_PATH=' "$env_file" | head -1 || true)
[[ -n "$wake_line" && -n "$fcm_line" ]] || fail

wake_val=$(echo "$wake_line" | cut -d= -f2- | cut -d'#' -f1 | tr -d ' ' | tr -d '"' | tr -d "'")
[[ "$wake_val" == "true" ]] || fail

fcm_path=$(echo "$fcm_line" | cut -d= -f2- | cut -d'#' -f1 | tr -d ' ' | tr -d '"' | tr -d "'")
[[ "$fcm_path" == "/run/secrets/fcm-service-account.json" ]] || fail

# Fail on FCM init / wake send failures in recent logs
fcm_logs=$(docker compose --env-file env/.env \
  -f "$STACK_COMPOSE" \
  -f "$SECRETS_COMPOSE" \
  logs --tail 80 relay 2>&1 | grep -iE 'fcm|push\.wake|push\.fcm' || true)
if echo "$fcm_logs" | grep -qiE 'push\.fcm_init_failed|push\.wake\.send_failed'; then
  fail
fi

# Cron: exactly via-docker; no host daily-stats-append.sh remnant
cron_all=$(crontab -l 2>/dev/null || true)
echo "$cron_all" | grep -qE 'daily-stats-append\.sh' && fail
active_stats=$(echo "$cron_all" | grep -vE '^[[:space:]]*#' | grep -F 'daily-stats-append-via-docker.sh' || true)
[[ -n "$active_stats" ]] || fail
# Prefer the documented path when present
echo "$active_stats" | grep -qF '/srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh' || fail

[[ -r "$STATS_JSONL" ]] || fail
# First line must be parseable JSON (content may be an older day — OK)
head -n 1 "$STATS_JSONL" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null || fail

echo PASSED
exit 0
