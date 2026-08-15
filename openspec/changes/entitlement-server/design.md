## Context

The product already specifies entitlement semantics across `licensing-trial-and-plan-entitlement`, `per-module-licensing-and-bundles`, and `subscription-entitlement-minimal-server-state`. The relay is implemented in `relay/` but has no entitlement integration yet. Trial start is currently local-only (`AppPreferences.markHousingPlanActiveUseStarted`).

Android production will ship before iOS (Apple Developer Program deferred). Phase A therefore targets housing-only server logic with a pluggable `LicenseVerifier` stub; Phase B adds Google Play validation.

## Goals / Non-Goals

**Goals:**

- Separate entitlement process and database from relay ciphertext storage.
- Canonical housing trial, roster, expense-decision metadata, and plan lifecycle state.
- Relay HTTP introspection for gated envelope kinds 5–9.
- Documented refusal codes returned to senders without exposing business payloads.
- Compose topology for local and production deployment next to relay.

**Non-Goals (Phase A):**

- Mobile client integration (follow-up change).
- Apple receipt validation.
- Bundle receipt projection.
- Signed assertions verified locally by relay without introspection (future optimization).

## Decisions

### Decision: Separate `entitlement/` service and database

The entitlement server runs as its own Go binary and PostgreSQL database. The relay calls it over HTTP on a private Docker network.

Rationale: `subscription-entitlement-minimal-server-state` requires separable concerns; relay handlers must not write entitlement tables.

### Decision: Hybrid-ready, introspection-first for Phase A

The relay calls `POST /v1/introspect/envelope` synchronously before storing gated envelopes. Clients may later obtain short-lived signed assertions; relay local verification is deferred.

### Decision: `entitlement_gate` on envelope submit

Gated housing kinds require an optional JSON object on `POST /v1/envelopes`:

- `module` (must be `housing` in Phase A)
- `participant_installation_id`
- `plan_id`
- `operation` (derived from kind if omitted)
- optional `expense_id`, `revision_id`, `decision_kind`

When `ENTITLEMENT_INTROSPECT_URL` is unset, gating is disabled (backward compatible).

### Decision: Play verifier (Phase B) with stub fallback

When `PLAY_SERVICE_ACCOUNT_JSON_PATH` is set, the service calls Google Play
`purchases.subscriptionsv2.get` and persists receipts as `valid` / `invalid`.
Paid housing coverage requires `SUBSCRIPTION_STATE_ACTIVE` and a catalog SKU.
Client-reported `POST /v1/housing/license-status` is then rejected.

When the path is empty, `LicenseVerifier` remains a stub and clients may still
report `active_paid` / `unpaid` (local/dev). Apple validation is Phase C.

### Decision: `participant_installation_id` is an opaque string

Format: base64url, 16–64 bytes decoded length, assigned at client registration. Not tied to relay routing identity in Phase A (mapping is client responsibility).

## Refusal codes (relay-visible)

| Code | Meaning |
|------|---------|
| `entitlement_gate_required` | Gated kind without `entitlement_gate` |
| `entitlement_module_unsupported` | Module not `housing` |
| `entitlement_trial_expired` | Trial ended; required licenses missing |
| `entitlement_not_entitled` | Participant or plan not licensed |
| `entitlement_plan_read_only` | Plan in read-only; mutating operation refused |
| `entitlement_introspection_unavailable` | Entitlement service unreachable |
| `entitlement_introspection_rejected` | Entitlement returned deny |

## Deployment

- Sub-domain or path TBD by operator; default dev: `http://entitlement:8080` on private network.
- Secrets: `DATABASE_URL`, optional `ENTITLEMENT_INTERNAL_TOKEN` for relay→entitlement auth.
- Relay env: `ENTITLEMENT_INTROSPECT_URL`, `ENTITLEMENT_ENABLED=true`.

## Risks

- **Client not yet wired:** Gating only applies when clients send `entitlement_gate`; until mobile ships, operator enables gating only after client update or testing with curl.
- **Stub license trust:** Phase A is not fraud-resistant; Phase B replaces stub for Android.
- **Relay latency:** Synchronous introspection adds RTT; acceptable for Phase A; assertions later.
