## Implementation status (2026-07-14)

**`vehicle-sharing`**: hub shell, invite/accept APIs, borrower-path UI with owner-path guards per `vehicle-usage-role-separation`. **Relay sync not shipped** — cross-installation sharing is incomplete until §5.2 lands. **2026-07-14:** owner-module defers Emprunteur→Propriétaire gap-notify (**11.2a**) into this change’s Emprunteur delivery (see §2.2).

## 1. Sharing domain

- [x] 1.1 Define VehicleSharingLink (vehicle, owner, borrower, status)
- [x] 1.2 Owner invite flow (requires `vehicle` + `vehicle-sharing`)
- [x] 1.2a Response deadline dialog (3h/8h/24h/48h) + `expiresAt` on link + offer JSON; local pending→expired; shares-detail “invitation sent to … on …”
- [ ] 1.2b **Deferred (relay):** enforce offer TTL / inbox expiry on relay, deadline reminder fires, and cross-device expiry beyond client JSON (no Go change in 1.2a)
- [x] 1.3a Borrower accept flow (`acceptSharingLink`)
- [ ] 1.3b Owner revoke UI (`revokeSharingLink` API exists; no hub control yet)
- [x] 1.4 Multi-vehicle and multi-borrower list surfaces (basic hub lists)
- [ ] 1.5 Enforce cap of five distinct active Emprunteurs per Propriétaire (`vehicle-sharing-domain-model`)

## 2. Borrower usage

- [x] 2.1 Borrower use session UI on shared vehicles (start/end readings)
- [ ] 2.2 Gap attribution notifications to attributed Emprunteur/Propriétaire (`vehicle-odometer-gap-attribution`) — not wired (`vehicleGapOwnerNotified` l10n only); relay/push deferred. **Includes 11.2 Emprunteur→Propriétaire notify path** deferred from owner-module (2026-07-14 decision); implement with Emprunteur delivery, not current `vehicle` owner scope.
- [ ] 2.3 Borrower-path quick actions (odometer, fuel, maintenance report, damage/violation) per `vehicle-quick-actions-ui` and `vehicle-usage-role-separation` — UI + guards shipped; **relay forward** deferred (§5.2)
- [x] 2.4 Emprunteur hub does not show Propriétaire-only alert tiles or lifetime owner metrics

## 3. Metrics & reconciliation

- [x] 3.1 Borrower-scoped distance and fuel statistics — **informative running usage balance** (formula + shared detail UI); broader stats charts still open
- [x] 3.2 Reconciliation window per borrower — running window from `acceptedAt` until future confirmed usage payment (payment flow not shipped)
- [ ] 3.3 Owner aggregate view across all sharers — owner **per-Emprunteur balance list** shipped; usage-ratio aggregate allocation still open (`vehicle-expense-sharing`)

## 4. Expense sharing

- [ ] 4.1 Category model (Fuel, Maintenance, Violations, Payments)
- [ ] 4.2 Ratio configuration with propose/accept
- [ ] 4.3 Violation responsibility proposals
- [ ] 4.4 Explainable allocation breakdown UI

## 5. Integration

- [x] 5.1 Contacts picker for invite (connected Contacts only)
- [ ] 5.2 Relay sync for sharing links and usage facts
- [ ] 5.3 Gate borrowing on `vehicle-sharing`; gate sharing out on both modules (debug-only stub)
- [x] 5.4 Vehicle sharing hub (`vehicle-sharing-hub-ui`): accessible vehicles, statistics, quick actions
- [x] 5.5 Remove any sharing-side dependencies on prototype `car_sharing` screens (`vehicle-legacy-code-removal`)

## 6. Usage role separation (spec `vehicle-usage-role-separation`)

- [x] 6.1 Spec written: one DB per installation, navigation-derived role, forbid self-borrow, accessible = other installations + relay.
- [x] 6.2 Code: exclude self-owned vehicles from Emprunteur accessible/pending lists; `denyVehicleUsageAccess` on borrower path for own vehicles; `VehicleUsageContext` from hub routes.
- [ ] 6.3 Enforce at API layer: `createSharingOffer` / seeds MUST NOT create self-borrow links; add unit tests for denial paths.
- [ ] 6.4 QA: document that current vehicle Maestro scenarios are **owner-path only**; Emprunteur E2E waits on relay fixtures (see `vehicle-module` tasks §14.4).
