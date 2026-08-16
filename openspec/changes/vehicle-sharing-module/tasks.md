## Implementation status (2026-08-07)

**`vehicle-sharing` thin cut:** invite/accept, usage sessions, fuel catch-up, informative usage balance + freeze/transfers, revoke/reactivate, Emprunteur caps, gap flow via pending corrections. **Category expense ratios (`vehicle-expense-sharing`) are out of product.** Gap product behavior is **owner-notified + Unknown until Propriétaire resolves** (see `vehicle-odometer-gap-attribution`); task 2.2 no longer tracks the obsolete “attribute at save + notify attributed party” design.

## 1. Sharing domain

- [x] 1.1 Define VehicleSharingLink (vehicle, owner, borrower, status)
- [x] 1.2 Owner invite flow (requires `vehicle` + `vehicle-sharing`)
- [x] 1.2a Response deadline dialog (3h/8h/24h/48h) + `expiresAt` on link + offer JSON; local pending→expired; shares-detail “invitation sent to … on …”
- [x] 1.2b **Relay:** offer TTL / inbox expiry from plaintext `expires_at` (else 7-day retention); recipe-A deadline reminder fires for offer and reactivation; client still refuses accept after local `expiresAt`
- [x] 1.3a Borrower accept flow (`acceptSharingLink`)
- [x] 1.3b Owner revoke / reactivate UI (unilateral revoke + dedicated reactivate kinds; shares screen controls)
- [x] 1.4 Multi-vehicle and multi-borrower list surfaces (basic hub lists)
- [x] 1.5 Enforce cap of five distinct Emprunteurs per Propriétaire (`vehicle-sharing-domain-model`) — counts `active` + `pending` + `reactivatePending`; reactivation has offer-like `expiresAt` (back to `revoked` on expiry); fifth-slot warning + sixth blocked

## 2. Borrower usage

- [x] 2.1 Borrower use session UI on shared vehicles (start/end readings)
- [x] 2.2 Odometer gap product flow (`vehicle-odometer-gap-attribution`): positive gaps stored as **Unknown** until Propriétaire resolves (correct reading or assign / add sessions via pending corrections); Propriétaire notified on Emprunteur session-start gap/conflict; Unknown distance excluded from Emprunteur owed inputs. **Obsolete:** prompt “who is the gap attributable to?” at save time + notify the attributed peer — not product.
- [ ] 2.3 Borrower-path quick actions (odometer, fuel, maintenance report, damage/violation) per `vehicle-quick-actions-ui` and `vehicle-usage-role-separation` — UI + guards shipped; **relay forward** deferred (§5.2)
- [x] 2.4 Emprunteur hub does not show Propriétaire-only alert tiles or lifetime owner metrics

## 3. Metrics & reconciliation

- [x] 3.1 Borrower-scoped distance and fuel statistics — **informative running usage balance** (formula + shared detail UI); broader stats charts still open
- [x] 3.2 Reconciliation window per borrower — running window from `acceptedAt` until freeze/transfer settlement on the usage balance
- [x] 3.3 Owner per-Emprunteur usage-balance list shipped. **Cancelled:** usage-ratio aggregate allocation via `vehicle-expense-sharing` (out of product — thin cut uses usage balance only)

## 4. Expense sharing

**Out of product (2026-08-07).** No housing-style category ratios; maintenance cost stays with Propriétaire; fuel covered by usage-balance anchors; violations informational only. See `vehicle-expense-sharing` scope note.

- [x] 4.1 ~~Category model~~ — **cancelled / out of product**
- [x] 4.2 ~~Ratio configuration with propose/accept~~ — **cancelled / out of product**
- [x] 4.3 ~~Violation responsibility proposals~~ — **cancelled / out of product**
- [x] 4.4 ~~Explainable allocation breakdown UI~~ — **cancelled / out of product** (usage-balance breakdown is the product UI)

## 5. Integration

- [x] 5.1 Contacts picker for invite (connected Contacts only)
- [ ] 5.2 Relay sync for sharing links and usage facts
- [x] 5.2a Fuel catch-up (kind 23) on session start: Emprunteur sends `lastKnownPurchaseId`; Propriétaire always replies (empty purchases = ack); stable fuel ids; Emprunteur `fuelCatchUpResponseReceived` gates session-end distance guard while awaiting
- [ ] 5.3 Gate borrowing on `vehicle-sharing`; gate sharing out on both modules (debug-only stub)
- [x] 5.4 Vehicle sharing hub (`vehicle-sharing-hub-ui`): accessible vehicles, statistics, quick actions
- [x] 5.5 Remove any sharing-side dependencies on prototype `car_sharing` screens (`vehicle-legacy-code-removal`)

## 6. Usage role separation (spec `vehicle-usage-role-separation`)

- [x] 6.1 Spec written: one DB per installation, navigation-derived role, forbid self-borrow, accessible = other installations + relay.
- [x] 6.2 Code: exclude self-owned vehicles from Emprunteur accessible/pending lists; `denyVehicleUsageAccess` on borrower path for own vehicles; `VehicleUsageContext` from hub routes.
- [x] 6.3 Enforce at API layer: `createSharingOffer` MUST NOT create self-borrow links (`SelfBorrowForbiddenException`); unit tests for denial paths.
- [ ] 6.4 QA: document that current vehicle Maestro scenarios are **owner-path only**; Emprunteur E2E waits on relay fixtures (see `vehicle-module` tasks §14.4).
