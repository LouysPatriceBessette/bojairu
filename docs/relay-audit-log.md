# Bojairũ Relay — Audit Log

Public, append-only record of stack deployments and self-audits
(`relay-public-auditability`).

**How to deploy and audit:** [`deploy/2026-07-24-HOW-TO-DEPLOY.md`](../deploy/2026-07-24-HOW-TO-DEPLOY.md)
(§1 Deploy, then §2 Audit). Append entries here after each release.

**Rules**

- Never delete a past entry. Append only.
- Operator / auditor fields use a **role** id (e.g. `operator-on-call`), not a personal name.
- Image digests are immutable container ids (`sha256:…` / `docker inspect` `.Id`).
- Configuration drift vs docs is a **Finding** before you rewrite the docs.

---

## Deployments

Copy the template, fill it, paste **above** the older entries (newest first)
or append at the bottom — pick one convention and keep it. This file uses
**newest last** (chronological).

### Template

```markdown
### vX.Y.Z

- **Tag:** vX.Y.Z
- **Relay image digest:** sha256:…
- **Entitlement image digest:** sha256:…   (omit only for pre-entitlement releases)
- **Deployed at:** YYYY-MM-DDTHH:MMZ
- **Git commit:** <full sha>
- **Operator:** operator-on-call
- **Notes:** one or two sentences
```

### v0.1.0

- **Tag:** v0.1.0
- **Relay image digest:** sha256:1c826875efb8c73a96676d82c0fabcbb3e0f3849167d79bf3c831b773ddc653e
- **Deployed at:** 2026-05-13T21:05Z
- **Git commit:** _(not recorded in earlier log rows)_
- **Operator:** operator-on-call
- **Notes:** First deployment.

### v0.2.0

- **Tag:** v0.2.0
- **Relay image digest:** sha256:b5967deacc70d3b19cd2e31a12f294898a7549951779a8b92ba9a81d63cc010d
- **Deployed at:** 2026-05-19T21:58Z
- **Git commit:** _(not recorded in earlier log rows)_
- **Operator:** operator-on-call
- **Notes:** Closed-app push delivery (schema v2). Wake dispatch disabled (`WAKE_PUSH_DISPATCH_ENABLED=false`). Stats cron via `daily-stats-append-via-docker.sh`.

### v0.2.1

- **Tag:** v0.2.1
- **Relay image digest:** sha256:1c826875efb8c73a96676d82c0fabcbb3e0f3849167d79bf3c831b773ddc653e
- **Deployed at:** 2026-05-26T00:23Z
- **Git commit:** b69d4bfb2ed0c5b9bb6d5acae04cbdbffebd4567
- **Operator:** operator-on-call
- **Notes:** Raised `ENVELOPE_MAX_BYTES` to 262144 (256 KiB) for proof-bearing envelopes.

### v0.3.0

- **Tag:** v0.3.0
- **Relay image digest:** sha256:5055f30f74eb18e9616086ad9be5c5469090d4ea2e99081baa75d713e581e1ff
- **Deployed at:** 2026-06-18T16:54Z
- **Git commit:** 5abd13e1970a50143776b248af37f8d7673261dc
- **Operator:** operator-on-call
- **Notes:** Cron notifications on the relay; first entitlement server deploy.

### v0.3.1

- **Tag:** v0.3.1
- **Relay image digest:** sha256:f01a7f7c30436e8aae806724187841edfa704d3ccd9ffe2cd08f1e68af9fffde
- **Deployed at:** 2026-06-23T13:21Z
- **Git commit:** 0e334a44d8908748da1d366dbfc7efcd23ea40de
- **Operator:** operator-on-call
- **Notes:** Installation id update on mobile device data import (relay + entitlement).

### v0.4.0

- **Tag:** v0.4.0
- **Relay image digest:** sha256:3f70e5d2c55babdd56f57771d6403f4add9e19f3ff6a477540ebb7e497adeabc
- **Entitlement image digest:** sha256:4c30c73512ec9603b7b9b8f10757225a17a52a4ffc4c82667aa310fcff5e2c42
- **Deployed at:** 2026-07-24T17:49Z
- **Git commit:** 5a434ecad615f76c1feaba41d033450dc2ad8578
- **Operator:** operator-on-call
- **Notes:** Bojairũ scheme/landing + FCM service-account path hardening; wake dispatch enabled; living HOW-TO deploy/audit (`deploy/2026-07-24-HOW-TO-DEPLOY.md`).

### v0.5.0

- **Tag:** v0.5.0
- **Relay image digest:** sha256:a8465960a3b86ae6362631c58cedc3a712c4f27330bf89d96ed9702ba42e99e9
- **Entitlement image digest:** sha256:037fdf1b86e4bfb8129778ecee9c846200c5a468f3dfd5e34baf5c25b87a9c1a
- **Deployed at:** 2026-08-16T20:09Z
- **Git commit:** e6b9f05c2bd2cb8be98e8fae629edb9cbabd09dd
- **Operator:** operator-on-call
- **Notes:** Envelope expiry (`expires_at`, relay schema 4) and vehicle-sharing deadline domain; Play purchase verifier on entitlement (schema 2, host JSON bind); `operator-notice` in the relay image.

---

## Self-audits

Cadence: at least once every **90 days**. Missed deadline → open a Finding.

### Template

```markdown
### Self-audit — vX.Y.Z

- **Date:** YYYY-MM-DDTHH:MMZ
- **Tag:** vX.Y.Z
- **Relay image digest:** sha256:…
- **Entitlement image digest:** sha256:…
- **Operator:** operator-on-call
- **Procedure:** deploy/2026-07-24-HOW-TO-DEPLOY.md §2
- **Summary:** …
- **Findings:** None. | See Findings / <id>
```

### Baseline (v0.1.0)

- **Date:** 2026-05-13T21:05Z
- **Tag:** v0.1.0
- **Relay image digest:** sha256:1c826875efb8c73a96676d82c0fabcbb3e0f3849167d79bf3c831b773ddc653e
- **Operator:** operator-on-call
- **Procedure:** docs/relay-audit-checklist.md @ 6a2fdc026d472179b50505736f2a5a7c8bfb595a _(superseded; use HOW-TO going forward)_
- **Summary:** Initial deployment of sync.incoherences.org; all checks pass.
- **Findings:** None.

### Self-audit — v0.2.0

- **Date:** 2026-05-19T21:58Z
- **Tag:** v0.2.0
- **Relay image digest:** sha256:b5967deacc70d3b19cd2e31a12f294898a7549951779a8b92ba9a81d63cc010d
- **Operator:** operator-on-call
- **Procedure:** docs/relay-audit-checklist.md @ 899e36cb441fef858c78b5b444e191ed5d407a65 _(superseded)_
- **Summary:** Generic closed-app push delivery; all checks pass.
- **Findings:** None.

### Self-audit — v0.2.1

- **Date:** 2026-05-26T00:23Z
- **Tag:** v0.2.1
- **Relay image digest:** sha256:1c826875efb8c73a96676d82c0fabcbb3e0f3849167d79bf3c831b773ddc653e
- **Operator:** operator-on-call
- **Procedure:** docs/relay-audit-checklist.md @ b69d4bfb2ed0c5b9bb6d5acae04cbdbffebd4567 _(superseded)_
- **Summary:** Raised `ENVELOPE_MAX_BYTES` to 262144 for compressed proof images in envelopes.
- **Findings:** None.

### Self-audit — v0.3.0

- **Date:** 2026-06-18T16:54Z
- **Tag:** v0.3.0
- **Relay image digest:** sha256:5055f30f74eb18e9616086ad9be5c5469090d4ea2e99081baa75d713e581e1ff
- **Operator:** operator-on-call
- **Procedure:** docs/relay-audit-checklist.md @ 5abd13e1970a50143776b248af37f8d7673261dc _(superseded)_
- **Summary:** Cron notifications + first entitlement server deploy.
- **Findings:** None.

### Self-audit — v0.3.1

- **Date:** 2026-06-23T13:21Z
- **Tag:** v0.3.1
- **Relay image digest:** sha256:f01a7f7c30436e8aae806724187841edfa704d3ccd9ffe2cd08f1e68af9fffde
- **Operator:** operator-on-call
- **Procedure:** docs/relay-audit-checklist.md @ 0e334a44d8908748da1d366dbfc7efcd23ea40de _(superseded)_
- **Summary:** Installation id update on mobile device data import.
- **Findings:** None.

### Self-audit — v0.4.0

- **Date:** 2026-07-24T17:49Z
- **Tag:** v0.4.0
- **Relay image digest:** sha256:3f70e5d2c55babdd56f57771d6403f4add9e19f3ff6a477540ebb7e497adeabc
- **Entitlement image digest:** sha256:4c30c73512ec9603b7b9b8f10757225a17a52a4ffc4c82667aa310fcff5e2c42
- **Operator:** operator-on-call
- **Procedure:** deploy/2026-07-24-HOW-TO-DEPLOY.md §2
- **Summary:** §2.0–§2.6 PASS (public surface, digests, DB, metrics, entitlement loopback, FCM `project_id=bojairu`, wake flags, stats file). First full audit against the living HOW-TO; Appendix A expected outputs filled from this run.
- **Findings:** Finding 2026-07-24 — daily-stats-host-cron-remnant (resolved same day).

### Self-audit — v0.5.0

- **Date:** 2026-08-16T21:12Z
- **Tag:** v0.5.0
- **Relay image digest:** sha256:a8465960a3b86ae6362631c58cedc3a712c4f27330bf89d96ed9702ba42e99e9
- **Entitlement image digest:** sha256:037fdf1b86e4bfb8129778ecee9c846200c5a468f3dfd5e34baf5c25b87a9c1a
- **Operator:** operator-on-call
- **Procedure:** deploy/2026-07-24-HOW-TO-DEPLOY.md §2
- **Summary:** §2.1–§2.6 PASS on this host after two audit-script/doc alignments (not production bind changes). Relay `schema_version` 4; entitlement `schema_version` 2, `build` `e6b9f05c2bd2cb8be98e8fae629edb9cbabd09dd`. Public HTML is `/contact/invite/` only (`/` → 403). Play service-account JSON is mounted (smoke §11; §2.5 does not verify Play). FCM `project_id=bojairu` via §2.6.
- **Findings:** Finding 2026-08-16 — public-root-no-index (accepted). Finding 2026-08-16 — audit-2.5-public-8081-000000 (resolved same day).

---

## Findings

Append one block per finding. Status starts as `open`, then `resolved`
(with fix pointer) or `accepted` (with written reason).

### Template

```markdown
### Finding YYYY-MM-DD — short-slug

- **Date:** YYYY-MM-DD
- **Auditor:** operator-on-call
- **Item:** 2.1 / public surface (or other HOW-TO §2 subsection)
- **Observed:** …
- **Expected:** …
- **Status:** open | resolved | accepted
- **Resolution:** …
```

### Finding 2026-07-24 — daily-stats-host-cron-remnant

- **Date:** 2026-07-24
- **Auditor:** operator-on-call
- **Item:** 2.6 / closed-app push and daily stats
- **Observed:** `crontab -l` still listed a commented host
  `daily-stats-append.sh` line beside the via-docker job.
- **Expected:** exactly one cron line —
  `daily-stats-append-via-docker.sh`.
- **Status:** resolved
- **Resolution:** Removed the host-script remnant. Re-check:
  `crontab -l | grep daily-stats` shows only via-docker.

### Finding 2026-08-16 — public-root-no-index

- **Date:** 2026-08-16
- **Auditor:** operator-on-call
- **Item:** 2.1 / public surface
- **Observed:** `GET https://sync.incoherences.org/` → HTTP 403.
  DocumentRoot `/var/www/compartarenta-relay-landing/` has no
  `index.html`. Invite HTML is only at `/contact/invite/` (Bojairũ /
  `bojairu://`).
- **Expected (until this finding):** HTTP 200 (HOW-TO A.2.1.5 from
  2026-07-24).
- **Status:** accepted
- **Resolution:** Operator decision 2026-08-16: no marketing homepage
  on the relay sub-domain. Public HTML is `/contact/invite/` only.
  `audit-2.1-public-surface.sh` and HOW-TO A.2.1.5 now expect 403 or
  404 on `/`. `docs/relay-deployment.md` updated to match.

### Finding 2026-08-16 — audit-2.5-public-8081-000000

- **Date:** 2026-08-16
- **Auditor:** operator-on-call
- **Item:** 2.5 / entitlement
- **Observed:** `audit-2.5-entitlement.sh` printed FAILED.
  Step-through showed `public8081=000000`. Live bind is
  `127.0.0.1:8081`; public `https://sync.incoherences.org:8081/healthz`
  does not connect. `curl -w '%{http_code}'` already writes `000` and
  exits non-zero; the script also ran `|| echo 000`.
- **Expected:** HTTP `000` (or empty) meaning 8081 is not reachable
  from the public internet.
- **Status:** resolved
- **Resolution:** Replaced `|| echo "000"` with `|| true` in
  `deploy/audit-2.5-entitlement.sh`. Production listen/bind unchanged.

---

## Configuration drift

If live config disagrees with [`relay-deployment.md`](./relay-deployment.md)
or the HOW-TO (TTL, digests, exposed surface, schema), open a Finding
**before** changing the documentation.
