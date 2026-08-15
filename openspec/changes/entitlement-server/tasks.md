## 1. OpenSpec and layout

- [x] 1.1 Create `entitlement-server` change with proposal, design, specs, tasks.
- [x] 1.2 Add `entitlement/` Go project skeleton mirroring relay patterns.

## 2. Entitlement service core

- [x] 2.1 Schema: installations, housing plans, rosters, expense decisions, license status, receipt placeholder.
- [x] 2.2 Housing lifecycle: trial (14d), grace (7d), read-only transitions.
- [x] 2.3 API: register installation, report roster, active-use, expense decision, license status.
- [x] 2.4 Introspection endpoint for relay.
- [x] 2.5 Stub `LicenseVerifier`; store receipt blobs as `pending` for Phase B.

## 3. Relay integration

- [x] 3.1 `entitlement_gate` on envelope POST; gated kinds 5–9.
- [x] 3.2 HTTP client + config (`ENTITLEMENT_INTROSPECT_URL`, `ENTITLEMENT_ENABLED`).
- [x] 3.3 Refusal metrics and documented error codes.
- [x] 3.4 Compose: entitlement service + DB; relay wired on private network.

## 4. Tests and docs

- [x] 4.1 Unit tests: housing lifecycle, introspection allow/deny.
- [x] 4.2 Relay unit tests: gate required, introspection deny path.
- [x] 4.3 `entitlement/README.md` and `.env.example`.

## 5. Follow-ups (not Phase A)

- [x] 5.1 Mobile client: register installation, report metadata, attach `entitlement_gate`.
- [x] 5.2 Phase B: Google Play `LicenseVerifier` implementation.
- [ ] 5.3 Phase C: Apple validation; `docs/store-mapping.md`.
- [x] 5.4 Audit checklist extension for entitlement deployment.
- [ ] 5.5 Signed assertions verified locally by relay.
