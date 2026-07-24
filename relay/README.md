# Bojairũ Relay

A privacy-first relay for end-to-end-encrypted envelopes exchanged between
Bojairũ clients. The relay never sees plaintext: every envelope it
stores is opaque ciphertext addressed to opaque recipient identifiers. This
project's value to operators and users is that **what the relay does NOT do
is enforceable by reading this repository**.

## Status

This is the day-one source for the relay capability defined in OpenSpec
change `relay-server-infrastructure-and-audit`. The product semantics it
enforces (encrypted-only, no-persistence-after-delivery, TTL-bounded,
proposal/accept/reject) are pinned by capability
`privacy-first-sync-architecture` in the parent repository.

## Architecture at a glance

- **Language / runtime:** Go 1.26+. Single static binary.
- **Database:** PostgreSQL, deployed as a sibling container on a private
  Docker network. The DB port is never exposed to the public internet.
- **Public surface:** a single HTTPS endpoint at the dedicated sub-domain
  (e.g., `relay.<example.tld>`). Metrics and admin live on a separate
  private port that is not bound to the public interface.
- **State:** the only persistent data is what
  [`relay-state-schema-and-retention`](../openspec/changes/relay-server-infrastructure-and-audit/specs/relay-state-schema-and-retention/spec.md)
  enumerates: routing relationships, idempotency entries, undelivered
  ciphertext envelopes, schema version, and the sweeper checkpoint. **No
  display names, no avatars, no expense data, no email, no phone.**

```
                        public internet
                              │
                              │ HTTPS, port 443
                              ▼
                ┌─────────────────────────────────┐
                │  reverse proxy (TLS at the edge) │  ← documented in
                │  forwards to relay on private nw │    docs/relay-deployment.md
                └────────────────┬────────────────┘
                                 │ http://relay:8080 (private)
                                 ▼
            ┌──────────────────────────────────────┐
            │  relay (this Go binary)              │
            │  - POST /v1/envelopes                │
            │  - GET  /v1/envelopes/inbox/:id      │
            │  - POST /v1/envelopes/:id/ack        │
            │  - POST /v1/disconnect               │
            │  - GET  /healthz, /readyz (public-ok) │
            │  - GET  /metrics  (private port)     │
            └────────────────┬─────────────────────┘
                             │ tcp://postgres:5432 (private)
                             ▼
                  ┌──────────────────────────┐
                  │ postgres (sibling)       │
                  │ - named volume           │
                  │ - migrations versioned   │
                  └──────────────────────────┘
```

## Repository layout

| Path | Purpose |
|------|---------|
| [`cmd/relay/`](./cmd/relay) | Process entry point. Wires config, DB, HTTP server, sweeper. |
| [`internal/api/`](./internal/api) | HTTP handlers, framing validation, size limits, rate limiting, logging. |
| [`internal/store/`](./internal/store) | DB layer; the only place SQL is written. |
| [`internal/sweeper/`](./internal/sweeper) | Periodic task: envelope TTL, idempotency TTL, disconnect grace. |
| [`internal/ratelimit/`](./internal/ratelimit) | Token bucket per opaque identity and per source IP. |
| [`internal/metrics/`](./internal/metrics) | Prometheus collectors. |
| [`internal/config/`](./internal/config) | Environment-variable parsing. Secrets never default to a non-empty value. |
| [`internal/logging/`](./internal/logging) | Structured logger with an explicit field allow-list. |
| [`internal/store/schema/`](./internal/store/schema) | Versioned SQL migrations applied at startup. Embedded into the binary via `//go:embed`. |
| [`internal/integration/`](./internal/integration) | PostgreSQL integration tests (build tag `integration`; see "Running locally"). |
| [`Dockerfile`](./Dockerfile) | Reproducible image build. |
| [`compose.yml`](./compose.yml) | Dev/reference deployment manifest. |
| [`.env.example`](./.env.example) | Documented configuration template. **Real secrets never live in this repo.** |
| [`deploy/apache2/relay-vhost.conf.template`](./deploy/apache2/relay-vhost.conf.template) | Reference Apache vhost: TLS, static landing page on `/`, reverse-proxy to the relay on `/v1/`, `/healthz`, `/readyz`. |

The audit posture (checklist, deployment runbook, audit log) lives one
level up in [`../docs/`](../docs):

- [`../docs/relay-deployment.md`](../docs/relay-deployment.md)
- [`../docs/relay-audit-checklist.md`](../docs/relay-audit-checklist.md)
- [`../docs/relay-audit-log.md`](../docs/relay-audit-log.md)

## Running locally

```bash
# Build the binary and run unit tests.
go test ./...
go build ./cmd/relay

# Bring up the dev stack (PostgreSQL + relay) on a private network.
docker compose --env-file .env.example up --build
```

The relay refuses to start if the on-disk schema version does not match
the binary's expected version (`relay-state-schema-and-retention` /
"Schema migrations are versioned and reviewable").

### PostgreSQL integration tests (OpenSpec 7.3 / 7.4)

End-to-end tests against a real database live under
[`internal/integration/`](./internal/integration). They use the Go build
tag `integration` and are skipped unless `RELAY_INTEGRATION_TEST_DSN` is set
to a PostgreSQL connection string (same shape as `DATABASE_URL`, typically
`sslmode=disable` for local Docker).

```bash
export RELAY_INTEGRATION_TEST_DSN='postgresql://relay:relay@127.0.0.1:5432/relay?sslmode=disable'
go test -tags=integration -count=1 ./internal/integration/...
```

They delete relay data tables at the start of each test; use a dedicated
database, not production.

## Why Go, why PostgreSQL?

Recorded here because the spec is language-agnostic and this is the place
the implementer's choice is supposed to be documented.

- **Go**: standard library covers HTTP, TLS, crypto, structured logging,
  and concurrency. The resulting image is a single static binary <20 MB
  on `FROM scratch`, which keeps the supply-chain audit step's surface
  small (few third-party deps, easy SBOM, easy dependency-scan).
- **PostgreSQL**: needed for the spec's "DB runs in its own container"
  requirement and gives us mature versioned-migration tooling. SQLite is
  ruled out because it would run in-process with the relay binary and
  violate the network-isolation requirement.

## What the relay does NOT do

- It does NOT decrypt envelopes. Ever.
- It does NOT store display names, avatars, expense data, e-mail
  addresses, phone numbers, or any user-presented identity attribute.
- It does NOT keep delivered envelopes past delivery.
- It does NOT keep undelivered envelopes past their TTL.
- It does NOT log envelope ciphertext or any field that would, alone or
  combined, reveal user content.
- It does NOT host any unrelated workload in its containers.
- It does NOT expose admin or metrics surfaces on the public internet.

Each of these statements is testable; see
[`../docs/relay-audit-checklist.md`](../docs/relay-audit-checklist.md).
