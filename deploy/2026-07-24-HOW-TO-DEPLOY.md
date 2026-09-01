# HOW-TO: Deploy and audit the Bojairũ stack

**Living ops document.** This is the procedure for upgrading the production
relay + entitlement stack on the VPS and recording the audit afterward.

| | |
|--|--|
| VPS deploy root | `/srv/compartarenta-relay` |
| OS deploy user | `compartarenta-relay` (not in `sudoers`) |
| Public host | `sync.incoherences.org` |
| Audit record | [`docs/relay-audit-log.md`](../docs/relay-audit-log.md) |
| Host prep / Apache first install | [`docs/relay-deployment.md`](../docs/relay-deployment.md) |
| Topology / first-time entitlement | [`docs/stack-deployment.md`](../docs/stack-deployment.md) |

**Order is fixed:** §1 Deploy → §2 Audit. Audit uses values you wrote down
in §1. Do not re-pull or rebuild during audit.

---

## 1. Deploy steps

### 1.0 Variables (set once)

Run this block at the start of the deploy shell (as `compartarenta-relay`
after step 1.1):

```bash
DEPLOY_ROOT=/srv/compartarenta-relay
PUBLIC_HOST=sync.incoherences.org
LICENSE_HOST=license.incoherences.org
STACK_COMPOSE=source/deploy/compose.production-stack.yml
SECRETS_COMPOSE=docker-compose.secrets.yml
LANDING_SRC="$DEPLOY_ROOT/source/relay/deploy/landing/contact/invite"
LANDING_DST=/var/www/compartarenta-relay-landing/contact/invite
# One release version for both images (RELAY_TAG + ENTITLEMENT_TAG in env/.env).
RELEASE_TAG=v0.5.1
RELAY_SCHEMA_VERSION=4
ENTITLEMENT_SCHEMA_VERSION=3
```

Set `RELEASE_TAG` and the two schema-version variables to the release being
deployed. Section 1.4 reads the real host secret paths from the merged Compose
configuration before any container is rebuilt; do not guess or hardcode a
replacement filename.

### 1.1 Shell identity (once)

Every command in §1 except **1.7 Landing** runs as OS user
`compartarenta-relay`.

From an admin / root shell:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay
```

If the prompt already shows `compartarenta-relay@…`, skip the `sudo` line
and only `cd /srv/compartarenta-relay`.

Do **not** prefix later commands with `sudo -u compartarenta-relay`.

### 1.2 Pull source

```bash
cd "$DEPLOY_ROOT"
git -C source pull --ff-only
GIT_COMMIT=$(git -C source rev-parse HEAD)
echo "GIT_COMMIT=$GIT_COMMIT"
git -C source status --short
git -C source tag --points-at HEAD
```

**Expected for this release:** `GIT_COMMIT` is
`62926400f29428e7951326fe554e5da375e6e4f2`, status prints nothing, and the
tag list contains `v0.5.1`. Stop if any of those three checks differs.

Start (or update) a **local** notepad on your laptop — not on the VPS.
Section 1.6 prints the exact blocks to save after the images are built.

### 1.3 Edit `env/.env`

```bash
cd "$DEPLOY_ROOT"
nano env/.env
```

Set these to this release (version ≠ git SHA):

| Variable in `.env` | Value |
|--------------------|--------|
| `RELAY_TAG` | `$RELEASE_TAG` (`v0.5.1` for this release) |
| `ENTITLEMENT_TAG` | `$RELEASE_TAG` (same version number) |
| `BUILD_DIGEST` | `$GIT_COMMIT` (full SHA from §1.2) |

Leave `ENTITLEMENT_BUILD_DIGEST` unset so it follows `BUILD_DIGEST`.

Leave these **unchanged**:

| Variable | Value |
|----------|--------|
| `FCM_SERVICE_ACCOUNT_JSON_PATH` | `/run/secrets/fcm-service-account.json` |
| `PLAY_SERVICE_ACCOUNT_JSON_PATH` | `/run/secrets/play-android-developer.json` |
| `ENTITLEMENT_INTROSPECT_URL` | `http://entitlement:8080` |
| `WAKE_PUSH_DISPATCH_ENABLED` | `true` (production wake) |

The Firebase path is consumed by **both** relay and Entitlement. The Play
path is consumed only by Entitlement. They are different credentials and
must remain separate files.

### 1.4 Confirm the planned relay and Entitlement secret mounts

```bash
cd "$DEPLOY_ROOT"
stack_config=$(docker compose --env-file env/.env \
  -f "$STACK_COMPOSE" \
  -f "$SECRETS_COMPOSE" \
  config --format json)

FCM_HOST_JSON=$(printf '%s\n' "$stack_config" | jq -r \
  'first(.services.relay.volumes[]? |
    select(.target == "/run/secrets/fcm-service-account.json") |
    .source) // empty')
ENTITLEMENT_FCM_HOST_JSON=$(printf '%s\n' "$stack_config" | jq -r \
  'first(.services.entitlement.volumes[]? |
    select(.target == "/run/secrets/fcm-service-account.json") |
    .source) // empty')
PLAY_HOST_JSON=$(printf '%s\n' "$stack_config" | jq -r \
  'first(.services.entitlement.volumes[]? |
    select(.target == "/run/secrets/play-android-developer.json") |
    .source) // empty')

if [[ -n "$FCM_HOST_JSON" &&
      "$FCM_HOST_JSON" == "$ENTITLEMENT_FCM_HOST_JSON" ]]; then
  echo "FCM Host: ok"
else
  echo "FCM Host: FAILED — the same Firebase file must be mounted in relay and Entitlement"
fi

if [[ -n "$PLAY_HOST_JSON" &&
      "$PLAY_HOST_JSON" != "$FCM_HOST_JSON" ]]; then
  echo "Play Host: ok"
else
  echo "Play Host: FAILED — Entitlement needs a separate Google Play file"
fi
```

**Expected:**

```text
FCM Host: ok
Play Host: ok
```

Do not continue while either line says `FAILED`.

If the Entitlement Firebase destination is absent, add the same host Firebase
file to its `volumes` block in `docker-compose.secrets.yml` as described in
[Procedure A](#procedure-a--replace-fcm-service-account-file). Preserve the
existing, separate Play mount, then re-run this section immediately. This
check reads the planned Compose configuration, so it must pass **before**
recording the deployment time or rebuilding the containers.

### 1.5 Record deploy timestamp

```bash
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%MZ")
echo "DEPLOYED_AT=$DEPLOYED_AT"
```

**Write down** `DEPLOYED_AT` for the audit log.

### 1.6 Build and recreate the stack

```bash
cd "$DEPLOY_ROOT"

docker compose --env-file env/.env \
  -f "$STACK_COMPOSE" \
  -f "$SECRETS_COMPOSE" \
  build && \
docker compose --env-file env/.env \
  -f "$STACK_COMPOSE" \
  -f "$SECRETS_COMPOSE" \
  up -d
```

Capture digests (and deploy time) for the audit log:

```bash
RELAY_DIGEST=$(docker inspect --format '{{.Id}}' "compartarenta-relay:${RELEASE_TAG}")
ENTITLEMENT_DIGEST=$(docker inspect --format '{{.Id}}' "compartarenta-entitlement:${RELEASE_TAG}")
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%MZ")
echo "RELAY_DIGEST=$RELAY_DIGEST"
echo "ENTITLEMENT_DIGEST=$ENTITLEMENT_DIGEST"
echo "DEPLOYED_AT=$DEPLOYED_AT"

printf 'export RELEASE_TAG=%q\nexport RELAY_DIGEST=%q\nexport ENTITLEMENT_DIGEST=%q\n' \
  "$RELEASE_TAG" "$RELAY_DIGEST" "$ENTITLEMENT_DIGEST"
printf 'Git commit: %s\nVersion: %s\nBuild datetime: %s\nDocker SHA: %s\nEntitlement SHA: %s\n' \
  "$GIT_COMMIT" "${RELEASE_TAG#v}" "$DEPLOYED_AT" \
  "$RELAY_DIGEST" "$ENTITLEMENT_DIGEST"
```

**Save both printed blocks on your laptop.** The first block is ready to paste
into §2.0 if the SSH session drops. The second block is ready for the public
audit log; `Docker SHA` is the relay image id and `Entitlement SHA` is the
Entitlement image id.

### 1.7 Landing page (Apache DocumentRoot)

Docker does **not** update the public invite HTML. Use an **admin/root**
shell for this block only, then return to `compartarenta-relay` for smoke.

```bash
sudo mkdir -p /var/www/compartarenta-relay-landing/contact/invite
sudo cp -r /srv/compartarenta-relay/source/relay/deploy/landing/contact/invite/* \
  /var/www/compartarenta-relay-landing/contact/invite/
```

### 1.8 Post-deploy smoke

Back as `compartarenta-relay` in `$DEPLOY_ROOT` (reuse §1.0 vars).

```bash
relay_hz=$(curl -sS "https://${PUBLIC_HOST}/healthz")
printf '%s\n' "$relay_hz" | jq .
test "$(printf '%s\n' "$relay_hz" | jq -r '.build')" = "$GIT_COMMIT"
test "$(printf '%s\n' "$relay_hz" | jq -r '.schema_version')" = "$RELAY_SCHEMA_VERSION"
curl -sS -H 'Accept: text/html' "https://${PUBLIC_HOST}/healthz" | head
curl -sS -o /dev/null -w '%{http_code}\n' "https://${PUBLIC_HOST}/readyz"

entitlement_hz=$(curl -sS http://127.0.0.1:8081/healthz)
printf '%s\n' "$entitlement_hz" | jq .
test "$(printf '%s\n' "$entitlement_hz" | jq -r '.build')" = "$GIT_COMMIT"
test "$(printf '%s\n' "$entitlement_hz" | jq -r '.schema_version')" = "$ENTITLEMENT_SCHEMA_VERSION"
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8081/readyz

test "$(curl -sS -o /dev/null -w '%{http_code}' "http://${LICENSE_HOST}/healthz")" = "301"
public_entitlement_hz=$(curl -sS "https://${LICENSE_HOST}/healthz")
test "$(printf '%s\n' "$public_entitlement_hz" | jq -r '.build')" = "$GIT_COMMIT"
test "$(printf '%s\n' "$public_entitlement_hz" | jq -r '.schema_version')" = "$ENTITLEMENT_SCHEMA_VERSION"
test "$(curl -sS -o /dev/null -w '%{http_code}' "https://${LICENSE_HOST}/readyz")" = "200"
test "$(curl -sS -o /dev/null -w '%{http_code}' "https://${LICENSE_HOST}/v1/introspect/envelope")" = "403"
test "$(curl -sS -o /dev/null -w '%{http_code}' "https://${LICENSE_HOST}/v1/free-licenses")" = "401"

docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
docker inspect compartarenta-entitlement \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
docker run --rm \
  -v "${FCM_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; d=json.load(open('/sa.json')); print(d['type'], d['project_id'])"
docker run --rm \
  -v "${PLAY_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; d=json.load(open('/sa.json')); print(d['type'], d['project_id'])"

curl -sS "https://${PUBLIC_HOST}/contact/invite/" | grep -iE 'Bojairũ|bojairu://' | head

set -a
. env/.env
set +a
"$DEPLOY_ROOT/source/deploy/free-licence/free-license-get.sh"
```

**Expected:**

- both health responses expose build
  `62926400f29428e7951326fe554e5da375e6e4f2`
- relay schema is `4`; Entitlement schema is `3`; both readyz calls return `200`
- `license.incoherences.org` redirects HTTP to HTTPS and serves the same
  Entitlement build; public introspection is `403`; unauthenticated free-license
  administration is `401`
- relay has the Firebase mount; Entitlement has the Firebase and Play mounts
- both credential checks print `service_account`; Firebase also prints project
  `bojairu`
- the authenticated free-license GET prints CSV beginning with
  `Nom,InstallationId` and does not change any licence
- invite page shows **Bojairũ** and `bojairu://`

From the **developer workstation** (phone USB + Monica-QA AVD):

```bash
cd /home/bvii/repos/Compartarenta
./tool/melosw run qa:run-fcm-wake-push
```

**Expected:** automation passes; physical device shows the housing-proposal
notification after Monica submits (app process killed, not force-stopped).

---

## Procedure A — Replace FCM service-account file

### What file this is

| File | Role | Where it goes |
|------|------|----------------|
| Firebase **service account** JSON (`"type": "service_account"`, `project_id`: **`bojairu`**) | Relay sends wake messages; Entitlement sends free-license grant/revoke messages | Same VPS host file, mounted read-only into both containers |
| Google Play service-account JSON | Entitlement validates Play purchases | Separate VPS host file, mounted read-only into Entitlement only |
| `google-services.json` (Android client flavors) | Mobile app Firebase SDK | App repo / build only — **never** mount on the relay |

`FCM_SERVICE_ACCOUNT_JSON_PATH` in `env/.env` is the path **inside the container**
(`/run/secrets/fcm-service-account.json`). It does **not** tell you where the
file sits on the host. The host file lives under
`/srv/compartarenta-relay/secrets/`.

| Role | Path |
|------|------|
| Source file on the VPS host | The real `.Source` printed by `docker inspect` |
| Path inside Docker (`.env`) | `/run/secrets/fcm-service-account.json` |

See the current bind without guessing:

```bash
FCM_HOST_JSON=$(docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/fcm-service-account.json"}}{{.Source}}{{end}}{{end}}')
test -n "$FCM_HOST_JSON"
printf 'Firebase host file: %s\n' "$FCM_HOST_JSON"
printf 'Entitlement overlay line:      - %s:/run/secrets/fcm-service-account.json:ro\n' \
  "$FCM_HOST_JSON"
```

The printed overlay line must exist under `services.entitlement.volumes` in
`docker-compose.secrets.yml`. The same source file remains mounted under
`services.relay.volumes`. Do not remove or replace Entitlement's separate
`/run/secrets/play-android-developer.json` mount.

### Obtain the JSON

1. Firebase Console → project **`bojairu`**.
2. Project settings → **Service accounts** → **Generate new private key**.
3. Confirm the downloaded JSON has `"type": "service_account"` and
   `"project_id": "bojairu"`.

### Install on the VPS

Place the new file under its **real name**. Do **not** rename it to overwrite
the old filename. Do **not** change `FCM_SERVICE_ACCOUNT_JSON_PATH` in `.env`.

From the workstation (adjust local filename):

```bash
LOCAL_FCM_JSON=/path/to/bojairu-firebase-adminsdk-….json
scp "$LOCAL_FCM_JSON" \
  compartarenta-relay@YOUR_VPS:/srv/compartarenta-relay/secrets/
```

On the VPS (deploy user shell):

```bash
cd /srv/compartarenta-relay

NEW_FCM_HOST_JSON=/srv/compartarenta-relay/secrets/bojairu-firebase-adminsdk-YOUR_NEW_SUFFIX.json

# Edit docker-compose.secrets.yml — change the host (left) side for BOTH
# services.relay and services.entitlement:
#   - /srv/compartarenta-relay/secrets/<new-filename>.json:/run/secrets/fcm-service-account.json:ro
# Leave Entitlement's play-android-developer.json line unchanged.
nano docker-compose.secrets.yml
```

Permissions (root/admin shell; then return to `compartarenta-relay`):

```bash
sudo chown 65532:65532 "$NEW_FCM_HOST_JSON"
sudo chmod 600 "$NEW_FCM_HOST_JSON"
```

In the deploy shell:

```bash
FCM_HOST_JSON=$NEW_FCM_HOST_JSON
```

Return to §1.4 (confirm planned mounts), then continue in order with §1.5 and
§1.6 so the new bind takes effect. Archive the previous host JSON after §1.8
smoke shows `project_id` = `bojairu`.

---

## Procedure B — Verify and use free-license operator commands

Run this only after §1.8 passes. These commands run on the VPS as
`compartarenta-relay`; they call Entitlement over loopback and never expose
the operator token publicly.

Load the token and list current active grants without changing anything:

```bash
cd /srv/compartarenta-relay
set -a
. env/.env
set +a
source/deploy/free-licence/free-license-get.sh
```

Expected first CSV line:

```text
Nom,InstallationId
```

To grant a licence, first obtain the complete installation ID from the user.
The installation must already have registered with Entitlement and have a
current Firebase token. The script intentionally fails if a free grant already
exists, a qualifying paid subscription blocks it, or the silent Firebase
message cannot be sent.

```bash
read -r -p "Free-license user name: " FREE_LICENSE_NAME
read -r -p "Installation ID: " INSTALLATION_ID
source/deploy/free-licence/free-license-set.sh \
  "$FREE_LICENSE_NAME" "$INSTALLATION_ID"
```

To revoke one existing grant:

```bash
read -r -p "Installation ID to revoke: " INSTALLATION_ID
source/deploy/free-licence/free-license-delete.sh "$INSTALLATION_ID"
```

Do not use SET or DELETE as a generic deployment smoke: both change a real
licence. The authenticated GET in §1.8 and audit §2.5 is the non-mutating
deployment check.

---

## 2. Audit

Run **after** §1. Keep your laptop notepad open with both exact blocks printed
in §1.6. The export block restores the image ids after an SSH reconnect; the
five-line audit block is copied into the public audit record.

Open findings go into [`docs/relay-audit-log.md`](../docs/relay-audit-log.md)
(Findings section). Passing checks are summarized in the Self-audit entry
(§2.7).

### 2.0 Audit shell and helpers

```bash
DEPLOY_ROOT=/srv/compartarenta-relay
PUBLIC_HOST=sync.incoherences.org
LICENSE_HOST=license.incoherences.org
STACK_COMPOSE=source/deploy/compose.production-stack.yml
SECRETS_COMPOSE=docker-compose.secrets.yml
RELEASE_TAG=v0.5.1
RELAY_SCHEMA_VERSION=4
ENTITLEMENT_SCHEMA_VERSION=3
VHOST_FILE=/etc/apache2/sites-available/sync.incoherences.org.conf

cd "$DEPLOY_ROOT"
# Paste the three exact `export` lines printed and saved in §1.6 here.
: "${RELAY_DIGEST:?paste the relay image id saved in section 1.6}"
: "${ENTITLEMENT_DIGEST:?paste the Entitlement image id saved in section 1.6}"
GIT_COMMIT=$(git -C source rev-parse HEAD)
FCM_HOST_JSON=$(docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/fcm-service-account.json"}}{{.Source}}{{end}}{{end}}')
PLAY_HOST_JSON=$(docker inspect compartarenta-entitlement \
  --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/play-android-developer.json"}}{{.Source}}{{end}}{{end}}')
export RELAY_DIGEST ENTITLEMENT_DIGEST RELEASE_TAG DEPLOY_ROOT PUBLIC_HOST \
  LICENSE_HOST STACK_COMPOSE SECRETS_COMPOSE FCM_HOST_JSON PLAY_HOST_JSON \
  RELAY_SCHEMA_VERSION ENTITLEMENT_SCHEMA_VERSION VHOST_FILE GIT_COMMIT

set -a
. env/.env
set +a

psql_relay() {
  docker compose --env-file env/.env \
    -f "$STACK_COMPOSE" \
    -f "$SECRETS_COMPOSE" \
    exec -T postgres \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
}
```

Same identity rule as §1: you are already `compartarenta-relay`.

Sanity check:

```bash
psql_relay -c 'SELECT 1;'
```

**Expected:**

```
 ?column? 
----------
        1
(1 row)
```

If that fails, stop — `env/.env` was not sourced or the relay Postgres
container is down.

---

### 2.1 Public surface

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.1-public-surface.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.1
and run each command one by one.

Defaults inside the script match §2.0 (`PUBLIC_HOST`, `DEPLOY_ROOT`,
`VHOST_FILE`). Override by exporting those vars before running.

---

### 2.2 Containers and images

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.2-containers-images.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.2
and run each command one by one.

Requires `RELAY_DIGEST` and `ENTITLEMENT_DIGEST` from §2.0 (laptop notepad
image Ids). `RELEASE_TAG` has no script fallback: the audit stops rather than
silently inspecting an older release.

---

### 2.3 Relay schema and retention

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.3-relay-schema.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.3
and run each command one by one.

---

### 2.4 Logs and metrics

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.4-logs-metrics.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.4
and run each command one by one.

---

### 2.5 Entitlement

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.5-entitlement.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.5
and run each command one by one.

This check now requires Entitlement schema 3, the public
`license.incoherences.org` route, both Entitlement secret mounts, the Play and
Firebase paths, and authenticated read-only access to the free-license CSV.
Apple validation and signed assertions remain out of scope.

---

### 2.6 Closed-app push and daily stats

```bash
"$DEPLOY_ROOT/source/deploy/audit-2.6-push-stats.sh"
```

**Expected:** prints `PASSED` (exit 0). On `FAILED`, open
[Appendix A — IF FAILED](#appendix-a--if-failed--check-those-one-by-one) §2.6
and run each command one by one.

**Auditor posture (record in the self-audit entry):**

| Item | Posture |
|------|---------|
| Push-token TTL default | 14 days |
| Country suppression threshold | 10 |
| Statistics HTTP endpoint | loopback-only (`STATS_LISTEN_ADDR`) |
| Stats file | append-only `/srv/compartarenta-stats/daily.jsonl` |
| DB access for routine stats | none (file + cron only) |

---

### 2.7 Record the deployment and self-audit

**Paste the exact five-line audit-log block printed and saved in §1.6.**
It already contains the commit, version, deployment time, relay image id, and
Entitlement image id for this run. Do not reuse values from an older release.

Then:

1. Append a **Deployment** entry to [`docs/relay-audit-log.md`](../docs/relay-audit-log.md)
   (`Tag` = `v` + `Version`, digests, `Build datetime`, `Git commit`,
   operator role, notes).
2. Append a **Self-audit** entry dated `Build datetime` (or audit finish
   time), pointing at this HOW-TO (`deploy/2026-07-24-HOW-TO-DEPLOY.md`
   §2), summary of PASS/FAIL, and Findings links.
3. For every FAIL: append a **Finding** (`open` → later `resolved` /
   `accepted`).
4. Commit the audit-log update on `main` with the release notes.

Cadence: next full self-audit no later than **90 days** after the previous
one. A missed deadline is itself a finding.

---

## Related files

| Path | Role |
|------|------|
| [`compose.production-stack.yml`](./compose.production-stack.yml) | Stack compose |
| [`env.stack.example`](./env.stack.example) | Env template (placeholders only) |
| [`audit-2.1-public-surface.sh`](./audit-2.1-public-surface.sh) | §2.1 PASSED/FAILED script |
| [`audit-2.2-containers-images.sh`](./audit-2.2-containers-images.sh) | §2.2 PASSED/FAILED script |
| [`audit-2.3-relay-schema.sh`](./audit-2.3-relay-schema.sh) | §2.3 PASSED/FAILED script |
| [`audit-2.4-logs-metrics.sh`](./audit-2.4-logs-metrics.sh) | §2.4 PASSED/FAILED script |
| [`audit-2.5-entitlement.sh`](./audit-2.5-entitlement.sh) | §2.5 PASSED/FAILED script |
| [`audit-2.6-push-stats.sh`](./audit-2.6-push-stats.sh) | §2.6 PASSED/FAILED script |
| [`free-licence/`](./free-licence/) | Authenticated VPS-only free-license GET/SET/DELETE scripts |
| [`../entitlement/deploy/apache2/license-vhost.conf.template`](../entitlement/deploy/apache2/license-vhost.conf.template) | Public client API vhost; internal introspection denied |
| `/srv/compartarenta-relay/docker-compose.secrets.yml` | Host-only relay FCM plus Entitlement FCM and Play bind mounts |
| [`docs/relay-audit-log.md`](../docs/relay-audit-log.md) | Public deploy + audit record |

---

## Appendix A — IF FAILED — CHECK THOSE ONE BY ONE

Use this appendix when a §2 check (or its script) prints `FAILED`.
Run **one** command at a time. Compare to **Expected** (captured from a
known-good production run). Do not invent new expected values — if an
Expected cell says *(paste from this audit)*, fill it from your live
output once that step passes, then keep it here for next time.

Assumes §2.0 vars are already set (`PUBLIC_HOST`, `LICENSE_HOST`,
`DEPLOY_ROOT`, `VHOST_FILE`, `RELEASE_TAG`, `STACK_COMPOSE`,
`SECRETS_COMPOSE`, `FCM_HOST_JSON`, `PLAY_HOST_JSON`, schema versions,
image ids, and `psql_relay`).

---

### A.2.1 Public surface

#### A.2.1.1 DNS A

```bash
dig +short A "$PUBLIC_HOST"
```

**Expected:**

```
64.176.9.30
```

#### A.2.1.2 DNS AAAA

```bash
dig +short AAAA "$PUBLIC_HOST"
```

**Expected:** empty (no AAAA), or an address if one is published later.

#### A.2.1.3 TLS SAN

```bash
echo | openssl s_client -connect "${PUBLIC_HOST}:443" -servername "$PUBLIC_HOST" 2>/dev/null \
  | openssl x509 -noout -text \
  | grep -A1 "Subject Alternative Name"
```

**Expected:**

```
            X509v3 Subject Alternative Name: 
                DNS:sync.incoherences.org
```

#### A.2.1.4 HTTP → HTTPS

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://${PUBLIC_HOST}/v1/envelopes"
```

**Expected:**

```
301
```

#### A.2.1.5 Path enumeration

```bash
for path in / /healthz /readyz /metrics /admin /debug /debug/pprof /pprof; do
  echo -n "$path: "
  curl -s -o /dev/null -w "%{http_code}\n" "https://${PUBLIC_HOST}${path}"
done
```

**Expected:**

```
/: 403
/healthz: 200
/readyz: 200
/metrics: 403
/admin: 403
/debug: 403
/debug/pprof: 403
/pprof: 403
```

`/` is **not** a marketing homepage. This host’s DocumentRoot has no
`index.html`; Apache `-Indexes` returns **403**. **404** is also
acceptable. **200** on `/` is a finding (unexpected page). Public HTML
is `/contact/invite/` only (A.2.1.7). Captured 2026-08-16 (`v0.5.0`).

#### A.2.1.6 Root URL — no ops leakage

```bash
curl -s "https://${PUBLIC_HOST}/" \
  | head -c 200000 \
  | grep -iE 'envelope_id|sender_identity|recipient_identity|relay_envelopes_|queue_depth|ttl_expires_at|operator_action|"build"|"schema_version"|/v1/' \
  || echo "ok"
```

**Expected:**

```
ok
```

#### A.2.1.7 Invite page — Bojairũ / bojairu://

```bash
curl -sS "https://${PUBLIC_HOST}/contact/invite/" \
  | grep -iE 'Bojairũ|bojairu://|Compartarenta|compartarenta://' \
  | head
```

**Expected:** lines containing **Bojairũ** and `bojairu://` only (examples
from a good run):

```
  <title>Bojairũ — Connection invitation</title>
      <h1 style="margin:0;">Bojairũ</h1>
    <p class="lede" data-i18n="en">You received an invitation to connect with someone on Bojairũ.</p>
    <p class="lede" data-i18n="fr" hidden>Vous avez reçu une invitation à vous connecter avec quelqu’un sur Bojairũ.</p>
    <p class="lede" data-i18n="es" hidden>Has recibido una invitación para conectarte con alguien en Bojairũ.</p>
      <p data-i18n="en">If Bojairũ is installed on this device, tap the button below.</p>
      <p data-i18n="fr" hidden>Si Bojairũ est installée sur cet appareil, touchez le bouton ci-dessous.</p>
      <p data-i18n="es" hidden>Si Bojairũ está instalada en este dispositivo, toca el botón de abajo.</p>
        <a id="open-app" class="open-btn" data-open-app href="bojairu://contact/invite">
          <span data-i18n="en">Open in Bojairũ</span>
```

**Fail if** any line shows `Compartarenta` or `compartarenta://`.

#### A.2.1.8 Apache vhost vs template

```bash
diff -u \
  "$DEPLOY_ROOT/source/relay/deploy/apache2/relay-vhost.conf.template" \
  "$VHOST_FILE"
```

**Expected:** the known production drift below (ServerName / cert paths /
comments adapted to `sync.incoherences.org`). A *new* hunk beyond this
is a finding.

```
--- /srv/compartarenta-relay/source/relay/deploy/apache2/relay-vhost.conf.template	2026-07-24 11:37:45.506947229 -0400
+++ /etc/apache2/sites-available/sync.incoherences.org.conf	2026-05-13 17:01:03.333559382 -0400
@@ -5,7 +5,7 @@
 #
 # Adapt:
 #   * ServerName : the dedicated sub-domain on your controlled
-#       domain. The literal `relay` in `relay.example.tld` below is a
+#       domain. The literal `relay` in `sync.incoherences.org` below is a
 #       PLACEHOLDER, not a requirement. Use any name that fits your
 #       product branding (e.g., `sync.<your-domain>`,
 #       `api.<your-domain>`, `m.<your-domain>`,
@@ -34,20 +34,20 @@
 # HTTP : redirect to HTTPS
 # ---------------------------------------------------------------------------
 <VirtualHost *:80>
-    ServerName relay.example.tld
-    Redirect permanent / https://relay.example.tld/
+    ServerName sync.incoherences.org
+    Redirect permanent / https://sync.incoherences.org/
 </VirtualHost>
 
 # ---------------------------------------------------------------------------
 # HTTPS : TLS termination + static landing page + reverse proxy to relay
 # ---------------------------------------------------------------------------
 <VirtualHost *:443>
-    ServerName relay.example.tld
+    ServerName sync.incoherences.org
 
     # --- TLS ---
     SSLEngine on
-    SSLCertificateFile      /etc/letsencrypt/live/relay.example.tld/fullchain.pem
-    SSLCertificateKeyFile   /etc/letsencrypt/live/relay.example.tld/privkey.pem
+    SSLCertificateFile      /etc/letsencrypt/live/sync.incoherences.org/fullchain.pem
+    SSLCertificateKeyFile   /etc/letsencrypt/live/sync.incoherences.org/privkey.pem
     Protocols h2 http/1.1
 
     # Apache's recommended SSL parameters, as managed by Let's Encrypt's
@@ -81,7 +81,7 @@
     #
     # This page is purely static — it reads the `?v=…&c=…` payload of the
     # invitation URL on the client and offers two paths:
-    #   (1) tap a `bojairu://contact/invite?…` deep link, and
+    #   (1) tap a `compartarenta://contact/invite?…` deep link, and
     #   (2) copy the full deep link and paste it into the app's
     #       "Scan / enter a code" screen.
     # It never sends the payload to the relay.
```

Note: the live vhost comment still saying `compartarenta://` is **stale
comment text** in Apache config. The invite **page** must still be
Bojairũ / `bojairu://` (A.2.1.7). Fixing that comment is a separate
doc/ops cleanup, not a substitute for the landing copy in §1.7.

#### A.2.1.9 Postgres — no host ports

```bash
docker inspect --format '{{ json .NetworkSettings.Ports }}' compartarenta-relay-db
docker inspect --format '{{ json .NetworkSettings.Ports }}' compartarenta-entitlement-db
docker port compartarenta-relay-db || true
docker port compartarenta-entitlement-db || true
```

**Expected:**

```
{"5432/tcp":null}
{"5432/tcp":null}
```

(`docker port` prints nothing.)

---

### A.2.2 Containers and images

#### A.2.2.1 Compose ps

```bash
cd "$DEPLOY_ROOT"
docker compose --env-file env/.env -f "$STACK_COMPOSE" -f "$SECRETS_COMPOSE" ps
```

**Expected:**

```
NAME                           IMAGE                              COMMAND                  SERVICE                CREATED       STATUS                PORTS
compartarenta-entitlement      compartarenta-entitlement:v0.5.1   "/entitlement"           entitlement            5 hours ago   Up 5 hours            127.0.0.1:8081->8080/tcp
compartarenta-entitlement-db   postgres:17-alpine                 "docker-entrypoint.s…"   entitlement-postgres   5 weeks ago   Up 7 days (healthy)   5432/tcp
compartarenta-relay            compartarenta-relay:v0.5.1         "/relay"                 relay                  5 hours ago   Up 5 hours            127.0.0.1:8080->8080/tcp, 127.0.0.1:9090->9090/tcp
compartarenta-relay-db         postgres:17-alpine                 "docker-entrypoint.s…"   postgres               5 weeks ago   Up 7 days (healthy)   5432/tcp
```

(`CREATED` / uptime ages will change; names, images, `Up`/`healthy`, and
loopback-only published ports must match.)

#### A.2.2.2 Image digests

```bash
docker inspect --format '{{.Id}}' "compartarenta-relay:${RELEASE_TAG}"
docker inspect --format '{{.Id}}' "compartarenta-entitlement:${RELEASE_TAG}"
```

**Expected:** the first line equals the exact `RELAY_DIGEST` saved in §1.6;
the second equals the exact `ENTITLEMENT_DIGEST`. Never compare with a digest
copied from an older release.

#### A.2.2.3 No secrets in git

```bash
cd "$DEPLOY_ROOT/source"
git grep -nE '(POSTGRES_PASSWORD|DATABASE_URL|ENTITLEMENT_INTERNAL_TOKEN|LICENSE_|sk_live)=' \
  -- ':!**/relay-audit-checklist.md' ':!**/relay-deployment.md' \
  ':!**/entitlement-audit-checklist.md' ':!**/.env.example' \
  ':!**/env.stack.example' || echo "clean"
```

**Expected:**

```
entitlement/README.md:43:ENTITLEMENT_INTERNAL_TOKEN=<same as entitlement service>
```

(Documentation placeholder only — not a live secret. Fail if a real token
or password appears.)

#### A.2.2.4 Non-root + read-only

```bash
user_cfg=$(docker inspect --format '{{.Config.User}}' compartarenta-relay)
uid_runtime=$(docker top compartarenta-relay 2>/dev/null | awk 'NR==2 {print $1}')
echo "relay Config.User=$user_cfg RuntimeUID=$uid_runtime"
ent_user=$(docker inspect --format '{{.Config.User}}' compartarenta-entitlement)
echo "entitlement Config.User=$ent_user"
ro=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' compartarenta-relay)
echo "relay ReadonlyRootfs=$ro"
```

**Expected:**

```
relay Config.User=65532:65532 RuntimeUID=65532
entitlement Config.User=65532:65532
relay ReadonlyRootfs=true
```

#### A.2.2.5 Process list

```bash
docker top compartarenta-relay
docker top compartarenta-relay-db
```

**Expected:**

```
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
65532               …                   …                   …                   …                   ?                   …                   /relay
```

```
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
70                  …                   …                   …                   …                   ?                   …                   postgres
70                  …                   …                   …                   …                   ?                   …                   postgres: checkpointer
70                  …                   …                   …                   …                   ?                   …                   postgres: background writer
70                  …                   …                   …                   …                   ?                   …                   postgres: walwriter
70                  …                   …                   …                   …                   ?                   …                   postgres: autovacuum launcher
70                  …                   …                   …                   …                   ?                   …                   postgres: logical replication launcher
70                  …                   …                   …                   …                   ?                   …                   postgres: … idle
```

(PIDs/times vary. Relay: exactly one `/relay` as UID `65532`. DB: all UID
`70`, CMD starts with `postgres`. Extra `postgres: … idle` rows are
client sessions on the Docker network — OK.)

---

### A.2.3 Relay schema and retention

#### A.2.3.1 Schema dump (visual)

```bash
psql_relay \
  -c '\dt+' \
  -c '\d+ schema_version' \
  -c '\d+ routing_relationships' \
  -c '\d+ idempotency_entries' \
  -c '\d+ envelopes' \
  -c '\d+ sweeper_checkpoint' \
  -c '\d+ operator_actions' \
  -c '\d+ routing_push_tokens' \
  -c '\d+ relay_day_metrics'
```

**Expected:** `\dt+` shows exactly these **12** tables (sizes vary):

```
 public | envelopes
 public | housing_reminder_plan_generation
 public | idempotency_entries
 public | operator_actions
 public | recipient_notification_timezone
 public | relay_day_metrics
 public | routing_push_tokens
 public | routing_relationships
 public | scheduled_notification_fires
 public | scheduled_notification_targets
 public | schema_version
 public | sweeper_checkpoint
(12 rows)
```

Verified on the `\d+` dump from this audit:

- `envelopes.ciphertext` is **bytea** (not text)
- Identities / envelope ids are **bytea** with length CHECKs
- `routing_relationships.status` CHECK ∈ `{active,disconnecting}`
- `routing_push_tokens.provider` CHECK ∈ `{fcm,apns}`
- `relay_day_metrics` has numeric counters only (no TEXT)
- Owner role name on tables may be `Roberr` (Postgres role from `.env`) — OK

#### A.2.3.2 Table set

```bash
expected="envelopes housing_reminder_plan_generation idempotency_entries operator_actions recipient_notification_timezone relay_day_metrics routing_push_tokens routing_relationships scheduled_notification_fires scheduled_notification_targets schema_version sweeper_checkpoint"
actual=$(psql_relay -At -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" \
  | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
echo "Expected tables: $expected"
echo "Actual tables:   $actual"
[ "$expected" = "$actual" ] && echo "SCHEMA_TABLES PASS" || echo "SCHEMA_TABLES FAIL"
```

**Expected:**

```
Expected tables: envelopes housing_reminder_plan_generation idempotency_entries operator_actions recipient_notification_timezone relay_day_metrics routing_push_tokens routing_relationships scheduled_notification_fires scheduled_notification_targets schema_version sweeper_checkpoint
Actual tables:   envelopes housing_reminder_plan_generation idempotency_entries operator_actions recipient_notification_timezone relay_day_metrics routing_push_tokens routing_relationships scheduled_notification_fires scheduled_notification_targets schema_version sweeper_checkpoint
SCHEMA_TABLES PASS
```

#### A.2.3.3 TEXT column allow-list

```bash
expected_cols="operator_actions.action operator_actions.actor operator_actions.reason operator_actions.target_kind recipient_notification_timezone.iana_timezone routing_push_tokens.country routing_push_tokens.provider routing_push_tokens.push_token routing_relationships.status scheduled_notification_fires.status scheduled_notification_targets.domain scheduled_notification_targets.reminder_kind"
actual_cols=$(psql_relay -At -c "
  SELECT table_name||'.'||column_name
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND data_type IN ('text', 'character varying')
  ORDER BY table_name, column_name;
" | tr -d '\r' | tr '\n' ' ' | sed 's/ $//')
echo "Expected TEXT cols: $expected_cols"
echo "Actual TEXT cols:   $actual_cols"
[ "$expected_cols" = "$actual_cols" ] && echo "NO_PLAINTEXT PASS" || echo "NO_PLAINTEXT FAIL"
```

**Expected:**

```
Expected TEXT cols: operator_actions.action operator_actions.actor operator_actions.reason operator_actions.target_kind recipient_notification_timezone.iana_timezone routing_push_tokens.country routing_push_tokens.provider routing_push_tokens.push_token routing_relationships.status scheduled_notification_fires.status scheduled_notification_targets.domain scheduled_notification_targets.reminder_kind
Actual TEXT cols:   operator_actions.action operator_actions.actor operator_actions.reason operator_actions.target_kind recipient_notification_timezone.iana_timezone routing_push_tokens.country routing_push_tokens.provider routing_push_tokens.push_token routing_relationships.status scheduled_notification_fires.status scheduled_notification_targets.domain scheduled_notification_targets.reminder_kind
NO_PLAINTEXT PASS
```

#### A.2.3.4 Envelope TTL

```bash
n=$(psql_relay -At -c \
  "SELECT count(*) FROM envelopes WHERE created_at < now() - interval '7 days';" \
  | tr -d '\r')
echo "Envelopes older than 7 days: $n"
[ "$n" = "0" ] && echo "TTL PASS" || echo "TTL FAIL"
```

**Expected:**

```
Envelopes older than 7 days: 0
TTL PASS
```

#### A.2.3.5 Sweeper freshness

```bash
last_run=$(psql_relay -At -c \
  "SELECT last_run_at FROM sweeper_checkpoint WHERE id = 1;" | tr -d '\r')
fresh=$(psql_relay -At -c \
  "SELECT (now() - last_run_at) < interval '5 minutes' FROM sweeper_checkpoint WHERE id = 1;" \
  | tr -d '\r')
echo "Sweeper last_run_at=$last_run fresh=$fresh"
[ "$fresh" = "t" ] && echo "SWEEPER PASS" || echo "SWEEPER FAIL"
```

**Expected:** `fresh=t` and `SWEEPER PASS` (`last_run_at` changes each minute), e.g.:

```
Sweeper last_run_at=2026-07-24 22:27:12.463813+00 fresh=t
SWEEPER PASS
```

#### A.2.3.6 No IP columns

```bash
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
[ -z "$ip_cols" ] && echo "NO_IP_COLS PASS" || { echo "NO_IP_COLS FAIL"; echo "$ip_cols"; }
```

**Expected:**

```
NO_IP_COLS PASS
```

#### A.2.3.7 Operator actions

```bash
psql_relay -c "SELECT count(*) AS operator_action_rows FROM operator_actions;"
psql_relay -c "
  SELECT count(*) AS bad_rows FROM operator_actions
  WHERE coalesce(trim(actor),'') = ''
     OR coalesce(trim(action),'') = ''
     OR coalesce(trim(reason),'') = '';
"
```

**Expected:**

```
 operator_action_rows 
----------------------
                    2
(1 row)

 bad_rows 
----------
        0
(1 row)
```

(`operator_action_rows` may grow later; must stay ≥ 1 and `bad_rows` = 0.)

---

### A.2.4 Logs and metrics

#### A.2.4.1 Log sample — no forbidden keys

```bash
sample=$(docker logs --tail 1000 compartarenta-relay 2>&1)
forbidden='"ciphertext"|"display_name"|"email"|"recipient_payload"|"sender_payload"|"avatar"'
hits=$(printf '%s' "$sample" | grep -E "$forbidden" || true)
[ -z "$hits" ] && echo "LOGS PASS" || { echo "LOGS FAIL"; echo "$hits" | head -5; }
```

**Expected:**

```
Sampled 771 log lines
LOGS PASS
```

(Line count varies; must end with `LOGS PASS`.)

#### A.2.4.2 Metrics not public

```bash
code=$(curl -s -o /dev/null -w "%{http_code}" "https://${PUBLIC_HOST}/metrics")
echo "GET https://${PUBLIC_HOST}/metrics -> HTTP $code"
[ "$code" -ge 400 ] && [ "$code" -lt 600 ] && echo "METRICS_PUBLIC PASS" || echo "METRICS_PUBLIC FAIL"
```

**Expected:**

```
GET https://sync.incoherences.org/metrics -> HTTP 403
METRICS_PUBLIC PASS
```

#### A.2.4.3 Private metrics scrape

```bash
metrics=$(curl -s http://127.0.0.1:9090/metrics)
expected_metrics="relay_envelopes_accepted_total relay_envelopes_delivered_total relay_envelopes_expired_total relay_envelopes_queue_depth relay_envelopes_oldest_undelivered_age_seconds relay_sweeper_runs_total relay_http_requests_total"
missing=""
for name in $expected_metrics; do
  printf '%s' "$metrics" \
    | grep -qE "^(# (HELP|TYPE) )?$name([[:space:]]|\{|\$)" \
    || missing="$missing $name"
done
[ -z "$missing" ] && echo "METRICS_PRIVATE PASS" || echo "METRICS_PRIVATE FAIL — missing:$missing"
```

**Expected:**

```
METRICS_PRIVATE PASS
```

---

### A.2.5 Entitlement

#### A.2.5.1 Loopback bind / public refuse

```bash
ss -ltn | grep -E ':8081\b' || true
curl -s -o /dev/null -w "%{http_code}\n" --connect-timeout 3 \
  "https://${PUBLIC_HOST}:8081/healthz" || echo "unreachable_from_public"
```

**Expected:**

```
LISTEN 0      4096       127.0.0.1:8081      0.0.0.0:*          
000
unreachable_from_public
```

The two-line `000` + `unreachable_from_public` is from this **manual**
`curl || echo` pair. `audit-2.5-entitlement.sh` must **not** append a
second `000` (`|| echo 000` after `curl -w '%{http_code}'`): that
becomes `000000` and the script fails even when 8081 is correctly
unreachable. The script uses `|| true` and accepts `000` or empty.

```bash
curl -sS http://127.0.0.1:8081/healthz | jq .
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8081/readyz
```

**Expected:**

```
{
  "build": "62926400f29428e7951326fe554e5da375e6e4f2",
  "schema_version": "3",
  "status": "ok"
}
200
```

For `v0.5.1`, `build` must equal the full `GIT_COMMIT` above, schema must be
`3`, status must be `ok`, and readyz must be `200`.

#### A.2.5.2 Public client route and protected server routes

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "http://${LICENSE_HOST}/healthz"
curl -sS "https://${LICENSE_HOST}/healthz" | jq .
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://${LICENSE_HOST}/readyz"
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://${LICENSE_HOST}/v1/introspect/envelope"
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://${LICENSE_HOST}/v1/free-licenses"
```

**Expected:** `301`; the same build/schema/status JSON as loopback; `200`;
`403`; `401`. The first two responses prove that mobile clients can traverse
DNS, TLS, Apache, and the Entitlement reverse proxy. The last two prove that
relay introspection and unauthenticated operator access remain blocked.

#### A.2.5.3 Entitlement configuration and secret mounts

```bash
grep -E '^(ENTITLEMENT_|PLAY_SERVICE_ACCOUNT_JSON_PATH|FCM_SERVICE_ACCOUNT_JSON_PATH)' \
  "$DEPLOY_ROOT/env/.env" | sed 's/=.*/=***redacted***/'
```

**Expected:** at least these keys (values redacted in the log):

```
ENTITLEMENT_POSTGRES_USER=***redacted***
ENTITLEMENT_POSTGRES_PASSWORD=***redacted***
ENTITLEMENT_POSTGRES_DB=***redacted***
ENTITLEMENT_TAG=***redacted***
ENTITLEMENT_ENABLED=***redacted***
ENTITLEMENT_INTROSPECT_URL=***redacted***
ENTITLEMENT_INTERNAL_TOKEN=***redacted***
PLAY_SERVICE_ACCOUNT_JSON_PATH=***redacted***
FCM_SERVICE_ACCOUNT_JSON_PATH=***redacted***
```

Unredacted values must be:

```text
ENTITLEMENT_INTROSPECT_URL=http://entitlement:8080
PLAY_SERVICE_ACCOUNT_JSON_PATH=/run/secrets/play-android-developer.json
FCM_SERVICE_ACCOUNT_JSON_PATH=/run/secrets/fcm-service-account.json
```

```bash
docker inspect compartarenta-entitlement \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
docker run --rm \
  -v "${PLAY_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; d=json.load(open('/sa.json')); print(d['type'], d['project_id'])"
docker run --rm \
  -v "${FCM_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; d=json.load(open('/sa.json')); print(d['type'], d['project_id'])"
```

**Expected:** Entitlement lists both destinations above. Both JSON checks print
`service_account`; the Firebase check also prints project `bojairu`. The two
host source paths must be different.

#### A.2.5.4 Internal authorization and free-license read

```bash
curl -sS -X POST http://127.0.0.1:8081/v1/introspect/envelope \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${ENTITLEMENT_INTERNAL_TOKEN}" \
  -d '{"module":"housing","plan_id":"audit-missing-plan","participant_installation_id":"audit-missing-inst","envelope_kind":7,"operation":"housing_realized_expense_propose"}' \
  | jq .
```

**Expected:**

```
{
  "allow": false,
  "code": "entitlement_not_entitled"
}
```

```bash
"$DEPLOY_ROOT/source/deploy/free-licence/free-license-get.sh"
```

**Expected:** authenticated CSV whose first line is
`Nom,InstallationId`. This GET is non-mutating; do not use SET or DELETE as an
audit smoke.

#### A.2.5.5 Entitlement tables

```bash
docker exec compartarenta-entitlement-db \
  psql -U "$ENTITLEMENT_POSTGRES_USER" -d "$ENTITLEMENT_POSTGRES_DB" -c '\dt'
```

**Expected:**

```
                   List of relations
 Schema |             Name             | Type  | Owner 
--------+------------------------------+-------+-------
 public | housing_expense_decisions    | table | Bvii
 public | housing_plan_active_revision | table | Bvii
 public | housing_plan_licenses        | table | Bvii
 public | housing_plan_rosters         | table | Bvii
 public | housing_plans                | table | Bvii
 public | installations                | table | Bvii
 public | license_receipts             | table | Bvii
 public | schema_version               | table | Bvii
(8 rows)
```

(Owner role name may differ; the **8** table names must match.)

#### A.2.6.1 FCM project_id

```bash
# Wrong: host open() → PermissionError (0600 / UID 65532).
# Wrong: docker exec … cat → scratch image has no `cat` → empty pipe → JSONDecodeError.
docker run --rm \
  -v "${FCM_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; print(json.load(open('/sa.json'))['project_id'])"
```

**Expected:**

```
bojairu
```

(First run may pull `python:3.12-alpine` once; then prints `bojairu`.)

#### A.2.6.2 Wake env flags

```bash
grep -E '^(WAKE_PUSH_DISPATCH_ENABLED|FCM_SERVICE_ACCOUNT_JSON_PATH)=' \
  "$DEPLOY_ROOT/env/.env"
```

**Expected:**

```
WAKE_PUSH_DISPATCH_ENABLED=true                       # or true, but needs FCM/APNs paths if so.
FCM_SERVICE_ACCOUNT_JSON_PATH=/run/secrets/fcm-service-account.json
```

(Inline comments after `true` are OK; the value must be `true`.)

```bash
docker compose --env-file env/.env \
  -f "$STACK_COMPOSE" \
  -f "$SECRETS_COMPOSE" \
  logs --tail 80 relay | grep -iE 'fcm|push\.wake|push\.fcm' || true
```

**Expected:** empty, or routine lines. **Fail** if `push.fcm_init_failed` or
`push.wake.send_failed` floods the sample. *(paste from this audit if any)*

#### A.2.6.4 Stats cron + file

```bash
crontab -l | grep daily-stats || true
ls -la /srv/compartarenta-stats/daily.jsonl 2>/dev/null || true
head -n 1 /srv/compartarenta-stats/daily.jsonl 2>/dev/null | jq . || true
```

**Expected (good):**

```
7 0 * * * /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh >> /srv/compartarenta-stats/cron.log 2>&1
-rw-rw-r-- 1 compartarenta-relay compartarenta-relay … /srv/compartarenta-stats/daily.jsonl
{ … JSON line … }
```

**Observed 2026-07-24:** first JSONL line may be an old day (`2026-06-17`);
`ls` mtime showed appends continuing (`Jul 24 00:07`). Mid-audit crontab
still listed a **commented** host `daily-stats-append.sh` line beside
via-docker — cleaned the same day; re-check showed **only** via-docker:

```
7 0 * * * /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh >> /srv/compartarenta-stats/cron.log 2>&1
```

---

## Operator notice (optional; after this relay binary is live)

Not part of every deploy. Use only when you need to notify Android
devices that still have a valid FCM token. The running relay **image**
must include the `operator-notice` subcommand (this delivery). Until
that image is recreated, the command will fail.

Run as `compartarenta-relay` (no `sudo` if you are already that user).
The container is `FROM scratch` (no shell): `exec` must call `/relay`.

This is **not** a public HTTP API and **not** an entitlement command.
Long text stays on the locale pages
https://bojairu.app/fr/message , https://bojairu.app/en/message , and
https://bojairu.app/es/mensaje . Android / FCM only (no APNs).

At least one of `--target-build` or `--consult-site` is required.
Default is dry-run. `--confirm` actually sends (not a rehearsal).

**Before `--confirm` with `--target-build=N` (Play update):**

1. Google Play Console → app **Bojairũ** (`app.incoherences.bojairu`) →
   **Production** already has AAB `versionCode` **N** on the public
   listing. The in-app badge opens
   `https://play.google.com/store/apps/details?id=app.incoherences.bojairu`,
   not Internal testing. Do not announce an Internal-only or unreleased
   number.
2. **N** is **strictly greater** than the build on phones that should see
   the badge (`installed < N`). Same number as already installed →
   notification can still arrive; Play badge is hidden. `--consult-site`
   can still offer the site message.
3. Re-run `--dry-run` with the **same** flags, then `--confirm`.

`--consult-site` alone (no `--target-build`) skips the Play badge; then
steps 1–2 do not apply.

Dry-run (example `versionCode` **39** — use the number you mean):

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  -f docker-compose.secrets.yml \
  exec -T relay /relay operator-notice --consult-site --target-build=39 --dry-run
```

Send:

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  -f docker-compose.secrets.yml \
  exec -T relay /relay operator-notice --consult-site --target-build=39 --confirm
```

`--consult-site` alone (no Play update affordance):

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  -f docker-compose.secrets.yml \
  exec -T relay /relay operator-notice --consult-site --dry-run
```
