# Development roadmap

This document records the **current sequencing decision** for Bojairũ development. It supersedes any earlier informal ordering and is the source of truth for the order in which the OpenSpec changes are intended to be implemented.

It is a planning document, not a capability specification. Capability rules live in `openspec/changes/<change-name>/` and (after archival) in `openspec/specs/<capability>/`.

## Why the order changed

Three things shifted the order:

1. The licensing model is becoming **modular** (per module, with optional combined bundles). The existing `licensing-trial-and-plan-entitlement` change keeps its scope (housing) but is now one **instance** of the per-module model defined in the new `per-module-licensing-and-bundles` change.
2. Participants will be modeled as **Contacts** in a new top-level area. Modules will reference Contacts rather than author inline temporary participant rows. This becomes the first product feature that requires the encrypted relay to actually be running end-to-end.
3. The relay (already specified at the product-semantics level in `privacy-first-sync-architecture`) needs its concrete deployment plus a public audit posture before any feature can use it. That work is captured in the new `relay-server-infrastructure-and-audit` change.

**Spec restructuring** (split into `vehicle-module` and `vehicle-sharing-module`, terminology `vehicle` / `vehicle-sharing`) landed in 2026-06-27. **Owner-side `vehicle`** implementation is in progress (hubs, local persistence, consumption metrics, six Android Maestro E2E scenarios as of 2026-07-01). **`vehicle-sharing`**: hub shell and role-separation guards per `vehicle-usage-role-separation`; relay sync and allocations remain open. Housing remains the primary shipping focus; vehicle owner-path work continues in parallel for local/dev validation.

## Sequence

> The numbering below is the intended **implementation order**. Items within a step can overlap when independent, but each numbered step must reach a meaningful complete state before the next step starts depending on it.

### Step 1 — Contacts module (`contacts-module`)

- On-device Contact entity, list, edit, delete, disconnect, block.
- Generation and out-of-band sharing of unique invitation codes (entropy + checksum + nonce + expiry + revocation).
- Handshake protocol (`hello` / `ack`) running over the encrypted relay.
- Migration mirroring existing module participants into local-only Contacts.

Depends on (will require, at the time the handshake actually runs):
- `relay-server-infrastructure-and-audit` step (the handshake needs a deployed relay). On-device Contact features that don't need the relay can land before the relay is up.

### Step 2 — Housing module adopts Contacts

- Modify the housing flows so that "adding a participant" routes through the Contacts picker.
- Drop the inline temporary participant authoring path in housing.
- Add per-module display alias and historical display snapshots where useful.
- Track this in a follow-up housing-adoption change (to be created when this step starts). That change references `contacts-module-integration` rather than redefining what a Contact is.

### Step 3 — Vehicle modules (`vehicle-module`, `vehicle-sharing-module`)

**Deferred for implementation** until the vehicle domain is ready to ship. **Specs are split** (2026-06-27):

| Module | Identifier | Role |
| --- | --- | --- |
| **Véhicule** | `vehicle` | Owner: register land vehicles (car, truck, motorcycle), full history, maintenance reminders, export on sale (**boat deferred**) |
| **Partage de véhicule** | `vehicle-sharing` | Collaboration: owners who share need `vehicle` + `vehicle-sharing`; borrowers may hold `vehicle-sharing` only |

When this step starts:

- Implement `vehicle-module` and `vehicle-sharing-module` (supersede `car-sharing-module`).
- Route participants through the Contacts picker (`contacts-module-integration`).
- Enforce `module-subscription-dependencies` from `per-module-licensing-and-bundles`.
- Reservations remain wish-list only.

### Step 4 — Relay server infrastructure and audit (`relay-server-infrastructure-and-audit`)

- Concrete deployment on the existing VPS under a dedicated sub-domain.
- Containerized relay + state database (Docker / Compose / equivalent), named-volume persistence.
- Explicit schema (routing relationships, idempotency entries, undelivered ciphertext envelopes, schema-version, sweeper checkpoint), TTLs, and deletion semantics.
- Security baseline (non-root containers, secret management, rate limiting, dependency hygiene, admin out-of-band only).
- Observability without payload visibility (metrics on a private endpoint, structured logs without ciphertext bodies, alerting).
- Public auditability from day one (audit checklist, tagged release matching deployed digest, baseline self-audit entry, quarterly cadence).

> Implementation note: although this step is listed after Steps 1 and 2 in product terms, the relay deployment must be **live** before Step 1's handshake can complete its first end-to-end run with two real devices. In practice, Step 4's repository skeleton, schema, audit checklist, and a development-environment deployment land **in parallel with** Step 1, and the production deployment goes live before Step 1's handshake feature ships to users.

#### Step 1 follow-ups (developer workflow)

- **Drift web runtime assets.** When the app is run in a desktop browser, Drift loads `sqlite3` as a WebAssembly module and offloads queries to a background worker. Both assets — `mobile/web/sqlite3.wasm` and `mobile/web/drift_worker.dart.js` — must match the `sqlite3` and `drift` versions pinned in `pubspec.lock`. The helper `mobile/tool/install_web_assets.sh` (also exposed as `melos run web:assets`) fetches the matching files from GitHub releases. Refresh after any bump of those two packages.
- **Web dev session persistence for `melos run:dev:web`.** A loopback HTTP server (started by `run_dev_web.sh`) writes Drift, prefs, and identity to `~/.cache/compartarenta/web-dev-session.json` after onboarding and on each DB flush. `flutter clean` does not remove that file. Reset with `melos run delete:web-dev-session`.

#### Step 4 follow-ups (deferred until before the first public mobile release)

These items are NOT required for the development deployment of the relay (which is already live and serving `/healthz` end-to-end behind the documented Apache vhost). They MUST be resolved before the first public release of the mobile app that talks to this relay.

- **~~Inject a real build identifier into the relay binary at deploy time.~~** **Resolved on 2026-05-13** with the `v0.1.0` baseline deployment on `sync.incoherences.org`. `BUILD_DIGEST` is now populated from `git rev-parse HEAD` of the tagged commit at build time (per `docs/relay-deployment.md` "Deploying the first time" / "Upgrading"), compiled into the binary via `-ldflags -X internal/version.Build=…`, and surfaced by `/healthz`. `RELAY_TAG` is the matching git tag (e.g. `v0.1.0`) rather than the literal `dev`. The resulting container image's `sha256:` digest is the load-bearing identifier recorded in the Deployments table of `docs/relay-audit-log.md`, satisfying the audit-checklist requirement "tagged release matching deployed digest" end-to-end.

### Step 5 — Focus on completing the housing module

After Steps 1 and 2 land, attention focuses on completing housing:
- Finish the partially-implemented `licensing-trial-and-plan-entitlement` work scoped to housing.
- Finish the partially-implemented `expense-plan-contract-model` flows (some tasks remain).
- Apply the per-module licensing layer defined in `per-module-licensing-and-bundles` to housing as its canonical instance.
- Vehicle owner-side features may continue in parallel; vehicle **relay sync and store licensing** stay gated on contacts + per-module entitlement maturity.

## Modular licensing — where it sits in the order

`per-module-licensing-and-bundles` is **not a standalone shipping step**. It defines the per-module entitlement model and the store-mapping rules. Its concrete implementation lands in two places:

- The app's entitlement layer is refactored to be module-aware as part of Step 1 or Step 2 (whichever needs the entitlement layer first; in practice, Step 1's Contacts feature is free, so module-awareness is consumed first by Step 5's housing licensing).
- Google Play subscription products for **housing**, **vehicle**, **vehicle-sharing**, and the launch **bundles** are catalogued in [`docs/store-mapping.md`](store-mapping.md) (create in Play Console when monetization ships). Apple identifiers remain placeholders until iOS store work begins.

## Mapping to the existing OpenSpec changes

| Change                                            | Role in the new order                                                                                                                                            | Status |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `app-onboarding-initial-setup`                    | Already mostly done. No re-sequencing needed.                                                                                                                    | In progress (most tasks complete) |
| `privacy-first-sync-architecture`                 | Product semantics of the relay. Unchanged. Continues to be the source of truth for relay behavior.                                                              | Not impacted by this roadmap |
| `client-db-selection`                             | On-device persistence choice. Continues to underpin all module data + Contacts.                                                                                  | Not impacted by this roadmap |
| `mobile-app-store-release`                        | Continues to apply. Per-module subscriptions will reference its release process.                                                                                 | Not impacted by this roadmap |
| `expense-plan-contract-model`                     | Belongs to Step 5 (complete housing).                                                                                                                            | In progress |
| `licensing-trial-and-plan-entitlement`            | Belongs to Step 5 (complete housing). Now treated as the housing **instance** of the per-module model.                                                          | Not started |
| `car-sharing-module`                              | **Superseded** by `vehicle-module` + `vehicle-sharing-module`. Spec only; not implemented.                                                                       | Superseded (2026-06-27) |
| `vehicle-module`                                  | Step 3 — owner-side vehicle domain.                                                                                                                              | In progress (owner flows + E2E; export/import and notifications open) |
| `vehicle-sharing-module`                          | Step 3 — sharing, borrower usage, allocations.                                                                                                                   | In progress (local hub/invite; relay sync and allocations open) |
| `ui-localization-fr-en-es`                        | Cross-cutting; tracked separately.                                                                                                                                | In progress |
| **NEW** `contacts-module`                         | Step 1.                                                                                                                                                          | Proposed |
| **NEW** `relay-server-infrastructure-and-audit`   | Step 4 (with dev-environment deployment in parallel with Step 1).                                                                                                | Proposed |
| **NEW** `per-module-licensing-and-bundles`        | Cross-cutting; consumed by Steps 1–5 as needed.                                                                                                                  | Proposed |

## Post-v1 backlog (out of scope for the first public release)

- **User-selectable currency and conversion.** The first release uses a single fixed storage currency (`CAD`, applied at onboarding) and shows amounts with the **`$` symbol only** — never the ISO code in UI. Settings → Units does not expose currency until multi-currency plans, user choice, and conversion logic are implemented. Existing currency picker data (`supported_currencies.dart`) and prefs storage remain for a future change; track implementation when conversion is specified.

## What this roadmap deliberately does NOT do

- It does not change the product-level semantics of the relay (those live in `privacy-first-sync-architecture` and stay as-is).
- It does not rename or implement the superseded `car-sharing-module` change. Owner/sharing split lives in `vehicle-module` and `vehicle-sharing-module`.
- It does not lock in pricing decisions. Per-module and bundle prices are commercial decisions made before each module ships.
- It does not commit to specific dates. Sequencing is a partial order with named gates, not a schedule.

## Updating this roadmap

This file is a living document. Any change to the order, the gates between steps, or the deferral status of vehicle SHALL be made by editing this file in a dedicated commit (or pull request) with a brief rationale.
