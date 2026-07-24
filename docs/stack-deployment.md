# Bojairũ Stack — VPS Deployment Runbook (Relay + Entitlement)

This runbook describes how to deploy and upgrade the **full backend stack**
on an existing Ubuntu VPS that already runs (or previously ran) the
Bojairũ relay. It covers:

- **Relay** — encrypted envelope transport (public via Apache TLS)
- **Entitlement** — housing licensing state (private, loopback only)

It assumes host preparation, Apache, TLS, and the `compartarenta-relay`
deploy user are already in place per
[`relay-deployment.md`](./relay-deployment.md). Read that document for
topology, Apache vhost, certbot, patch cadence, and audit posture; **this
document only adds entitlement and switches the compose manifest to the
combined stack.**

Product semantics: `openspec/changes/entitlement-server`,
`licensing-trial-and-plan-entitlement`,
`subscription-entitlement-minimal-server-state`.

## At a glance

| Item | Where |
|------|-------|
| Combined compose manifest | [`deploy/compose.production-stack.yml`](../deploy/compose.production-stack.yml) |
| Merged environment template | [`deploy/env.stack.example`](../deploy/env.stack.example) |
| Relay-only compose (legacy) | [`relay/compose.yml`](../relay/compose.yml) |
| Entitlement source | [`entitlement/`](../entitlement) |
| Relay source | [`relay/`](../relay) |
| Apache / TLS / host prep | [`relay-deployment.md`](./relay-deployment.md) |
| Audit checklist | [`relay-audit-checklist.md`](./relay-audit-checklist.md) |
| Entitlement audit checklist | [`entitlement-audit-checklist.md`](./entitlement-audit-checklist.md) |
| Daily stats cron (Docker VPS) | [`relay/scripts/daily-stats-append-via-docker.sh`](../relay/scripts/daily-stats-append-via-docker.sh) — see [Daily statistics cron](#daily-statistics-cron-containerized-vps) |

## Topology (additions over relay-only)

```
              Apache (host, existing)
                     │ HTTPS / 443
                     ▼
              relay :8080  (127.0.0.1, public via proxy)
                     │
                     │ HTTP introspection (private Docker network)
                     ▼
              entitlement :8080  (127.0.0.1:8081 on host, NOT proxied)
                     │
                     ▼
              entitlement-postgres  (no host port)

              relay ──► postgres  (existing relay DB, volume `pgdata`)
```

| Port | Visibility | Service |
|------|------------|---------|
| 443 | public (Apache) | Relay `/v1/*`, `/healthz`, `/readyz` |
| 8080 | `127.0.0.1` | Relay binary |
| 9090 | `127.0.0.1` | Relay `/metrics` |
| 8081 | `127.0.0.1` | Entitlement `/healthz`, API (operator / relay only) |
| 5432 | Docker internal only | Two separate Postgres instances |

**No new public port** is required. Entitlement is never exposed through
Apache.

## Deployment directory (unchanged)

```
/srv/compartarenta-relay/
├── source/                    git clone of this repository
│   ├── relay/
│   ├── entitlement/
│   └── deploy/
│       ├── compose.production-stack.yml
│       └── env.stack.example
├── env/
│   └── .env                   mode 0600 — relay + entitlement secrets
└── audit/
```

The compose project name stays **`compartarenta-relay`**. The relay
Postgres volume name stays **`pgdata`**, so migrating from
`relay/compose.yml` preserves existing relay data.

---

## First-time entitlement on an existing relay VPS

Use this when the relay already runs from `source/relay/compose.yml` and
you are **adding entitlement** for the first time.

### 1. Tag the release locally (workstation)

```bash
cd Compartarenta
git pull
# commit / tag as usual, then:
git tag vX.Y.Z
git push origin vX.Y.Z
git rev-parse HEAD    # note the SHA for BUILD_DIGEST
date -u +"%Y-%m-%dT%H:%MZ"   # note for audit log later
```

### 2. Pull on the VPS

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay
git -C source pull --ff-only
```

Confirm the new paths exist:

```bash
ls source/entitlement/Dockerfile
ls source/deploy/compose.production-stack.yml
```

### 3. Update `env/.env`

**Do not replace** your existing relay secrets. **Merge** the new
variables from [`deploy/env.stack.example`](../deploy/env.stack.example).

Minimum additions:

```bash
nano env/.env
```

| Variable | Action |
|----------|--------|
| `ENTITLEMENT_POSTGRES_USER` | New — e.g. `entitlement` |
| `ENTITLEMENT_POSTGRES_PASSWORD` | New — strong secret from secret store |
| `ENTITLEMENT_POSTGRES_DB` | New — e.g. `entitlement` |
| `ENTITLEMENT_TAG` | New — match `RELAY_TAG` (e.g. `vX.Y.Z`) |
| `ENTITLEMENT_INTERNAL_TOKEN` | New — random string; **same value** used by relay and entitlement |
| `ENTITLEMENT_ENABLED` | New — see rollout note below |
| `ENTITLEMENT_INTROSPECT_URL` | New — `http://entitlement:8080` (Docker service name) |
| `TRIAL_DURATION` | New — default `336h` (14 days) |
| `GRACE_DURATION` | New — default `168h` (7 days) |
| `RELAY_TAG`, `BUILD_DIGEST` | Update to the new release |

**Rollout recommendation:** set `ENTITLEMENT_ENABLED=false` for the
first deploy so the relay behaviour stays unchanged while you verify
entitlement health. Set `ENTITLEMENT_ENABLED=true` in a second deploy
once smoke tests pass (or when the mobile client sends `entitlement_gate`).

Generate an internal token (example):

```bash
openssl rand -base64 32
```

Paste the same value into `ENTITLEMENT_INTERNAL_TOKEN` once.

### 4. Stop the relay-only stack (preserve volumes)

Still as `compartarenta-relay`:

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/relay/compose.yml down
```

**Do not** pass `-v`. The relay `pgdata` volume must survive.

### 5. Build the full stack

```bash
docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  build
```

This builds **both** images. Each build stage runs `govulncheck ./...`.

### 6. Start the full stack

```bash
docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  up -d
```

Check containers:

```bash
docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml ps
```

Expected: `compartarenta-relay`, `compartarenta-relay-db`,
`compartarenta-entitlement`, `compartarenta-entitlement-db` — all running.

### 7. Smoke tests (on the VPS)

```bash
# Relay (unchanged public path via Apache — or loopback if testing locally)
curl -s http://127.0.0.1:8080/healthz | jq .

# Entitlement (loopback only)
curl -s http://127.0.0.1:8081/healthz | jq .
curl -s http://127.0.0.1:8081/readyz | jq .

# Entitlement API (no Apache exposure)
curl -s -X POST http://127.0.0.1:8081/v1/installations/register \
  -H 'Content-Type: application/json' \
  -d '{"participant_installation_id":"smoke-test-install-001"}'
```

From the public internet (relay only):

```bash
curl -s https://sync.YOUR-DOMAIN.TLD/healthz | jq .
```

Entitlement URLs must **not** be reachable from the public internet.

### 8. Enable gating (second step, when ready)

```bash
nano env/.env    # ENTITLEMENT_ENABLED=true

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  up -d relay
```

Only the relay container needs recreation for this env change; entitlement
keeps running.

### 9. Audit

Record the deployment in [`relay-audit-log.md`](./relay-audit-log.md).
Run [`relay-audit-checklist.md`](./relay-audit-checklist.md) (entitlement
checklist extensions are a follow-up; document entitlement container
digests alongside relay).

Image digests:

```bash
docker inspect compartarenta-relay:${RELAY_TAG} --format '{{.Id}}'
docker inspect compartarenta-entitlement:${ENTITLEMENT_TAG} --format '{{.Id}}'
```

---

## Upgrading an already-combined stack

When relay **and** entitlement already run from
`compose.production-stack.yml`:

### On your workstation

1. Push all code to git.
2. Create a version tag and push it.
3. Note `git rev-parse HEAD` for `BUILD_DIGEST`.

### On the VPS

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay

git -C source pull --ff-only

nano env/.env
# Update RELAY_TAG, ENTITLEMENT_TAG, BUILD_DIGEST (and ENTITLEMENT_BUILD_DIGEST if set)

date -u +"%Y-%m-%dT%H:%MZ"

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml build

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml up -d

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml ps
```

Rollback: pin the previous digests in `env/.env`, rebuild, `up -d`.
Relay routing data survives in `pgdata`; entitlement data survives in
`entitlement-pgdata`.

---

## Day-to-day operations

Always as `compartarenta-relay`:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay

COMPOSE="docker compose --env-file env/.env -f source/deploy/compose.production-stack.yml"

# Follow logs
$COMPOSE logs --tail 100 -f relay
$COMPOSE logs --tail 100 -f entitlement

# Status
$COMPOSE ps

# Restart one service
$COMPOSE restart relay
$COMPOSE restart entitlement

# Entitlement schema tables (audit)
$COMPOSE exec entitlement-postgres \
  psql -U "$ENTITLEMENT_POSTGRES_USER" -d "$ENTITLEMENT_POSTGRES_DB" -c "\dt+"

# Relay schema tables (unchanged)
$COMPOSE exec postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt+"
```

SSH tunnel for entitlement API from your workstation:

```bash
ssh -L 8081:127.0.0.1:8081 <admin>@<vps>
curl -s http://127.0.0.1:8081/healthz | jq .
```

---

## Daily statistics cron (containerized VPS)

The relay serves daily push-dispatch aggregates on an **in-container**
loopback listener (`STATS_LISTEN_ADDR`, default `127.0.0.1:9091`). Port
9091 is **not** mapped to the host. A host cron job that runs
`daily-stats-append.sh` (plain `curl` to `127.0.0.1:9091`) will fail
with `curl: (7) Failed to connect`.

**Use the Docker wrapper** documented in
[`relay-deployment.md`](./relay-deployment.md) (section "Daily
closed-app push statistics"):

| Script | When |
|--------|------|
| `source/relay/scripts/daily-stats-append-via-docker.sh` | **VPS production** (relay in Docker) |
| `source/relay/scripts/daily-stats-append.sh` | Relay on host loopback only (not this stack) |

Recommended crontab (`compartarenta-relay` user, 00:07 UTC):

```cron
CRON_TZ=UTC
7 0 * * * /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh >> /srv/compartarenta-stats/cron.log 2>&1
```

After deploy or cron change, run the script once manually and confirm
`tail -1 /srv/compartarenta-stats/daily.jsonl` shows a new `date` line.
`STATS_FILE_PATH` in `env/.env` is for operator documentation; the
cron script reads `STATS_FILE_PATH` from the environment if set in
crontab, or uses the default `/srv/compartarenta-stats/daily.jsonl`.

---

## Required environment variables (combined)

Loaded from `/srv/compartarenta-relay/env/.env`.

### Relay database (unchanged)

| Variable | Purpose |
|----------|---------|
| `POSTGRES_USER` | Relay DB user |
| `POSTGRES_PASSWORD` | Relay DB password |
| `POSTGRES_DB` | Relay DB name |

### Entitlement database (new, separate)

| Variable | Purpose |
|----------|---------|
| `ENTITLEMENT_POSTGRES_USER` | Entitlement DB user |
| `ENTITLEMENT_POSTGRES_PASSWORD` | Entitlement DB password |
| `ENTITLEMENT_POSTGRES_DB` | Entitlement DB name |

### Images

| Variable | Purpose |
|----------|---------|
| `RELAY_TAG` | Relay image tag |
| `ENTITLEMENT_TAG` | Entitlement image tag |
| `BUILD_DIGEST` | Baked into relay binary `/healthz` |
| `ENTITLEMENT_BUILD_DIGEST` | Optional; defaults to `BUILD_DIGEST` |

### Entitlement integration

| Variable | Purpose |
|----------|---------|
| `ENTITLEMENT_ENABLED` | `true` — relay enforces gating on kinds 5–9 |
| `ENTITLEMENT_INTROSPECT_URL` | `http://entitlement:8080` on Docker network |
| `ENTITLEMENT_INTERNAL_TOKEN` | Shared Bearer secret (recommended in production) |
| `TRIAL_DURATION` | Housing trial length (default `336h`) |
| `GRACE_DURATION` | Delinquency grace (default `168h`) |

All other relay variables (`ENVELOPE_MAX_BYTES`, `CORS_ALLOWED_ORIGINS`,
push wake, reminder cron, etc.) behave as documented in
[`relay-deployment.md`](./relay-deployment.md) and
[`relay/.env.example`](../relay/.env.example).

---

## Public license sub-domain (client HTTP API)

Operators may expose the entitlement **client** API on a dedicated sub-domain
(for example `license.incoherences.org`) that proxies to `127.0.0.1:8081`.
Reference vhost: [`entitlement/deploy/apache2/license-vhost.conf.template`](../entitlement/deploy/apache2/license-vhost.conf.template).

| Path | Public? |
|------|---------|
| `/v1/installations/register`, `/v1/housing/*`, `/healthz`, `/readyz` | Yes (via vhost) |
| `/v1/introspect/envelope` | **No** — relay only on Docker network |

**Flutter web dev** (`run:dev:web` at `http://localhost:5001`) needs CORS on
that vhost. The template includes a **dev-only** allow-list for that origin.
Remove or replace it before shipping a production browser build (see
`openspec/changes/repo-maintenance-backlog/tasks.md`).

Changing dev CORS on the VPS touches **only the license Apache vhost** — not the
entitlement container image, relay binary, or stack `.env` (unless you add a
new public hostname for the first time).

---

## What stays on the relay sub-domain

Apache on the **sync** sub-domain continues to proxy **only** the relay.
Entitlement introspection from the relay container uses
`ENTITLEMENT_INTROSPECT_URL` on the private Docker network, not the public
license vhost.

---

## Compose manifest choice

| Manifest | When to use |
|----------|-------------|
| `source/deploy/compose.production-stack.yml` | **VPS production** — relay + entitlement |
| `source/relay/compose.yml` | Legacy relay-only (migrate away) |
| `deploy/compose.dev-stack.yml` | Local workstation dev (repo root) |

After the first stack deploy, always use
`source/deploy/compose.production-stack.yml` on the VPS.
