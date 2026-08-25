# Bojairũ Relay — Deployment Runbook

> **Relay + entitlement on the same VPS:** use
> [`stack-deployment.md`](./stack-deployment.md) for pull, `.env`, build,
> and upgrade of the combined stack (`deploy/compose.production-stack.yml`).
> This document remains the reference for Apache, TLS, host preparation,
> and relay-only operational details.

This runbook describes how to deploy the Bojairũ relay on an
existing Ubuntu VPS that **already hosts other services**, under a
dedicated sub-domain, with Apache as the reverse proxy in front of the
containerized Go binary and a containerized PostgreSQL behind it. It is
the operational counterpart to the spec at
`openspec/changes/relay-server-infrastructure-and-audit/`. Auditors
should cross-reference this document with
[`relay-audit-checklist.md`](./relay-audit-checklist.md).

Host paths, deploy users, and container names such as `/srv/compartarenta-relay`
and `compartarenta-relay` remain the technical identifiers used on the VPS;
they are not renamed in this batch.

## At a glance

| Item                           | Where                                                      |
|--------------------------------|------------------------------------------------------------|
| Relay source                   | [`relay/`](../relay)                                       |
| Migrations (canonical)         | [`relay/internal/store/schema/`](../relay/internal/store/schema) |
| Container manifest             | [`relay/compose.yml`](../relay/compose.yml) (relay-only) or [`deploy/compose.production-stack.yml`](../deploy/compose.production-stack.yml) (relay + entitlement) |
| Environment template           | [`relay/.env.example`](../relay/.env.example) or [`deploy/env.stack.example`](../deploy/env.stack.example) |
| Apache vhost template          | [`relay/deploy/apache2/relay-vhost.conf.template`](../relay/deploy/apache2/relay-vhost.conf.template) |
| Audit checklist                | [`relay-audit-checklist.md`](./relay-audit-checklist.md)   |
| Relay state schema (summary)   | [`relay-state-schema.md`](./relay-state-schema.md)         |
| Audit log                      | [`relay-audit-log.md`](./relay-audit-log.md)               |
| Topology spec                  | `openspec/changes/relay-server-infrastructure-and-audit/specs/relay-deployment-topology/spec.md` |

## Topology

```
                 public internet
                       │
                       │ HTTPS / 443  (also 80 -> redirect)
                       ▼
              ┌──────────────────────────┐
              │  Apache 2 (host)         │  ← TLS for the dedicated
              │  vhost: relay sub-domain │    relay sub-domain only
              │  + static invite HTML    │  ← /contact/invite/ only
              │    (no index at /)       │  ← proxies /v1/, /healthz,
              │                          │    /readyz to the relay
              └────────────┬─────────────┘
                           │ HTTP / 8080  (loopback only, no TLS)
                           ▼
              ┌──────────────────────┐
              │   relay container    │   non-root (UID 65532),
              │   FROM scratch       │   read-only rootfs,
              │   /v1/envelopes      │   cap_drop: ALL,
              │   /v1/inbox/:id      │   no-new-privileges:true
              │   /v1/handshake/...  │
              │   /v1/disconnect     │
              │   /healthz /readyz   │
              │   /metrics  ← 9090   │  ← private listener,
              │                      │    loopback only
              └────────────┬─────────┘
                           │ tcp / 5432  (Docker private net)
                           ▼
              ┌──────────────────────┐
              │  postgres container  │   no published port
              │  pgdata named volume │   isolated network
              └──────────────────────┘
```

## Ports summary

The relay does NOT require any new public port on a VPS that already
runs other websites. Apache's 80/443 listeners are shared; everything
else is bound to loopback or stays inside the Docker network.

| Port  | Side                  | Visibility                              | Used by                                  |
|-------|-----------------------|------------------------------------------|------------------------------------------|
| 80    | host                  | public (existing Apache)                 | redirect to HTTPS on the relay sub-domain|
| 443   | host                  | public (existing Apache)                 | TLS + landing page + reverse proxy       |
| 22    | host                  | restricted (operator allow-list)         | SSH for administration                   |
| 8080  | host                  | `127.0.0.1` only (bound by compose)      | Apache → relay binary                    |
| 9090  | host                  | `127.0.0.1` only (bound by compose)      | metrics (SSH-tunnel reachable only)      |
| 5432  | inside Docker network | not bound to host at all                 | relay ↔ postgres                         |

Conclusion for UFW / host firewall: **no new rule needed for the
relay**. The existing rules that already allow 80/443/22 for the other
services on the VPS cover everything. A defensive `deny 5432/tcp` is
optional — Docker is not publishing that port in the first place, so
the audit checklist's A.5 probe is satisfied by construction.

## Host preparation

### Required system packages

Most are already on a standard Ubuntu 24.04 host that runs Apache. The
new ones in this list are `postgresql-client`, `jq`, and `fail2ban`.

```bash
sudo apt update
sudo apt install -y \
    apache2 \
    certbot python3-certbot-apache \
    postgresql-client \
    jq \
    fail2ban
sudo a2enmod proxy proxy_http ssl headers rewrite http2
```

The host does **not** need Go installed. The relay's `Dockerfile` uses
a `golang:1.26-alpine` builder stage to compile the binary inside the
container; the runtime image is `FROM scratch`. The host also does not
need anything Node-related — the relay is a single Go process.

### Dedicated Linux user

The deployment lives under a dedicated system user with exclusive
filesystem access. The username is **`compartarenta-relay`** and is
recorded here on purpose — its presence in the public repository is a
deliberate operational choice, mitigated by `fail2ban` for SSH and by
the user account being password-locked (login is only via
`sudo -u compartarenta-relay -s` from an authorized admin user).

```bash
sudo useradd --system --create-home \
             --home-dir /srv/compartarenta-relay \
             --shell /bin/bash \
             --comment "Compartarenta relay deploy account" \
             compartarenta-relay

# Password-locked. No SSH password login is possible for this account.
sudo passwd -l compartarenta-relay

# Exclusive ownership.
sudo chown -R compartarenta-relay:compartarenta-relay /srv/compartarenta-relay

# 0700 = owner rwx, group ---, others ---. Only compartarenta-relay
# (and root, which has no fs permissions limits) can read or traverse.
sudo chmod 0700 /srv/compartarenta-relay
```

Verify:

```bash
sudo namei -l /srv/compartarenta-relay
sudo ls -lan /srv/compartarenta-relay
```

### Docker group membership

To let `compartarenta-relay` run `docker compose` without `sudo`,
add it to the `docker` group:

```bash
sudo usermod -aG docker compartarenta-relay
```

**Security trade-off, recorded here for the audit posture:** members
of the `docker` group have effective root on the host (they can mount
any host path into a container as root). This is acceptable here
because the same account already owns the relay's secrets and the
deployment directory — the trust boundary is identical. Therefore:

- `compartarenta-relay` MUST NOT be used for unrelated host tasks.
- No SSH keys are authorized on this account directly; access is via
  `sudo -u compartarenta-relay -s` from a separately-authenticated
  admin user.

An alternative that avoids the `docker` group is to drive
`docker compose` from a `systemd` unit that runs as root, with a narrow
`sudoers` rule that lets `compartarenta-relay` issue only
`systemctl start/stop/restart compartarenta-relay`. Slightly more
ceremony for a marginal isolation gain in this context.

### Deployment directory layout

```
/srv/compartarenta-relay/                     compartarenta-relay:compartarenta-relay, 0700
├── source/                                   git clone of this repository
│   └── …/relay/
│       ├── compose.yml
│       ├── Dockerfile
│       └── internal/store/schema/0001_init.sql
├── env/                                      compartarenta-relay:compartarenta-relay, 0700
│   └── .env                                  compartarenta-relay:compartarenta-relay, 0600
└── audit/                                    compartarenta-relay:compartarenta-relay, 0700
    └── (local audit artefacts: schema dumps, log samples, etc.)
```

Set it up:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay

git clone https://github.com/<owner>/Compartarenta.git source
mkdir -p env audit
chmod 0700 env audit

cp source/relay/.env.example env/.env
chmod 0600 env/.env
# Edit env/.env: fill in real values from the secret store.
# Never commit env/.env.
```

### fail2ban for SSH

`compartarenta-relay` is password-locked and SSH-key-less, so the
username is not a direct attack target. But the VPS hosts other
services and the relay's existence is publicly documented (CT logs +
this repo), so the standard `fail2ban` SSH jail is recommended for
defense in depth.

```bash
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

The default `sshd` jail on Ubuntu 24.04 is sufficient. Tune
`bantime` / `findtime` / `maxretry` per the operator's preference;
record any deviation from defaults in `docs/relay-audit-log.md`.

## Reverse proxy: Apache vhost + static invite page

### Sub-domain name is a placeholder

The literal string `relay` used throughout this document, in the
Apache vhost template
([`relay/deploy/apache2/relay-vhost.conf.template`](../relay/deploy/apache2/relay-vhost.conf.template)),
and in the audit checklist examples is a **placeholder, not a
requirement**. The spec
(`relay-deployment-topology` / "The relay is exposed on a dedicated
sub-domain") writes the example as `relay.<example.tld>` with an
explicit `e.g.,`; no particular word is mandated.

Pick any sub-domain name that fits your product branding —
`sync.<your-domain>`, `api.<your-domain>`, `m.<your-domain>`,
`<brand>-sync.<your-domain>`, `connect.<your-domain>`, etc. Nothing in
the Go binary, the Docker manifests, the compose project name, or the
on-disk schema depends on the literal word `relay`.

What the spec **does** require, regardless of the name you pick:

1. It SHALL be a **dedicated sub-domain** (not a path under an
   existing domain such as `<your-domain>/api/`). The constraint is
   per `relay-deployment-topology` / "The relay is exposed on a
   dedicated sub-domain".
2. It SHALL have **its own TLS certificate**. No wildcard cert reuse
   with unrelated services on the same VPS, per
   `relay-deployment-topology` / "TLS material is not shared with
   unrelated services".
3. It SHALL serve **only** the relay's documented public surface: the
   protocol endpoints under `/v1/*`, the health endpoints, and the
   static invitation page at `/contact/invite/`. There is **no**
   marketing homepage at `/` (expect HTTP 403 or 404). No other
   application is reachable via the same sub-domain.

Whatever name you pick, replace every occurrence of
`relay.example.tld` in your local copy of the Apache vhost template
and in the deployments / audits sections of
[`relay-audit-log.md`](./relay-audit-log.md) with the real value at
deployment time. Once chosen, the name is recorded in the first
"Deployments" row of `relay-audit-log.md`.

> If you have not yet locked your product brand, picking a
> brand-neutral name (`sync`, `api`, `m`) lets you defer the decision
> without ever having to rename the sub-domain afterwards. Renaming a
> sub-domain later is technically cheap (DNS + a fresh ACME cert) but
> it does churn the audit log.

### Reverse proxy role

Apache:

- terminates TLS for the sub-domain with its own ACME-issued
  certificate (no wildcard reuse with unrelated sites on this VPS, per
  `relay-deployment-topology` / "TLS material is not shared with
  unrelated services"),
- serves the **static invitation page** at `/contact/invite/` (see
  notes below); `/` has no `index.html` (HTTP 403 with `-Indexes`),
- reverse-proxies `/v1/*`, `/healthz`, `/readyz` to the relay binary
  on `127.0.0.1:8080`,
- blocks `/metrics`, `/admin`, `/debug`, `/pprof` at the proxy as
  defense in depth (the relay's public listener doesn't serve them in
  the first place; metrics are on the private listener only).

### Reference vhost

The canonical vhost template lives in this repository at
[`relay/deploy/apache2/relay-vhost.conf.template`](../relay/deploy/apache2/relay-vhost.conf.template).
The audit checklist's F.1 item verifies its presence; F.2 expects no
drift between the deployed vhost and this template.

Adapt the template (replace `relay.example.tld` and the
`DocumentRoot` path), drop it into `/etc/apache2/sites-available/`:

```bash
sudo cp /srv/compartarenta-relay/source/relay/deploy/apache2/relay-vhost.conf.template \
        /etc/apache2/sites-available/relay.example.tld.conf
sudo sed -i 's/relay\.example\.tld/relay.YOUR-DOMAIN.TLD/g' \
        /etc/apache2/sites-available/relay.example.tld.conf
sudo a2ensite relay.example.tld.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### TLS issuance with certbot

```bash
sudo certbot --apache -d relay.YOUR-DOMAIN.TLD
```

`certbot --apache` rewrites the vhost to point at the issued
certificate and installs a `systemd` timer for automatic renewal. The
relay sub-domain MUST get its own certificate; do NOT use a wildcard
that also covers unrelated services on the host.

Monitoring of renewal failures (the spec requires alerting before
expiry) is operator-side; recommended pattern: a Prometheus alert on
`probe_ssl_earliest_cert_expiry` from blackbox_exporter, or a cron
that emails the operator when `certbot certificates` reports a date
less than 14 days away.

### Static invitation page

The HTML at `/contact/invite/` is **part of the relay's public
surface** (deep-link landing for a connection invitation). There is
**no** marketing homepage at `/`. The spec line "The sub-domain SHALL
serve only the relay" is preserved: this page belongs to the same
application as the protocol endpoints; it does not host an unrelated
service.

Constraints on that page (verified by audit §2.1 / HOW-TO A.2.1.6–A.2.1.7):

- Hand-authored static HTML + assets. No server-side language.
- No embedded telemetry, analytics, or scripts that call the relay's
  `/v1/...` endpoints.
- No operational state on the page (no envelope IDs, no metrics
  values, no schema version, no build hash).
- Product name **Bojairũ** and scheme `bojairu://` only (no legacy
  Compartarenta names or schemes).

Place it at `/var/www/compartarenta-relay-landing/contact/invite/`
(DocumentRoot remains the parent directory so `/` has no index and
returns 403). The reference copy lives in
[`relay/deploy/landing/contact/invite/`](../relay/deploy/landing/contact/invite/).

## Required environment

Loaded from `/srv/compartarenta-relay/env/.env` at deploy time.

| Variable                 | Purpose                                                  | Source                         |
|--------------------------|----------------------------------------------------------|--------------------------------|
| `DATABASE_URL`           | libpq DSN for postgres                                   | secret store                   |
| `POSTGRES_USER`          | Database user                                            | secret store                   |
| `POSTGRES_PASSWORD`      | Database password                                        | secret store                   |
| `POSTGRES_DB`            | Database name                                            | secret store                   |
| `RELAY_TAG`              | Container image tag, matches the deployed digest         | repo (release notes)           |
| `BUILD_DIGEST`           | Built into the binary; surfaced via `/healthz`           | CI build                       |
| `PUBLIC_LISTEN_ADDR`     | bind address for the relay protocol + health             | manifest (default `0.0.0.0:8080`) |
| `PRIVATE_LISTEN_ADDR`    | bind address for `/metrics`                              | manifest (default `127.0.0.1:9090`) |
| `ENVELOPE_MAX_BYTES`     | ciphertext cap per envelope                              | manifest (recommended `262144` / 256 KiB) |
| `ENVELOPE_TTL_MIN/MAX`   | `MAX` is the 7-day cap (and default) when `expires_at` is omitted. Dated envelopes use plaintext `expires_at` and are not raised to `MIN`. | manifest |
| `IDEMPOTENCY_TTL`        | idempotency entry lifetime                               | manifest                       |
| `DISCONNECT_GRACE`       | grace window on disconnecting routing rows               | manifest                       |
| `ROUTING_INACTIVITY_TTL` | long-inactivity TTL for routing rows                     | manifest                       |
| `SWEEPER_INTERVAL`       | cadence at which TTL deletions run                       | manifest                       |
| `RATE_LIMIT_PER_IDENTITY`| token-bucket rate per opaque identity (tokens/sec)       | manifest                       |
| `RATE_LIMIT_PER_IP`      | token-bucket rate per source IP (tokens/sec)             | manifest                       |
| `SHUTDOWN_TIMEOUT`       | drain window on SIGTERM                                  | manifest                       |

The relay's `config.Load` refuses to start without `DATABASE_URL`. It
also enforces ceiling bounds on `ENVELOPE_TTL_MAX` (~30 days) and
`IDEMPOTENCY_TTL` (~7 days). Wider values trip an explicit error.

The reference deployment manifest sets `ENVELOPE_MAX_BYTES=262144`
(256 KiB). This is an operator-side configuration choice, not a Go-code
default change: the binary still defaults to 64 KiB when the env var is
omitted, but the documented deployment raises the cap so a single
compressed proof image can fit in a ciphertext envelope.

## Deploying the first time

1. **DNS.** Create `A` (and `AAAA` if applicable) records for
   `relay.<your-domain>` pointing to the VPS public IP.
2. **Host preparation.** Run the package install, create the
   `compartarenta-relay` user, lay out `/srv/compartarenta-relay/` per
   the "Host preparation" section above.
3. **Apache vhost.** Copy and adapt the template, `a2ensite`,
   `apache2ctl configtest`, then `certbot --apache`. Reload Apache.
4. **Secrets.** Populate `env/.env` from the secret store
   (`compartarenta-relay` user, mode 0600).
5. **Build the image with a real digest.** From
   `/srv/compartarenta-relay`:

   ```bash
   docker compose --env-file env/.env \
                  -f source/relay/compose.yml \
                  build
   ```

   The build stage runs `govulncheck ./...` and aborts on critical CVEs.
6. **Start the stack:**

   ```bash
   docker compose --env-file env/.env \
                  -f source/relay/compose.yml \
                  up -d
   ```

   The relay applies migrations on startup and refuses to start when the
   schema version doesn't match the binary's expected version.
7. **Probe.** From the public side:

   ```bash
   curl https://relay.YOUR-DOMAIN.TLD/healthz
   curl -I https://relay.YOUR-DOMAIN.TLD/                # 200, landing page
   curl -I https://relay.YOUR-DOMAIN.TLD/metrics         # 403 or 404
   ```

   Through an SSH tunnel from a privileged workstation:

   ```bash
   ssh -L 9090:127.0.0.1:9090 <admin>@<vps>
   curl http://127.0.0.1:9090/metrics | head
   ```

8. **Tag + audit.** Tag the release in the repository, append the
   `(tag, digest, deployment date)` row to `docs/relay-audit-log.md`,
   run the full `docs/relay-audit-checklist.md` against the live
   instance, and record the baseline self-audit entry **before**
   advertising the sub-domain to clients.

## Upgrading

1. Make sure to push all your code to git.

2. Create a version tag and push it.

3. Get the tag SHA using `git rev-parse HEAD`

On the VPS:

4. Impersonnate the app user
	`sudo -u compartarenta-relay -s`
5. Pull the repos.
	```
	cd /srv/compartarenta-relay
	git -C source pull --ff-only
	```
6. Replace the commit SHA with the new one (obtained in step 3)
	`nano env/.env`

7. Get the build date (keep it safe, needed for the audit log)
  ```
  date -u +"%Y-%m-%dT%H:%MZ"
  ```
8. Build and run Docker
	```
	docker compose --env-file env/.env -f source/relay/compose.yml build
	docker compose --env-file env/.env -f source/relay/compose.yml up -d
	```
9. Get the Docker SHA
	`docker inspect compartarenta-relay:v0.1.0 --format '{{.Id}}'`

10. Exit impersonation of the app's user
	`exit`

11. From local files, open `docs/relay-audit-log.md`

12. Tag this new release in the `Deployments` section.

13. Follow `relay-audit-checklist.md` steps, then file the `Baseline` section.

Rollback: pin the previous digest in `env/.env` and re-run step 3. The
routing relationships and in-flight envelopes survive rollbacks because
they live in the `pgdata` named volume.

## Day-to-day operations

Always as the deploy user:

```bash
sudo -u compartarenta-relay -s
cd /srv/compartarenta-relay

# Logs (last 100 lines, follow).
docker compose --env-file env/.env -f source/relay/compose.yml \
  logs --tail 100 -f relay

# Status.
docker compose --env-file env/.env -f source/relay/compose.yml ps

# Schema dump for audit item C.1.
docker compose --env-file env/.env -f source/relay/compose.yml \
  exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt+"

# Restart the relay container only (postgres keeps running).
docker compose --env-file env/.env -f source/relay/compose.yml \
  restart relay
```

## Patch cadence

| Surface                 | Cadence                              | Critical CVE window         |
|-------------------------|--------------------------------------|-----------------------------|
| Host OS (Ubuntu 24.04)  | monthly review                       | 72 hours after disclosure   |
| Apache 2 + Certbot      | monthly review                       | 72 hours after disclosure   |
| fail2ban                | monthly review                       | as part of host OS          |
| Docker engine           | monthly review                       | 72 hours after disclosure   |
| Postgres image          | monthly review                       | 72 hours after disclosure   |
| Relay image deps        | weekly `govulncheck` in CI           | next image build            |

`govulncheck ./...` runs inside the Docker build stage and fails the
build on known-critical CVEs. Re-running `go mod tidy` plus rebuilding
brings in the fix.

## Alerts

Configure on the operator's monitoring stack:

| Signal                                       | Threshold                                  |
|----------------------------------------------|--------------------------------------------|
| `relay_sweeper_runs_total` rate              | should be > 0 over the last 5 minutes      |
| `relay_envelopes_queue_depth`                | alert when > N for M minutes (operator-chosen) |
| `relay_envelopes_oldest_undelivered_age_seconds` | alert when > envelope TTL minimum      |
| `relay_http_requests_total{status_class="5xx"}` rate | alert when > 1% of total over 5 minutes |
| `relay_ratelimit_rejections_total` rate      | alert on sustained spikes (abuse signal)   |
| TLS certificate expiry                       | alert > 14 days before expiry              |
| fail2ban jail size                           | alert on unusual spikes (brute-force burst)|

Recipients are role-keyed ("operator on-call"), not personal-data
level, per `relay-observability-without-plaintext` / "Alerting
thresholds are documented".

## What this relay never does

Repeated for emphasis (the audit checklist tests each item):

- It does NOT decrypt envelopes.
- It does NOT store display names, avatars, expense amounts, contact
  metadata, or any user-facing content.
- It does NOT log envelope ciphertext, recipient mapping payloads, or
  contact metadata.
- It does NOT keep delivered envelopes past the per-recipient ack.
- It does NOT keep undelivered envelopes past `ttl_expires_at`.
- It does NOT publish a metrics or admin endpoint to the public
  internet.
- It does NOT share TLS material with services unrelated to the relay.
- It does NOT host any unrelated workload in its containers.
- It does NOT use the dedicated Linux account for unrelated host tasks.

Each of these statements is verifiable from this repository alone.

## Operator-side items the repository cannot perform

Tasks 3.1 and 3.2 of
`openspec/changes/relay-server-infrastructure-and-audit/tasks.md`
(reserving the sub-domain and provisioning ACME certs) need DNS access
and domain control. They are operator runbook items by nature. The
same applies to tasks 7.6 (audit-checklist dry-run on a live
deployment) and 6.3/6.4 (first tagged release + baseline audit entry).
Mark them done in `tasks.md` once they're completed against the live
deployment.

## Closed-app wake push (FCM / Android)

Android clients register FCM tokens with the relay. Wake dispatch uses
Firebase Cloud Messaging HTTP v1. The **service account JSON must belong
to the same Firebase project as the mobile apps** (currently **`bojairu`**).

| Variable | Role |
|----------|------|
| `WAKE_PUSH_DISPATCH_ENABLED` | Master switch (default `false`). When false, tokens are stored but no FCM call is made. |
| `FCM_SERVICE_ACCOUNT_JSON_PATH` | Path **inside the relay container** to the Firebase service account JSON. The relay reads `project_id` from that file. |
| `ROUTING_PUSH_TOKEN_TTL_SECONDS` | Token lifetime on refresh (default 14 days). |

Mount the JSON into the container (compose volume or copy into the image
layer is **not** recommended — prefer a host bind under
`/srv/compartarenta-relay/…` with mode `0600`, owned by the deploy user).
Set `FCM_SERVICE_ACCOUNT_JSON_PATH` in the stack `.env`, then restart the
relay. See [`relay/.env.example`](../relay/.env.example) and
[`relay-state-schema.md`](./relay-state-schema.md).

**Ops checklist (Phase A cut):** place the `bojairu` service account on the
VPS → point `FCM_SERVICE_ACCOUNT_JSON_PATH` → set
`WAKE_PUSH_DISPATCH_ENABLED=true` when ready → restart relay → smoke an
Android wake (e.g. `qa:run-fcm-wake-push`).

APNs variables are documented in `.env.example` but iOS push QA remains
deferred.

## Daily closed-app push statistics (loopback)

See also [`relay-state-schema.md`](./relay-state-schema.md) for the
`routing_push_tokens` table, TTL, and wake payload contract.

The relay binary exposes a **second HTTP listener** for operator-only
daily aggregates: `STATS_LISTEN_ADDR` (default `127.0.0.1:9091` inside
the container, or `-` to disable). Only **in-container loopback** clients
receive `GET /internal/stats/daily?date=YYYY-MM-DD`; other remote
addresses get HTTP 404.

Port **9091 is not published** to the VPS host in
[`relay/compose.yml`](../relay/compose.yml) or
[`deploy/compose.production-stack.yml`](../deploy/compose.production-stack.yml).
The stats listener binds inside the relay container only.

### Containerized VPS (production) — use the Docker wrapper

When the relay runs in Docker (this deployment), **do not** cron
[`relay/scripts/daily-stats-append.sh`](../relay/scripts/daily-stats-append.sh)
from the host. A host-side `curl http://127.0.0.1:9091/...` fails with
`Failed to connect` because nothing listens on the host's loopback at
9091, and even a published port would not satisfy the relay's loopback
check.

Use
[`relay/scripts/daily-stats-append-via-docker.sh`](../relay/scripts/daily-stats-append-via-docker.sh)
instead. It runs a minimal `curl` container in the relay container's
network namespace (`docker run --network container:compartarenta-relay`).

Example crontab for user `compartarenta-relay` (00:07 UTC daily):

```cron
CRON_TZ=UTC
7 0 * * * /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh >> /srv/compartarenta-stats/cron.log 2>&1
```

Manual smoke test (after deploy):

```bash
sudo -u compartarenta-relay -s
/srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh
tail -1 /srv/compartarenta-stats/daily.jsonl
```

Ensure the script is executable:

```bash
chmod +x /srv/compartarenta-relay/source/relay/scripts/daily-stats-append-via-docker.sh
```

Environment variables: `COMPARTARENTA_RELAY_CONTAINER` (default
`compartarenta-relay`), `STATS_FILE_PATH` (default
`/srv/compartarenta-stats/daily.jsonl`). See
[`relay/scripts/README-daily-stats.md`](../relay/scripts/README-daily-stats.md).

### Bare-metal / relay on host loopback (uncommon)

If the relay process runs **directly on the host** (not in Docker), cron
[`daily-stats-append.sh`](../relay/scripts/daily-stats-append.sh) with
`RELAY_STATS_URL=http://127.0.0.1:9091/internal/stats/daily`.

## Scheduled notifications (housing payment reminders)

See [`relay-deployment-scheduled-notifications.md`](./relay-deployment-scheduled-notifications.md)
for `REMINDER_CRON_ENABLED`, scheduling HTTP endpoints, and operator verification
steps for migration `0003_scheduled_notifications.sql`.

## Operator notice (optional FCM; Android only)

Not part of every deploy. After a relay image that includes the
`operator-notice` subcommand is running, the operator may notify every
device that still has a **non-expired FCM token**.

This is **not** an inbox wake (`wake_for_inbox`). It is a separate
data-only `kind=operator_notice` (Message manuel). Long copy stays on
the locale pages `https://bojairu.app/fr/message`,
`https://bojairu.app/en/message`, and `https://bojairu.app/es/mensaje`;
the FCM payload carries only `v`, `kind`, optional `target_build`, and
`consult_site`.

- **Who:** Linux user `compartarenta-relay` on the VPS. Do **not** use
  `sudo -u compartarenta-relay` if the shell is already that user.
- **Where:** second process inside the running `relay` container
  (`FROM scratch` — no shell). `docker compose exec` runs `/relay …`.
- **Not:** a public HTTP API, an entitlement endpoint, or an in-app
  button. APNs is not used.
- **Send flag:** `--confirm`. Default (and `--dry-run`) only prints how
  many distinct FCM tokens would be notified.
- **FCM JSON:** `FCM_SERVICE_ACCOUNT_JSON_PATH` must be set to send.
  `WAKE_PUSH_DISPATCH_ENABLED` is **not** required for this command.

At least one of `--target-build` or `--consult-site` is required.

### Before `--confirm` (Play update)

`--confirm` sends for real (every distinct non-expired FCM token). It is
not a rehearsal. Dry-run already counts tokens.

When the notice includes `--target-build=N` (so the in-app page can show
the Play update badge):

1. **Production must already have that AAB.** The badge opens the public
   listing `https://play.google.com/store/apps/details?id=app.incoherences.bojairu`,
   not an Internal testing track. Do not `--confirm` with `N` until
   Google Play Console → **Production** has `versionCode` **N** (published
   or processing onto that listing). Announcing a number that is only on
   Internal testing, or not on Play yet, shows a badge that cannot install
   that package.
2. **`N` must be strictly greater than the installed build** on devices
   that should see the badge. The app shows the Play block only when
   `installed < N`. Confirming with the `versionCode` those phones already
   have (for example targeting 40 while those devices already run 40) still
   delivers the notification, but hides the badge. `--consult-site` can
   still show **Read the message**.
3. **Dry-run first with the same flags** as the send (same `N`, same
   `--consult-site`), then `--confirm`.

`--consult-site` without `--target-build` has no Play badge; steps 1–2
do not apply.

Dry-run (replace `39` with the Play `versionCode` you mean, or omit
`--target-build` and keep `--consult-site`):

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  -f docker-compose.secrets.yml \
  exec -T relay /relay operator-notice --consult-site --target-build=39 --dry-run
```

Send the same notice:

```bash
cd /srv/compartarenta-relay

docker compose --env-file env/.env \
  -f source/deploy/compose.production-stack.yml \
  -f docker-compose.secrets.yml \
  exec -T relay /relay operator-notice --consult-site --target-build=39 --confirm
```

The living HOW-TO also records this command:
[`deploy/2026-07-24-HOW-TO-DEPLOY.md`](../deploy/2026-07-24-HOW-TO-DEPLOY.md)
(section **Operator notice**).

