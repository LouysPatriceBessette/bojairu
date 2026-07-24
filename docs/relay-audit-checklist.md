# Compartarenta Relay — Audit Checklist

This checklist is the runnable counterpart to the OpenSpec capability
`relay-public-auditability`. An external reviewer can clone this
repository and reproduce each check below. Every item lists the
expected outcome; any divergence is an audit finding that goes into
[`relay-audit-log.md`](./relay-audit-log.md).

Replace `<example.tld>` with the deployed sub-domain you are auditing
and `$RELAY_HOST` with the public hostname (e.g., `relay.example.tld`).
Replace `$ADMIN_HOST` with the bastion / VPS hostname over SSH where
applicable.

Tools assumed available on the auditor's machine: `curl`, `dig`,
`openssl`, `jq`, `psql`, `docker`, and SSH. No proprietary tooling.

---

## A. DNS, TLS, and public surface

Define `$RELAY_HOST` with your VPS url.

```bash
RELAY_HOST=sub.domain.tld
```

### A.1 The relay sub-domain resolves to a single A/AAAA record

```bash
dig +short A $RELAY_HOST
dig +short AAAA $RELAY_HOST
```

**Expected:** at least one address record. Records do not point at a
shared load-balancer alias for unrelated services on the same VPS.

### A.2 TLS certificate covers only the relay sub-domain

```bash
echo | openssl s_client -connect $RELAY_HOST:443 -servername $RELAY_HOST 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -A1 "Subject Alternative Name"
```

**Expected:** SAN list contains only the relay sub-domain (and other
names that are exclusively part of the relay deployment). No wildcard
shared with unrelated services. Required by
`relay-deployment-topology` / "TLS material is not shared with
unrelated services".

### A.3 Plaintext HTTP is refused or redirected

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://$RELAY_HOST/v1/envelopes
```

**Expected:** `301`, `308`, or refused connection. Required by
`relay-deployment-topology` / "TLS is mandatory on the relay
sub-domain".

### A.4 Public surface enumeration

```bash
for path in / /healthz /readyz /metrics /admin /debug /debug/pprof /pprof; do
  echo -n "$path: "
  curl -s -o /dev/null -w "%{http_code}\n" https://$RELAY_HOST$path
done
```

**Expected:**

- `/` returns **200**. By design, the relay sub-domain serves a
  hand-authored static landing page describing the application and
  linking to the app stores. This is documented in
  [`relay-deployment.md`](./relay-deployment.md) as part of the
  relay's own public surface (not an unrelated co-tenant). The
  landing-page content is itself audited by item **A.4.b** below.
- `/healthz` and `/readyz` return **200** (proxied by Apache to the
  relay binary).
- `/metrics`, `/admin`, `/debug`, `/debug/pprof`, `/pprof` return
  **non-200** (Apache `Require all denied` returns 403; if Apache is
  bypassed the relay binary's public listener does not serve them
  either, so the answer is 404).

Required by `relay-deployment-topology` / "The relay is the only
public surface exposed by the deployment". The landing page is part
of the relay's own front door, not "an unrelated service hosted on
the same VPS".

### A.4.b Landing page is static and free of operational state

```bash
curl -s https://$RELAY_HOST/ \
  | head -c 200000 \
  | grep -iE 'envelope_id|sender_identity|recipient_identity|relay_envelopes_|queue_depth|ttl_expires_at|operator_action|"build"|"schema_version"|/v1/' \
  || echo "ok"
```

**Expected:** prints `ok`. The landing page contains only static
marketing content (description + store links) and does not embed:

- references to the relay's `/v1/...` endpoints,
- envelope, identity, or routing identifiers,
- internal counter / metric names,
- the build hash or schema version,
- telemetry beacons or analytics that contact the relay.

The corresponding constraints are documented in
[`relay-deployment.md`](./relay-deployment.md) under "Static landing
page". Any failure here is a finding per
`relay-public-auditability` / "Public claims about the relay are
verifiable from the repo".

### A.4.c Apache vhost matches the repository template

`$VHOST_FILE` is whatever filename the operator chose under
`/etc/apache2/sites-available/`. The literal `relay-vhost` in the
template is conventional, not required; see
[`relay-deployment.md`](./relay-deployment.md) /
"Sub-domain name is a placeholder".

```bash
diff -u \
  /srv/compartarenta-relay/source/relay/deploy/apache2/relay-vhost.conf.template \
  "$VHOST_FILE" \
  | head -200
```

**Expected:** the only differences from the template are:

- `ServerName` (your chosen sub-domain),
- `DocumentRoot` (path to the landing page),
- the `SSLCertificate*` paths rewritten by `certbot`,
- the `Redirect permanent` target on the `*:80` vhost (matching your
  chosen sub-domain).

Any other deviation is a finding per
`relay-public-auditability` /
"Configuration drift between deployed and documented is itself a
finding".

### A.5 The relay's database container has no host-facing port binding

The spec requirement is that **the relay's postgres container** has no
route from the public internet, not that "port 5432 on the host is
closed". On a shared / multi-tenant VPS, an unrelated co-tenant service
may legitimately listen on port 5432; scanning the host port from the
outside conflates those two questions. The deterministic check is on
the relay's own container, on the host:

```bash
docker inspect --format '{{ json .NetworkSettings.Ports }}' \
  compartarenta-relay-db
docker port compartarenta-relay-db || true
```

**Expected:** the first command prints either:

- `{}` / `null` (the image declares no exposed port for postgres), or
- `{"5432/tcp":null}` (the image exposes 5432/tcp internally for the
  `relay-net` Docker bridge, but **no host port is bound** — the `null`
  on the right-hand side is the load-bearing piece of information).

The second command prints nothing (no host-facing port mapping at all).
This corresponds to the explicit `# NO ports: mapping` comment in
[`relay/compose.yml`](../relay/compose.yml). Required by
`relay-deployment-topology` /
"The database container is not reachable from the public internet".

**Failing case (for reference).** If the relay's compose manifest had
been altered to publish the database port — which is the deviation
this item is designed to catch — the first command would instead print
something like:

```json
{"5432/tcp":[{"HostIp":"0.0.0.0","HostPort":"5432"}]}
```

and `docker port compartarenta-relay-db` would print:

```
5432/tcp -> 0.0.0.0:5432
```

That output is a finding: it means the database container is reachable
from outside the private Docker network, in violation of
`relay-deployment-topology` /
"The database container is not reachable from the public internet".

> If port 5432 on the host **is** open from the outside (e.g., another
> service on the same VPS publishes its own postgres), that observation
> belongs to the co-tenant's own audit, not to this checklist, *provided
> that* the two preceding commands confirm the relay's container is not
> the one listening there. Record this distinction in the Baseline
> Summary if relevant.

---

## B. Container image and configuration

The checks below inspect the running containers and the local clone of
the repository. They are inherently operator-side: an external reviewer
cannot run them without privileged access to the host (see the
"Operator self-audit vs external review" note in the preamble). Run
them on the VPS as the deploy user; from a fresh shell on the VPS:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay/source
```

The `cd` puts the shell inside the local git checkout, which B.2 needs.
The other items (B.1, B.3, B.4, B.5) are `docker` commands and do not
depend on the working directory, but staying in the source tree keeps
the session consistent for the rest of the section.

### B.1 Deployed image digest matches a tagged release

```bash
docker inspect --format '{{ .Id }}' compartarenta-relay:v0.1.0
```

(Use whatever tag is in the `Tag` column of the most recent
[`relay-audit-log.md`](./relay-audit-log.md) "Deployments" row in place
of `v0.1.0`.)

Compare with the digest declared in the same row.

**Expected:** the printed `sha256:…` matches the audit-log row.
Required by `relay-public-auditability` /
"Each deployed version maps to a tagged release".

> **Registry-published variant.** If the image is ever pushed to a
> container registry, an external auditor can verify the digest without
> host access by pulling the image and running:
> `docker inspect --format '{{ index .RepoDigests 0 }}' <registry>/compartarenta-relay:<tag>`.
> The current deployment builds locally and does not publish to a
> registry, so `.RepoDigests` is empty and `.Id` is the load-bearing
> identifier.

### B.2 No secret values committed to the repository

```bash
git grep -nE '(POSTGRES_PASSWORD|DATABASE_URL)=[^$]' \
  -- ':!**/relay-audit-checklist.md' ':!**/relay-deployment.md' \
  ':!**/.env.example' || echo "clean"
```

**Expected:** only prints the repository placeholder values which are in `env.stack.example`: **"change-me-from-secret-store"**. \
Required by `relay-security-baseline` /
"Secrets are managed by an explicit secret store".

> The `clean` fallback is reached when `git grep` exits non-zero. The
> "good" path is *no matches found* (exit 1). If `git grep` itself
> fails to run (e.g., `$REPO` unset, wrong cwd), it also exits non-zero
> and prints `clean` — which would be a false positive. Make sure the
> `cd` from the section setup is in effect before running this.

### B.3 Container runs as non-root

The image declares a non-root user (`Config.User`) and the runtime
must honour it (`docker top` UID column). The block below prints both
values and asserts the verdict in a single line. We deliberately do
not use `docker exec compartarenta-relay id` because the runtime image
is `FROM scratch` and has no `id` binary — that approach prints a
confusing OCI runtime error before the fallback fires.

```bash
user_cfg=$(docker inspect --format '{{ .Config.User }}' compartarenta-relay)
uid_runtime=$(docker top compartarenta-relay 2>/dev/null | awk 'NR==2 {print $1}')
echo "Config.User:  $user_cfg"
echo "Runtime UID:  $uid_runtime"
if [ "$user_cfg" = "65532:65532" ] && [ "$uid_runtime" = "65532" ]; then
  echo "B.3 PASS"
else
  echo "B.3 FAIL (expected Config.User=65532:65532 and Runtime UID=65532)"
fi
```

**Expected:** `B.3 PASS`. The UID/GID `65532:65532` is the value set
in [`relay/Dockerfile`](../relay/Dockerfile). Required by
`relay-security-baseline` /
"The relay process runs with least privilege".

### B.4 Root filesystem is read-only on the relay container

```bash
ro=$(docker inspect --format '{{ .HostConfig.ReadonlyRootfs }}' compartarenta-relay)
echo "ReadonlyRootfs: $ro"
[ "$ro" = "true" ] && echo "B.4 PASS" || echo "B.4 FAIL (expected true)"
```

**Expected:** `B.4 PASS`.

### B.5 No unrelated processes inside the containers

PostgreSQL's standard architecture spawns several worker subprocesses
(checkpointer, background writer, walwriter, autovacuum launcher,
logical replication launcher) plus one row per active client
connection. None of these are "unrelated" — they all share UID `70`
(the alpine `postgres` user) and a `CMD` starting with `postgres`.
The block below prints the raw `docker top` output for both
containers, then asserts:

- the relay container has exactly **one** process and its `CMD` is
  `/relay`,
- every process in the db container has UID `70` and a `CMD` starting
  with `postgres`.

```bash
echo "--- compartarenta-relay processes ---"
docker top compartarenta-relay
echo
echo "--- compartarenta-relay-db processes ---"
docker top compartarenta-relay-db
echo

relay_rows=$(docker top compartarenta-relay | awk 'NR>1')
relay_count=$(printf '%s\n' "$relay_rows" | grep -c .)
relay_bad=$(printf '%s\n' "$relay_rows" | awk '$1!="65532" || $8!="/relay" {print}')

db_bad=$(docker top compartarenta-relay-db \
  | awk 'NR>1 && ($1!="70" || $8!~/^postgres/) {print}')

if [ "$relay_count" -eq 1 ] && [ -z "$relay_bad" ] && [ -z "$db_bad" ]; then
  echo "B.5 PASS"
else
  [ "$relay_count" -ne 1 ] && \
    echo "B.5 FAIL (relay): expected 1 process, got $relay_count"
  [ -n "$relay_bad" ] && {
    echo "B.5 FAIL (relay): unexpected process row(s):"; echo "$relay_bad";
  }
  [ -n "$db_bad" ] && {
    echo "B.5 FAIL (db): row(s) with non-postgres CMD or non-70 UID:"
    echo "$db_bad"
  }
fi
```

**Expected:** `B.5 PASS`. Required by `relay-deployment-topology` /
"The deployment runs without unrelated workloads in relay containers".

---

## C. Schema and retention

These checks query the relay database through the postgres container.
They are operator-side (host access to the docker socket required).
Open a shell as the deploy user, position yourself at the deploy root
(where `env/.env` lives), source the deploy environment, and define a
`psql_q` helper that wraps `psql` inside the running postgres
container:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay

set -a; . env/.env; set +a

psql_q() {
  docker compose --env-file env/.env -f source/relay/compose.yml \
    exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
}
```

This setup block produces **no output**: `set -a` toggles a shell flag,
sourcing `env/.env` populates the shell environment silently, and the
`psql_q` declaration is just a function definition. The prompt should
simply come back ready for the next command. You can sanity-check the
helper before continuing with `psql_q -c 'SELECT 1;'` — it should print
a single-row `?column?` table and `(1 row)`.

The `-T` flag on `compose exec` disables TTY allocation, which keeps
the output clean enough to pipe into shell assertions.

### C.1 Live schema matches the migrations directory

First print the full schema for visual review:

```bash
psql_q \
  -c "\dt+" \
  -c "\d+ schema_version" \
  -c "\d+ routing_relationships" \
  -c "\d+ idempotency_entries" \
  -c "\d+ envelopes" \
  -c "\d+ sweeper_checkpoint" \
  -c "\d+ operator_actions" \
  -c "\d+ routing_push_tokens" \
  -c "\d+ relay_day_metrics"
```

Then assert that the live table set is exactly the one declared in the
canonical migrations ([`0001_init.sql`](../relay/internal/store/schema/0001_init.sql)
and [`0002_routing_push_tokens.sql`](../relay/internal/store/schema/0002_routing_push_tokens.sql)).
From schema version 2 onward, `routing_push_tokens` and `relay_day_metrics`
are expected in addition to the v0.1.0 tables:

```bash
expected="envelopes housing_reminder_plan_generation idempotency_entries operator_actions recipient_notification_timezone relay_day_metrics routing_push_tokens routing_relationships scheduled_notification_fires scheduled_notification_targets schema_version sweeper_checkpoint"
actual=$(psql_q -At -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" \
  | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
echo "Expected tables: $expected"
echo "Actual tables:   $actual"
[ "$expected" = "$actual" ] && echo "C.1 PASS" || echo "C.1 FAIL"
```

**Expected:** `C.1 PASS`. The detailed schema dump above is for manual
review (column types, CHECK constraints, indexes); the assertion only
catches gross structural drift (added/removed tables). The only
payload-carrying column is `envelopes.ciphertext` and it is BYTEA.
`routing_push_tokens` stores opaque device tokens and an optional
country code (`UNDISCLOSED` or ISO 3166-1 alpha-2), not message
content. `relay_day_metrics` holds numeric counters only.
Required by `relay-state-schema-and-retention` /
"The relay database schema is explicitly enumerated and minimal".

### C.2 No table holds plaintext user content

Print every TEXT / VARCHAR column in the public schema, then assert
the set matches the allow-list:

```bash
psql_q -c "
  SELECT table_name, column_name, data_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND data_type IN ('text', 'character varying')
  ORDER BY table_name, column_name;
"

expected_cols="operator_actions.action operator_actions.actor operator_actions.reason operator_actions.target_kind recipient_notification_timezone.iana_timezone routing_push_tokens.country routing_push_tokens.provider routing_push_tokens.push_token routing_relationships.status scheduled_notification_fires.status scheduled_notification_targets.domain scheduled_notification_targets.reminder_kind"
actual_cols=$(psql_q -At -c "
  SELECT table_name||'.'||column_name
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND data_type IN ('text', 'character varying')
  ORDER BY table_name, column_name;
" | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
echo "Expected: $expected_cols"
echo "Actual:   $actual_cols"
[ "$expected_cols" = "$actual_cols" ] && echo "C.2 PASS" || echo "C.2 FAIL"
```

**Expected:** `C.2 PASS`. The allow-listed TEXT/VARCHAR columns are:
operator housekeeping (`operator_actions.*`); routing relationship
status (`routing_relationships.status`, CHECK-constrained to
`'active' | 'disconnecting'`); and closed-app push registration metadata
on `routing_push_tokens` (`provider` is `'fcm' | 'apns'`;
`push_token` is an opaque third-party device token, not envelope
content; `country` is an optional ISO country code or `UNDISCLOSED`,
not a display name or message body). `relay_day_metrics` has no TEXT
columns. None of the allow-listed columns store user-facing message
plaintext. Required by `relay-state-schema-and-retention` /
"The relay database SHALL NOT store user payload plaintext".

### C.3 No envelope is older than `ENVELOPE_TTL_MAX`

```bash
n=$(psql_q -At -c \
  "SELECT count(*) FROM envelopes WHERE created_at < now() - interval '7 days';" \
  | tr -d '\r')
echo "Envelopes older than 7 days: $n"
[ "$n" = "0" ] && echo "C.3 PASS" || echo "C.3 FAIL"
```

Adjust the `'7 days'` interval to the operator's actual
`ENVELOPE_TTL_MAX` value if it diverges from the default (168h).
Required by `relay-state-schema-and-retention` /
"Undelivered envelopes are deleted at TTL expiry".

### C.4 Sweeper has run recently

```bash
last_run=$(psql_q -At -c \
  "SELECT last_run_at FROM sweeper_checkpoint WHERE id = 1;" \
  | tr -d '\r')
fresh=$(psql_q -At -c \
  "SELECT (now() - last_run_at) < interval '5 minutes' FROM sweeper_checkpoint WHERE id = 1;" \
  | tr -d '\r')
echo "Sweeper last_run_at: $last_run"
echo "Within 5 minutes:    $fresh"
[ "$fresh" = "t" ] && echo "C.4 PASS" || echo "C.4 FAIL (last_run_at older than 5 min)"
```

The 5-minute window is generous: the default `SWEEPER_INTERVAL` is one
minute, so the assertion tolerates ~4 minutes of jitter. Tighten the
window if `SWEEPER_INTERVAL` is shorter.

### C.5 No IP addresses persisted in the relay DB

The schema declares no `inet` / `cidr` typed columns and no columns
named like an IP address. Assert it:

```bash
ip_cols=$(psql_q -At -c "
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

if [ -z "$ip_cols" ]; then
  echo "C.5 PASS"
else
  echo "C.5 FAIL — columns matching IP-address patterns:"
  echo "$ip_cols"
fi
```

**Expected:** `C.5 PASS`. Required by
`relay-observability-without-plaintext` /
"Logs do not persist client IP addresses as relay state".

---

## D. Logs and metrics

D.1 and D.3 are operator-side (host access required). D.2 is publicly
verifiable — anyone can run it. From the VPS, all three work
without further setup; from the same `compartarenta-relay` shell used
for section C is fine. If that shell has been closed:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay
```

### D.1 Sample relay logs contain no ciphertext / payload fields

Scan the recent log buffer for forbidden JSON field names. The relay
emits structured JSON logs; the allow-listed fields are documented
inline below.

```bash
sample=$(docker logs --tail 1000 compartarenta-relay 2>&1)
line_count=$(printf '%s' "$sample" | wc -l)
echo "Sampled $line_count log lines"

forbidden='"ciphertext"|"display_name"|"email"|"recipient_payload"|"sender_payload"|"avatar"'
hits=$(printf '%s' "$sample" | grep -E "$forbidden" || true)

if [ -z "$hits" ]; then
  echo "D.1 PASS (no forbidden JSON keys in sample)"
else
  echo "D.1 FAIL — log lines containing forbidden keys:"
  echo "$hits" | head -5
fi
```

**Expected:** `D.1 PASS`. The relay's structured logger only emits
allow-listed fields (`endpoint`, `envelope_id`, `sender_identity`,
`recipient_identity`, `status`, `duration_ms`, `error`,
`rejection_reason`, `build`, etc.). The `forbidden` regex above is
what an auditor would search for. Required by
`relay-observability-without-plaintext` /
"Logs do not contain user-content plaintext".

> On a freshly deployed relay with no traffic yet, the `sample` may be
> short (or empty). The assertion is still meaningful: it confirms that
> nothing forbidden appears in *whatever* the relay has logged so far.

### D.2 Metrics endpoint is private-only

Curl the public metrics path; expect a 4xx/5xx response. This check
works from any host that can reach the relay's public sub-domain,
including the VPS itself (the request still goes through the public
DNS and the Apache vhost on `0.0.0.0:443`).

```bash
RELAY_HOST=sync.incoherences.org
code=$(curl -s -o /dev/null -w "%{http_code}" "https://$RELAY_HOST/metrics")
echo "GET https://$RELAY_HOST/metrics -> HTTP $code"
if [ "$code" -ge 400 ] && [ "$code" -lt 600 ]; then
  echo "D.2 PASS"
else
  echo "D.2 FAIL (expected 4xx/5xx, got $code)"
fi
```

Replace `RELAY_HOST` with your own deployed sub-domain. **Expected:**
`D.2 PASS`. Required by `relay-observability-without-plaintext` /
"The metrics endpoint is not publicly reachable".

### D.3 Metrics scraping works through the documented private channel

The metrics listener binds to `127.0.0.1:9090` on the host (per
[`relay/compose.yml`](../relay/compose.yml)), so on the VPS it can be
reached directly without a tunnel. From a remote workstation, prepend
`ssh -L 9090:127.0.0.1:9090 $ADMIN_HOST` to open the tunnel first.

```bash
echo "--- first 40 lines of /metrics ---"
curl -s http://127.0.0.1:9090/metrics | head -40
echo

metrics=$(curl -s http://127.0.0.1:9090/metrics)
expected="relay_envelopes_accepted_total \
          relay_envelopes_delivered_total \
          relay_envelopes_expired_total \
          relay_envelopes_queue_depth \
          relay_envelopes_oldest_undelivered_age_seconds \
          relay_sweeper_runs_total \
          relay_http_requests_total"

missing=""
for name in $expected; do
  printf '%s' "$metrics" \
    | grep -qE "^(# (HELP|TYPE) )?$name([[:space:]]|\{|\$)" \
    || missing="$missing $name"
done

if [ -z "$missing" ]; then
  echo "D.3 PASS"
else
  echo "D.3 FAIL — missing metrics:$missing"
fi
```

**Expected:** `D.3 PASS`. The regex tolerates plain rows
(`relay_xxx 42`), labeled rows (`relay_xxx{label="..."} 42`), and the
`# HELP` / `# TYPE` declaration lines.

---

## E. Operator action log

The `operator_actions` table is the audit trail for actions the operator
takes on the relay (severing routing relationships, manual sweeps,
applying migrations — and self-audits themselves). The checks below
require `psql_q` from the section C setup; if your shell has been
closed, redo the C setup block first.

### E.0 (optional) Record this audit run in `operator_actions`

The **authoritative** audit record is [`relay-audit-log.md`](./relay-audit-log.md)
(committed to the repository: deployment row + self-audit section). The
`operator_actions` table is a **secondary** in-database trail for
operator-initiated events (manual sever, out-of-cycle sweep, migration,
or choosing to mirror an audit run).

**Skip E.0** when E.1 would already pass (≥1 row), for example after the
v0.1.0 baseline audit or any prior insert. That is the normal case for a
**version upgrade audit** (e.g. v0.2.0): document the run only in
`relay-audit-log.md` and proceed to E.1/E.2.

**Run E.0** only when:

- this is the **first** audit on a deployment whose `operator_actions`
  table is still empty (greenfield); or
- you deliberately want a new DB row for this run (recommended for
  unusual operator interventions, optional for routine quarterly audits).

Example insert for a **first** baseline on an empty table:

```bash
psql_q -c "INSERT INTO operator_actions (actor, action, reason)
           VALUES ('operator-on-call',
                   'baseline_self_audit',
                   'Initial baseline audit per docs/relay-audit-checklist.md');"
```

Example for a **release upgrade** audit (optional; adjust tag and date):

```bash
psql_q -c "INSERT INTO operator_actions (actor, action, reason)
           VALUES ('operator-on-call',
                   'self_audit_v0.2.0',
                   'Post-deploy checklist after v0.2.0; see docs/relay-audit-log.md');"
```

For other operator work (out-of-cycle sweeper, manual disconnect, etc.),
use a distinct `action` and a concrete `reason`. Do **not** repeat the
baseline insert on every checklist run.

### E.1 Operator actions are recorded

```bash
n=$(psql_q -At -c "SELECT count(*) FROM operator_actions;" | tr -d '\r')
max_at=$(psql_q -At -c "SELECT coalesce(max(occurred_at)::text, '(none)') FROM operator_actions;" | tr -d '\r')
echo "Total operator_actions rows: $n"
echo "Most recent occurred_at:     $max_at"
[ "$n" -ge 1 ] && echo "E.1 PASS" || echo "E.1 FAIL (expected ≥1 row)"
```

**Expected:** `E.1 PASS`. Required by
`relay-observability-without-plaintext` /
"Operator action logs are separate from envelope logs".

### E.2 Each row has non-empty actor / action / reason

```bash
psql_q -c "SELECT id, actor, action, reason
           FROM operator_actions
           ORDER BY occurred_at DESC
           LIMIT 5;"

bad=$(psql_q -At -c "
  SELECT id FROM operator_actions
   WHERE coalesce(actor,  '') = ''
      OR coalesce(action, '') = ''
      OR coalesce(reason, '') = '';
" | tr -d '\r')

if [ -z "$bad" ]; then
  echo "E.2 PASS"
else
  echo "E.2 FAIL — row ids with empty mandatory field(s):"
  echo "$bad"
fi
```

**Expected:** `E.2 PASS`. The schema declares `actor`, `action`, and
`reason` as `NOT NULL TEXT`, but empty strings are not blocked at the
DB level — this assertion catches that.

---

## F. Documentation alignment

### F.1 Documentation and reference manifests are present

Run from inside the local clone of the repository. On the VPS:

```bash
cd /srv/compartarenta-relay/source
```

Then:

```bash
files="relay/README.md \
       relay/compose.yml \
       relay/Dockerfile \
       relay/.env.example \
       relay/deploy/apache2/relay-vhost.conf.template \
       docs/relay-deployment.md \
       docs/relay-audit-checklist.md \
       docs/relay-audit-log.md"

missing=""
for f in $files; do
  [ -f "$f" ] || missing="$missing $f"
done

if [ -z "$missing" ]; then
  echo "F.1 PASS"
else
  echo "F.1 FAIL — missing files:$missing"
fi
```

**Expected:** `F.1 PASS`. Every artefact an external reviewer needs to
reproduce the deployment locally is present in the repo. Required by
`relay-public-auditability` /
"The relay's source, configuration, and schema are public".

### F.2 The audit log has an entry within the last quarter

This item is verified **after** the baseline self-audit entry has been
committed to [`docs/relay-audit-log.md`](./relay-audit-log.md). The
assertion below greps the most recent `**Date:** YYYY-MM-DD` line and
compares it to today.

```bash
cd /srv/compartarenta-relay/source

last_date=$(grep -oE '\*\*Date:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2}' \
  docs/relay-audit-log.md | head -1 | awk '{print $2}')

if [ -z "$last_date" ]; then
  echo "F.2 PENDING — no dated self-audit entry yet."
  echo "Fill the Baseline block in docs/relay-audit-log.md, commit,"
  echo "git -C source pull --ff-only on the VPS, then re-run F.2."
else
  age=$(( ( $(date +%s) - $(date -d "$last_date" +%s) ) / 86400 ))
  echo "Most recent self-audit date: $last_date (age: $age days)"
  if [ "$age" -le 90 ]; then
    echo "F.2 PASS"
  else
    echo "F.2 FAIL — last self-audit older than 90 days"
  fi
fi
```

**Expected:** initially `F.2 PENDING` (the baseline entry has not been
committed yet), then `F.2 PASS` after the baseline commit lands on
`main` and is pulled to the VPS. Required by
`relay-public-auditability` /
"A periodic self-audit is performed and recorded".

---

## G. Closed-app push ops (FCM `bojairu` + daily stats)

Operator-facing checks for OpenSpec `closed-app-push-delivery` **11.2** /
**11.6** and Phase A FCM project cutover. Execution is on the VPS; this
section is the checklist the operator ticks. Details:
[`relay-deployment.md`](./relay-deployment.md) (FCM / WAKE section),
[`stack-deployment.md`](./stack-deployment.md) (daily statistics cron).

### G.1 FCM service account is the `bojairu` Firebase project (ops A2)

1. On the VPS, confirm the JSON mounted into the relay container has
   `"project_id": "bojairu"` (or the current product Firebase project id
   documented in `relay-deployment.md`).
2. Confirm stack `.env` sets `FCM_SERVICE_ACCOUNT_JSON_PATH` to that file
   **inside** the container.
3. Restart relay after placing/rotating the file.
4. With `WAKE_PUSH_DISPATCH_ENABLED=true`, smoke a wake-eligible send and
   confirm FCM accept in relay logs (no permanent token error storm).

**Expected:** dispatcher credentials match the same Firebase project as
the shipped Android/iOS apps. The agent cannot place the secret JSON —
operator only.

### G.2 Auditor posture confirmation (OpenSpec 11.2)

Before treating production wake dispatch as formally signed-off, confirm
with the auditor:

| Item | Posture |
|------|---------|
| Push-token TTL default | 14 days |
| Country suppression threshold | hardcoded **10** |
| Statistics HTTP endpoint | loopback-only |
| Stats file | append-only `STATS_FILE_PATH` (default `/srv/compartarenta-stats/daily.jsonl`) |
| DB access for stats | no humans querying the DB for routine stats |

Record sign-off date and actor in [`relay-audit-log.md`](./relay-audit-log.md).
Field QA may enable the flag earlier; **11.2** remains open until auditor
confirmation.

### G.3 Daily stats cron under the relay OS user (OpenSpec 11.6)

1. Install cron under the **operating-system user that owns the relay
   process** (not root-only), using the Docker wrapper on this stack:

   ```cron
   7 0 * * * /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh >> /srv/compartarenta-stats/cron.log 2>&1
   ```

2. After one full UTC day, verify the first line landed:

   ```bash
   ssh $ADMIN_HOST 'head -n 1 /srv/compartarenta-stats/daily.jsonl | jq .'
   ```

**Expected:** one JSON line per day appended at ~00:07 UTC; `cron.log`
shows no permission errors. Scripts live under `relay/scripts/`.

---

## How to record findings

Append one row per finding to the **Findings** section of
[`relay-audit-log.md`](./relay-audit-log.md). Include:

- Date and auditor (`actor`),
- Reference to the checklist item (e.g., `A.2`),
- Observed value vs expected value,
- Resolution state (`open` / `resolved` / `accepted`),
- Pointer to the underlying issue / commit when applicable.

A failing item does not become "resolved" until the underlying
deviation has been corrected or explicitly accepted with a documented
reason, per `relay-public-auditability` / "Audit findings are tracked
and resolved transparently".
