#!/usr/bin/env bash
# Audit §2.2 — containers and images. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
# Requires: RELAY_DIGEST and ENTITLEMENT_DIGEST (image Ids from §1.6 notepad).
set -uo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/compartarenta-relay}"
STACK_COMPOSE="${STACK_COMPOSE:-source/deploy/compose.production-stack.yml}"
SECRETS_COMPOSE="${SECRETS_COMPOSE:-docker-compose.secrets.yml}"
RELEASE_TAG="${RELEASE_TAG:-}"
RELAY_DIGEST="${RELAY_DIGEST:-}"
ENTITLEMENT_DIGEST="${ENTITLEMENT_DIGEST:-}"

fail() {
  echo FAILED
  exit 1
}

[[ -n "$RELEASE_TAG" ]] || fail
[[ -n "$RELAY_DIGEST" && -n "$ENTITLEMENT_DIGEST" ]] || fail

cd "$DEPLOY_ROOT" || fail
set -a
# shellcheck disable=SC1091
. env/.env
set +a

ps_out=$(docker compose --env-file env/.env -f "$STACK_COMPOSE" -f "$SECRETS_COMPOSE" ps 2>/dev/null) || fail
for name in compartarenta-relay compartarenta-relay-db compartarenta-entitlement compartarenta-entitlement-db; do
  echo "$ps_out" | grep -qF "$name" || fail
done
echo "$ps_out" | grep -qE 'compartarenta-relay[[:space:]].*Up' || fail
echo "$ps_out" | grep -qE 'compartarenta-entitlement[[:space:]].*Up' || fail
echo "$ps_out" | grep -qE 'compartarenta-relay-db[[:space:]].*(Up|healthy)' || fail
echo "$ps_out" | grep -qE 'compartarenta-entitlement-db[[:space:]].*(Up|healthy)' || fail

# Loopback-only published ports on app containers
for ctn in compartarenta-relay compartarenta-entitlement; do
  ports=$(docker inspect --format '{{ json .NetworkSettings.Ports }}' "$ctn" 2>/dev/null) || fail
  if echo "$ports" | grep -qE '"HostIp":"0\.0\.0\.0"|"HostIp":"::"'; then
    fail
  fi
done

relay_id=$(docker inspect --format '{{.Id}}' "compartarenta-relay:${RELEASE_TAG}" 2>/dev/null) || fail
ent_id=$(docker inspect --format '{{.Id}}' "compartarenta-entitlement:${RELEASE_TAG}" 2>/dev/null) || fail
[[ "$relay_id" == "$RELAY_DIGEST" ]] || fail
[[ "$ent_id" == "$ENTITLEMENT_DIGEST" ]] || fail

# Running containers must use those images
relay_running=$(docker inspect --format '{{.Image}}' compartarenta-relay 2>/dev/null) || fail
ent_running=$(docker inspect --format '{{.Image}}' compartarenta-entitlement 2>/dev/null) || fail
[[ "$relay_running" == "$RELAY_DIGEST" ]] || fail
[[ "$ent_running" == "$ENTITLEMENT_DIGEST" ]] || fail

# No live secrets in git (placeholders OK)
cd "$DEPLOY_ROOT/source" || fail
grep_out=$(git grep -nE '(POSTGRES_PASSWORD|DATABASE_URL|ENTITLEMENT_INTERNAL_TOKEN|LICENSE_|sk_live)=' \
  -- ':!**/relay-audit-checklist.md' ':!**/relay-deployment.md' \
  ':!**/entitlement-audit-checklist.md' ':!**/.env.example' \
  ':!**/env.stack.example' 2>/dev/null || true)
if [[ -n "$grep_out" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Allow documentation placeholders only
    if echo "$line" | grep -qiE 'change-me|<[^>]+>|PLACEHOLDER|example\.|redacted|\*\*\*'; then
      continue
    fi
    fail
  done <<< "$grep_out"
fi

user_cfg=$(docker inspect --format '{{.Config.User}}' compartarenta-relay)
uid_runtime=$(docker top compartarenta-relay 2>/dev/null | awk 'NR==2 {print $1}')
[[ "$user_cfg" == "65532:65532" || "$user_cfg" == "65532" ]] || fail
[[ "$uid_runtime" == "65532" ]] || fail

ent_user=$(docker inspect --format '{{.Config.User}}' compartarenta-entitlement)
[[ "$ent_user" == "65532:65532" || "$ent_user" == "65532" ]] || fail

ro=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' compartarenta-relay)
[[ "$ro" == "true" ]] || fail

# Relay: exactly one /relay as UID 65532
relay_top=$(docker top compartarenta-relay 2>/dev/null) || fail
relay_cmd_lines=$(echo "$relay_top" | awk 'NR>1')
[[ -n "$relay_cmd_lines" ]] || fail
relay_count=$(echo "$relay_cmd_lines" | wc -l | tr -d ' ')
[[ "$relay_count" == "1" ]] || fail
echo "$relay_cmd_lines" | grep -qE '^65532[[:space:]].*/relay' || fail

# DB: all processes UID 70, CMD starts with postgres
db_top=$(docker top compartarenta-relay-db 2>/dev/null) || fail
db_lines=$(echo "$db_top" | awk 'NR>1')
[[ -n "$db_lines" ]] || fail
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "$line" | grep -qE '^70[[:space:]]' || fail
  echo "$line" | grep -qiE 'postgres' || fail
done <<< "$db_lines"

echo PASSED
exit 0
