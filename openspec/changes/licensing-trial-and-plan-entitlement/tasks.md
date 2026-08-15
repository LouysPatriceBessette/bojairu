## 1. Domain and state machine

- [ ] 1.1 Define plan lifecycle states: free/unlinked, linked-not-active, active-trial, active-paid, delinquent-grace, delinquent-readonly.
- [ ] 1.2 Define events that transition states: second participant linked, qualifying realized expense sync, payment success, payment failure, grace expiry.
- [ ] 1.3 Define installation-identity-scoped `trial_consumed` state and the rule “no housing trial if any participant already consumed one”.

## 2. Notifications and UX

- [ ] 2.1 Implement trial reminder schedule: trial start (with end date), 1 week remaining, daily for last 3 days.
- [ ] 2.2 Implement delinquency reminders: daily to all participants during 1-week grace.
- [ ] 2.3 Implement read-only mode UX and clear banner explaining what is blocked and why.

## 3. Licensing model

- [ ] 3.1 Implement per-participant license checks and plan-level enforcement.
- [ ] 3.2 Implement plan-aligned renewal date once all required licenses are paid.
- [ ] 3.3 Implement entitlement-server canonical state for housing trial, accepted roster, and plan authorization.
- [ ] 3.4 Implement relay-facing authorization for gated housing operations using signed assertions, online checks, or a documented hybrid.
- [ ] 3.5 Treat store-supported promotional entitlements as valid housing licenses when store state is active.
- [ ] 3.6 When unpaid license blocks the plan (≥ 2 other active licenses): “Modify plan for remaining participants” flow with ratio redistribution and inactive participant (align with `housing-participation-change-major-flow` mechanics; no differential report in initial release).
- [x] 3.7 When entitlement / relay can obtain authoritative Google Play Developer API expiry (`expiryTime` / `expiryTimeMillis`) from uploaded purchase tokens, use that for Licenses renewal/end dates (and stop relying on client-side license-tester period estimates).

## 4. Export and legal documentation

- [ ] 4.1 Implement export flows that remain available in read-only mode so participants can always retrieve their history.
- [x] 4.2 Add a legal/disclosures document describing dispute-limited behavior and that the app is not legal advice. *(`docs/legal-and-disputes.md`; linked from `README.md` FR/EN/ES — Jul 2026.)*
- [ ] 4.3 Import gate: active store subscription (housing standalone or bundle) per `device-data-import-restore`; export always available. Entitlement server does not gate import.

## 5. Tests

- [ ] 5.1 Unit tests for state machine transitions and time-based reminders.
- [ ] 5.2 Integration tests: active use triggers trial; trial expiry gating; delinquency grace then read-only; export available when read-only.
- [ ] 5.3 Integration tests: a new accepted housing plan with any `trial_consumed` installation identity receives no new trial; import refused without active paid store subscription (trial/grace/expired).

## Deferred — differential impact report only (wish list)

Not blocking initial Play / App Store release. Product decision 2026-07-06. Plan adaptation on removal (all cases) remains in scope. See `dev-ideas/2026-06-27-wish-list.md` § 3.

- [ ] D.1 **Case A — unpaid license:** differential impact report (per-participant projected obligations before vs after).
- [ ] D.2 **Case B — voluntary withdrawal / ejection:** before/after impact projection UI in Major change flows.
- [ ] D.3 Legal copy and in-app disclosure for the differential report (when shipped).
- [ ] D.4 Unit / integration tests for projection diff math and export.

