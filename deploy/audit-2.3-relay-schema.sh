#!/usr/bin/env bash
# Audit §2.3 — relay schema and retention. Prints only PASSED or FAILED.
# Run on the VPS as compartarenta-relay after HOW-TO §2.0.
set -uo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/srv/compartarenta-relay}"
STACK_COMPOSE="${STACK_COMPOSE:-source/deploy/compose.production-stack.yml}"
SECRETS_COMPOSE="${SECRETS_COMPOSE:-docker-compose.secrets.yml}"

fail() {
  echo FAILED
  exit 1
}

cd "$DEPLOY_ROOT" || fail
set -a
# shellcheck disable=SC1091
. env/.env
set +a

psql_relay() {
  docker compose --env-file env/.env \
    -f "$STACK_COMPOSE" \
    -f "$SECRETS_COMPOSE" \
    exec -T postgres \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
}

psql_relay -c 'SELECT 1;' >/dev/null 2>&1 || fail

expected="envelopes housing_reminder_plan_generation idempotency_entries operator_actions recipient_notification_timezone relay_day_metrics routing_push_tokens routing_relationships scheduled_notification_fires scheduled_notification_targets schema_version sweeper_checkpoint"
actual=$(psql_relay -At -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" \
  | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
[[ "$expected" == "$actual" ]] || fail

expected_cols="operator_actions.action operator_actions.actor operator_actions.reason operator_actions.target_kind recipient_notification_timezone.iana_timezone routing_push_tokens.country routing_push_tokens.provider routing_push_tokens.push_token routing_relationships.status scheduled_notification_fires.status scheduled_notification_targets.domain scheduled_notification_targets.reminder_kind"
actual_cols=$(psql_relay -At -c "
  SELECT table_name||'.'||column_name
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND data_type IN ('text', 'character varying')
  ORDER BY table_name, column_name;
" | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
[[ "$expected_cols" == "$actual_cols" ]] || fail

n=$(psql_relay -At -c \
  "SELECT count(*) FROM envelopes WHERE created_at < now() - interval '7 days';" \
  | tr -d '\r')
[[ "$n" == "0" ]] || fail

fresh=$(psql_relay -At -c \
  "SELECT (now() - last_run_at) < interval '5 minutes' FROM sweeper_checkpoint WHERE id = 1;" \
  | tr -d '\r')
[[ "$fresh" == "t" ]] || fail

ip_cols=$(psql_relay -At -c "
  SELECT table_name||'.'||column_name||' ('||data_type||')'
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND (
      column_name ILIKE '%ip%addr%'
      OR column_name = 'client_ip'
      OR data_type IN ('inet', 'cidr')
    )
  ORDER BY table_name, column_name;
" | tr -d '\r')
[[ -z "$ip_cols" ]] || fail

oa_rows=$(psql_relay -At -c "SELECT count(*) FROM operator_actions;" | tr -d '\r')
[[ "$oa_rows" =~ ^[0-9]+$ ]] || fail
[[ "$oa_rows" -ge 1 ]] || fail

bad_rows=$(psql_relay -At -c "
  SELECT count(*) FROM operator_actions
  WHERE coalesce(trim(actor),'') = ''
     OR coalesce(trim(action),'') = ''
     OR coalesce(trim(reason),'') = '';
" | tr -d '\r')
[[ "$bad_rows" == "0" ]] || fail

echo PASSED
exit 0
