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
STACK_COMPOSE=source/deploy/compose.production-stack.yml
SECRETS_COMPOSE=docker-compose.secrets.yml
LANDING_SRC="$DEPLOY_ROOT/source/relay/deploy/landing/contact/invite"
LANDING_DST=/var/www/compartarenta-relay-landing/contact/invite
# One release version for both images (RELAY_TAG + ENTITLEMENT_TAG in env/.env).
RELEASE_TAG=v0.4.0
# Host path of the FCM JSON currently mounted (confirm with inspect in 1.4).
FCM_HOST_JSON=/srv/compartarenta-relay/secrets/bojairu-firebase-adminsdk-fbsvc-3f8e9288d7.json
FCM_CONTAINER_PATH=/run/secrets/fcm-service-account.json
```

Set `RELEASE_TAG` to this release’s version. Update `FCM_HOST_JSON` to the
real filename on disk after Procedure A.

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
```

Start (or update) a **local** notepad on your laptop — not on the VPS —
with the four-line block in §1.6. Put `Git commit:` now; fill the rest
after build.

### 1.3 Edit `env/.env`

```bash
cd "$DEPLOY_ROOT"
nano env/.env
```

Set these to this release (version ≠ git SHA):

| Variable in `.env` | Value |
|--------------------|--------|
| `RELAY_TAG` | `$RELEASE_TAG` (e.g. `v0.4.0`) |
| `ENTITLEMENT_TAG` | `$RELEASE_TAG` (same version number) |
| `BUILD_DIGEST` | `$GIT_COMMIT` (full SHA from §1.2) |

Leave `ENTITLEMENT_BUILD_DIGEST` unset so it follows `BUILD_DIGEST`.

Leave these **unchanged**:

| Variable | Value |
|----------|--------|
| `FCM_SERVICE_ACCOUNT_JSON_PATH` | `/run/secrets/fcm-service-account.json` |
| `ENTITLEMENT_INTROSPECT_URL` | `http://entitlement:8080` |
| `WAKE_PUSH_DISPATCH_ENABLED` | `true` (production wake) |

### 1.4 Confirm FCM mount

```bash
cd "$DEPLOY_ROOT"
docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
```

**Expected:** one line with `$FCM_HOST_JSON` → `$FCM_CONTAINER_PATH`.

For a new host JSON file, complete
[Procedure A](#procedure-a--replace-fcm-service-account-file) first, then
re-run this inspect before §1.6.

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
```

**Save on your laptop** (SSH can drop during a long audit). Use exactly
this shape — `Version` without a leading `v`; `Docker SHA` = **relay**
image id (`RELAY_DIGEST`):

```text
Git commit: <GIT_COMMIT from §1.2>
Version: 0.4.0
Build datetime: 2026-07-24T17:49Z		(13:49 EST)
Docker SHA: sha256:…
```

Also keep `ENTITLEMENT_DIGEST` somewhere in the same note (fifth line is
fine). You will paste the four-line block at §2.7.

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
curl -sS "https://${PUBLIC_HOST}/healthz" | jq .
curl -sS -H 'Accept: text/html' "https://${PUBLIC_HOST}/healthz" | head
curl -sS -o /dev/null -w '%{http_code}\n' "https://${PUBLIC_HOST}/readyz"

curl -sS http://127.0.0.1:8081/healthz | jq .
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8081/readyz

docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
docker run --rm \
  -v "${FCM_HOST_JSON}:/sa.json:ro" \
  python:3.12-alpine \
  python -c "import json; print(json.load(open('/sa.json'))['project_id'])"

curl -sS "https://${PUBLIC_HOST}/contact/invite/" | grep -iE 'Bojairũ|bojairu://' | head
```

**Expected:**

- healthz JSON healthy; HTML healthz readable; readyz `200`
- entitlement healthz/readyz OK on loopback
- FCM mount host → `/run/secrets/fcm-service-account.json`; `project_id` prints `bojairu`
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
| Firebase **service account** JSON (`"type": "service_account"`, `project_id`: **`bojairu`**) | Relay sends FCM wake | VPS host → see below |
| `google-services.json` (Android client flavors) | Mobile app Firebase SDK | App repo / build only — **never** mount on the relay |

`FCM_SERVICE_ACCOUNT_JSON_PATH` in `env/.env` is the path **inside the container**
(`/run/secrets/fcm-service-account.json`). It does **not** tell you where the
file sits on the host. The host file lives under
`/srv/compartarenta-relay/secrets/`.

| Role | Path |
|------|------|
| Source file on the VPS host | `/srv/compartarenta-relay/secrets/<adminsdk-filename>.json` |
| Path inside Docker (`.env`) | `/run/secrets/fcm-service-account.json` |

See the current bind without guessing:

```bash
docker inspect compartarenta-relay \
  --format '{{range .Mounts}}{{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
```

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

# Edit docker-compose.secrets.yml — change ONLY the host (left) side:
#   - /srv/compartarenta-relay/secrets/<new-filename>.json:/run/secrets/fcm-service-account.json:ro
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

Return to §1.4 (confirm mount), then §1.6 Build so the new bind takes
effect. Archive the previous host JSON after §1.8 smoke shows
`project_id` = `bojairu`.

---

## 2. Audit

Run **after** §1. Keep your laptop notepad open (the four-line block from
§1.6). Map: `Version` → tag `v`+version; `Build datetime` → deploy time;
`Docker SHA` → relay digest; plus `ENTITLEMENT_DIGEST` from the same note.

Open findings go into [`docs/relay-audit-log.md`](../docs/relay-audit-log.md)
(Findings section). Passing checks are summarized in the Self-audit entry
(§2.7).

### 2.0 Audit shell and helpers

```bash
DEPLOY_ROOT=/srv/compartarenta-relay
PUBLIC_HOST=sync.incoherences.org
STACK_COMPOSE=source/deploy/compose.production-stack.yml
SECRETS_COMPOSE=docker-compose.secrets.yml
RELEASE_TAG=v0.4.0
# Image Ids from §1.6 laptop notepad (required by audit-2.2):
RELAY_DIGEST=sha256:3f70e5d2c55babdd56f57771d6403f4add9e19f3ff6a477540ebb7e497adeabc
ENTITLEMENT_DIGEST=sha256:4c30c73512ec9603b7b9b8f10757225a17a52a4ffc4c82667aa310fcff5e2c42
FCM_HOST_JSON=/srv/compartarenta-relay/secrets/bojairu-firebase-adminsdk-fbsvc-3f8e9288d7.json
VHOST_FILE=/etc/apache2/sites-available/sync.incoherences.org.conf
export RELAY_DIGEST ENTITLEMENT_DIGEST RELEASE_TAG DEPLOY_ROOT PUBLIC_HOST \
  STACK_COMPOSE SECRETS_COMPOSE FCM_HOST_JSON VHOST_FILE

cd "$DEPLOY_ROOT"
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
image Ids). Override any §2.0 default by exporting vars before running.

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

Out of scope for this audit (do not fail the run on these): Play/App Store
license verifiers, signed assertions Phase B+.

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

**Paste your laptop notepad block** (same four lines as §1.6), for example:

```text
Git commit: 5a434ecad615f76c1feaba41d033450dc2ad8578
Version: 0.4.0
Build datetime: 2026-07-24T17:49Z		(13:49 EST)
Docker SHA: sha256:3f70e5d2c55babdd56f57771d6403f4add9e19f3ff6a477540ebb7e497adeabc
```

If you also saved entitlement’s image id, paste that too. Otherwise the
writer uses the `ENTITLEMENT_DIGEST` from §1.6 / §2.2 for this release.

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
| `/srv/compartarenta-relay/docker-compose.secrets.yml` | Host-only FCM bind mount |
| [`docs/relay-audit-log.md`](../docs/relay-audit-log.md) | Public deploy + audit record |

---

## Appendix A — IF FAILED — CHECK THOSE ONE BY ONE

Use this appendix when a §2 check (or its script) prints `FAILED`.
Run **one** command at a time. Compare to **Expected** (captured from a
known-good production run). Do not invent new expected values — if an
Expected cell says *(paste from this audit)*, fill it from your live
output once that step passes, then keep it here for next time.

Assumes §2.0 vars are already set (`PUBLIC_HOST`, `DEPLOY_ROOT`,
`VHOST_FILE`, `RELEASE_TAG`, `STACK_COMPOSE`, `SECRETS_COMPOSE`,
`FCM_HOST_JSON`, `psql_relay`).

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
/: 200
/healthz: 200
/readyz: 200
/metrics: 403
/admin: 403
/debug: 403
/debug/pprof: 403
/pprof: 403
```

#### A.2.1.6 Landing root — no ops leakage

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
compartarenta-entitlement      compartarenta-entitlement:v0.4.0   "/entitlement"           entitlement            5 hours ago   Up 5 hours            127.0.0.1:8081->8080/tcp
compartarenta-entitlement-db   postgres:17-alpine                 "docker-entrypoint.s…"   entitlement-postgres   5 weeks ago   Up 7 days (healthy)   5432/tcp
compartarenta-relay            compartarenta-relay:v0.4.0         "/relay"                 relay                  5 hours ago   Up 5 hours            127.0.0.1:8080->8080/tcp, 127.0.0.1:9090->9090/tcp
compartarenta-relay-db         postgres:17-alpine                 "docker-entrypoint.s…"   postgres               5 weeks ago   Up 7 days (healthy)   5432/tcp
```

(`CREATED` / uptime ages will change; names, images, `Up`/`healthy`, and
loopback-only published ports must match.)

#### A.2.2.2 Image digests

```bash
docker inspect --format '{{.Id}}' "compartarenta-relay:${RELEASE_TAG}"
docker inspect --format '{{.Id}}' "compartarenta-entitlement:${RELEASE_TAG}"
```

**Expected:** (must equal `RELAY_DIGEST` / `ENTITLEMENT_DIGEST` from §1.6)

```
sha256:3f70e5d2c55babdd56f57771d6403f4add9e19f3ff6a477540ebb7e497adeabc
sha256:4c30c73512ec9603b7b9b8f10757225a17a52a4ffc4c82667aa310fcff5e2c42
```

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

```bash
curl -sS http://127.0.0.1:8081/healthz | jq .
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8081/readyz
```

**Expected:**

```
{
  "build": "5a434ecad615f76c1feaba41d033450dc2ad8578",
  "schema_version": "1",
  "status": "ok"
}
200
```

(`build` SHA changes per release; `status` must be `ok`, readyz must be `200`.)

```bash
grep -E '^ENTITLEMENT_' "$DEPLOY_ROOT/env/.env" | sed 's/=.*/=***redacted***/'
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
```

Unredacted: `ENTITLEMENT_INTROSPECT_URL` must be `http://entitlement:8080`.

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
