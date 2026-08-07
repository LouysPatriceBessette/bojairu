## Implementation status (2026-07-14)

Owner-side **`vehicle`** module: **substantially implemented** on-device (local persistence, hubs, quick actions, consumption metrics, Maestro E2E on Android debug). **Gap resolution (owner):** pending corrections list, superseding replacement readings (journal preserves originals), retroactive session insert, applied journal entry (2026-07-01).

**Decisions (2026-07-14)** — see `design.md` § Decisions:
- **§8** auto-detection / auto-correction of incoherent tank-volume declarations → **deferred to a future release**; current release **trusts** user-declared tank/fuel volumes.
- **3.3** stale full-tank suggestion → **deferred to a future release**.
- **11.2 Emprunteur** path (notify Propriétaire) → tracked with **`vehicle-sharing-module`** / Emprunteur work (not current owner-module scope).
- **11.2 Propriétaire** in-app reminder after “Maintain reading, investigate later” → **deferred**; **journal entry alone** is acceptable for the current release.

**Still open for current release (non-relay):** Entitlement (**6.5**) waits on Google Play / StoreKit. Relay sync, cross-device notifications, and **boat** (§10.5 / §15) remain deferred as before. Legacy odometer-photo migration (**7.3b**) **won't do**.

**QA’ed (2026-07-14, Android Maestro / unit):**
- **1.3b** active-vehicle cap (unit: `vehicle_owned_active_cap_test.dart`; hub FAB hide at three active).
- **5.1–5.2** sale export / import — `./tool/melosw run qa:run-vehicle-sale-export-import` (`Scenario PASSED | vehicle_sale_export_import`).
- **5.3 Undo import** (full DB + public media revert; confirm dialog on detail) — `./tool/melosw run qa:run-vehicle-sale-export-import-undo` (`Scenario PASSED | vehicle_sale_export_import_undo`, artifacts `20260715T021251Z`).

**Active cap + deactivation (2026-07-14):** at most three **active** owned vehicles; irreversible deactivate frees a slot; FAB hidden at cap; same cap for QA seeds.
See `vehicle-sharing-module` for collaboration, relay sync, borrower metrics, usage-balance reconciliation (category expense ratios are **out of product**), and **`vehicle-usage-role-separation`** (owner vs borrower path; forbid self-borrow).

## 1. Domain model & storage

- [x] 1.1 Define Vehicle, VehicleUse, FuelPurchase, MaintenanceEvent, TrafficViolation entities with fixed owner
- [x] 1.2 Support vehicle kinds car, truck, motorcycle at initial release (`vehicle-domain-model`); **boat deferred** (§15)
- [x] 1.3 Implement local persistence scoped by owner; multi-vehicle per owner
- [x] 1.3b Enforce cap of three **active** owned vehicles per Propriétaire; irreversible deactivation frees a slot (`vehicle-domain-model`, implemented + QA’ed 2026-07-14)
- [x] 1.4 Implement audit-friendly odometer correction (flag + note)

## 2. Odometer & distance

- [x] 2.1 Owner use flow: start/end meter readings with photo rules (known-unchanged sentinel at unchanged session start; photo always at session end), distance derivation
- [x] 2.2 Monotonic / negative-gap flow per `vehicle-odometer-gap-attribution`
- [x] 2.3 Attribute uses to Propriétaire or Emprunteur Contact (sharing path)
- [x] 2.4a Positive/negative gap detection, confirm dialog, `unknown` gap record, verification journal entry, **Corrections en attente** (owner), resolution forms (correct previous/trigger reading, add/split sessions), **Correction appliquée** journal, `resolvedAt` + gap delete on resolve (2026-07-01)
- [ ] 2.4b Participant attribution dialog at detection time (Self / approved Emprunteur / Unknown) — product choice: auto-`unknown` + owner resolves later
- [ ] 2.4c Propriétaire notification when Emprunteur confirms gap; relay sync of superseding corrections to remote devices (deferred §5.2 / notifications)

## 3. Fuel & owner metrics

- [x] 3.1 Owner fuel purchase UI (full-tank flag, volume, odometer)
- [x] 3.2 Owner lifetime and windowed consumption per km (full-tank anchors)
- [ ] 3.3 Owner-only stale full-tank suggestion notification — **Deferred to a future release (2026-07-14)** (`vehicle-consumption-metrics`); not in current-release scope

## 4. Maintenance & violations

- [x] 4.1 Owner maintenance log UI
- [x] 4.2 Owner-only distance/time maintenance reminders (hub alert tiles; push notifications deferred)
- [x] 4.3 Violations log with responsibility state

## 5. Data portability

- [x] 5.1 Single-vehicle export (factual zip+JSON snapshot, module manifest) (implemented + QA’ed 2026-07-14, `qa:run-vehicle-sale-export-import`)
- [x] 5.2 Import as new owned vehicle on buyer device (implemented + QA’ed 2026-07-14, `qa:run-vehicle-sale-export-import`)
- [x] 5.3 Undo sale import while only rename/consult (revert DB + media; confirm dialog; affordance on vehicle detail) (implemented + QA’ed 2026-07-14, `qa:run-vehicle-sale-export-import-undo`)

## 6. Navigation, hubs & licensing

- [x] 6.1 Wire existing home tiles (`homeModuleVehicle`, `homeModuleVehicleSharing`) to hubs; replace coming-soon stub (`vehicle-app-home-navigation`)
- [x] 6.2 Vehicle module hub (`vehicle-hub-ui`): My vehicles cards, statistics entry, quick actions
- [x] 6.3 Maintenance alert tiles on owned vehicle cards (`vehicle-maintenance-alert-tiles`)
- [x] 6.4 Shared quick-action forms with local persist (`vehicle-quick-actions-ui`)
- [ ] 6.5 Gate owner features on effective `vehicle` entitlement (debug-only stub; store licensing deferred)

## 7. Vehicle sharing hub & legacy cleanup

- [x] 7.1 Vehicle sharing hub shell (`vehicle-sharing-hub-ui`) wired to same quick-action forms (forward routing)
- [x] 7.2 Remove prototype: `/car` route, `CarSharingPlanScreen`, `CarSharingPlanDraft` prefs (`vehicle-legacy-code-removal`)
- [x] 7.3a Enforce `user-owned-media-storage` on all new odometer and gallery writes (`storeVehicleMeterPhotoFromSource`, `storeVehicleGalleryPhotoFromSource` → public `Documents/Bojairũ/Car/…`)
- [x] 7.3b Migrate legacy app-private `vehicle_meter_photos/` references to public storage keys. **Won't do (2026-07-13):** there is **no** legacy corpus to migrate — the app is still early pre-release and has never been used except by the developer with disposable test data. Read fallback for old private paths may remain defensive; no migration job.

## 8. Consumption estimate validation & correction (fuel purchase anchors)

**Deferred to a future release (2026-07-14).** Current release **trusts** user-declared tank and fuel volumes: no auto-detection and no auto-correction of “incoherent” residual / after-fill declarations on fuel purchase save. Consumption metrics continue to use declared facts and full-tank anchors as entered.

**Future-release product rules (kept for when this ships):**

- **Correction + journal entry (immediate on save)** when the user’s declared **after-fill** level implies `before_fill + volume_purchased > tank_capacity` (physical overflow / impossible fill).
- **Owner notification** when estimated remaining volume before purchase vs. user-implied before-fill differs by **more than 10 L** — without necessarily triggering a consumption correction (e.g. close match like 22.5 L estimated vs. 20 L implied stays silent).
- **Journal placement:** merged **Odomètre et carburant** list (same sort-by-date stream as fuel purchases and meter readings).

- [ ] 8.1 **Detection on fuel purchase save**: compute estimated remaining before purchase; derive `before_fill_declared` from post-fill tank state (`isFullTank`, `tankFillFraction`, `volumeLiters`, `fuelTankCapacityLiters`). **Overflow** → correction path; **|estimate − before_fill_declared| > 10 L** → schedule owner notification only (no correction unless overflow). **(future release)**
- [ ] 8.2 **Odometer declaration**: use fuel purchase `meterReadingValue` and latest canonical odometer for distance since last anchor when estimating remaining fuel. **(future release)**
- [ ] 8.3 **Tank state declaration**: partial fill is **after** refill; `before_fill_declared = level_after − volume_added`. **(future release)**
- [ ] 8.4 **Consumption recalculation**: on overflow correction, re-anchor using corrected purchase for subsequent `VehicleConsumptionMetrics`. **(future release)**
- [ ] 8.5 **Journal entry** in **Odomètre et carburant**: card line 1 « Estimation de la consommation corrigée », line 2 date/time; detail with before/after narrative (distance window, total fuel in window, estimated vs. declared improbability, corrected consumption). **(future release)**
- [ ] 8.6 **Schema & persistence**: table or typed record for consumption correction events (vehicle id, purchase id, anchors, volumes, rates before/after). **(future release)**
- [ ] 8.7 **Owner notification**: push/local when gap > 10 L (Propriétaire only); wire after notification infrastructure for vehicle module. **(future release)**
- [ ] 8.8 **Tests**: overflow → correction + journal; 22.5 L vs 20 L implied (¾ on 80 L after 40 L) → no correction; >10 L gap without overflow → notification only (mock). **(future release)**

## 9. Oil change interval (vehicle-specific)

- [x] 9.1 Add-vehicle form: ×1000 km/miles blur validation, store as interval tenths on `oil` maintenance rule only (`other_fluids` journal-only). Boat hour-interval validation (50–500 h) deferred with §15.

## 10. Driving-condition consumption (road vehicles)

- [x] 10.1 End-of-use session form: route / city / traffic integer percents (sum = 100) under odometer photo; persist on `VehicleUses`
- [x] 10.2 Tank-to-tank NNLS fit for per-condition L/100 km (minimum two full-tank intervals with session mix data)
- [x] 10.3 Rolling window of five plein→plein intervals; reliability gradation (none / preliminary from 1st interval / reliable / very reliable) with user-facing messages
- [x] 10.4 Persist reliable+ estimate history (`VehicleConsumptionEstimateHistory`); show on statistics screen
- [ ] 10.5 Boat-specific operating-condition mix and consumption model (horometer / marine use patterns — **deferred**; see `design.md` § Decisions)

## 11. Vehicle notifications (deferred)

- [ ] 11.1 **Suspicious session-end tank (borrower)**: when an Emprunteur ends a session with the highest declared tank level after high mileage since the last fuel purchase and confirms the declaration anyway, notify the Propriétaire (relay/push when vehicle notification infrastructure ships). Tracked with Emprunteur / sharing work.
- [ ] 11.2a **Negative-gap maintained — Emprunteur path**: when an Emprunteur confirms a lower odometer reading, notify the **Propriétaire** (photos / investigate). **Out of current `vehicle` owner-module scope (2026-07-14)** — follow `vehicle-odometer-gap-attribution` (pending-corrections attention model). Positive session-start gaps from Emprunteurs already notify the Propriétaire via sharing session-gap notification (`vehicle-sharing-module` task 2.2 product flow).
- [x] 11.2b **Negative-gap maintained — Propriétaire path (current release)**: when the Propriétaire chooses **Maintain reading, investigate later**, persist the reading with negative-gap acknowledgment and the existing **journal entry**. **No dedicated in-app/push reminder** in the current release — reminder **deferred to a future release (2026-07-14)**; journal alone is acceptable.

## 12. Session-end distance plausibility guard

- [x] 12.0 **Session-end distance guard**: on session **end** reading, compare distance since the **last full-tank** meter (`end − lastFullTankMeter`; fallback `end − start` when no full-tank meter) to `(tankCapacity + fuelVolumesPurchasedAfterThatFullTank) × 100 / guardConsumption` — partial top-ups after the last plein count (e.g. 60 L + 20 L → 80 L); guard consumption = max(route, city, traffic) known values or 7.5 L/100 km; confirmation dialog before save when exceeded (`vehicle_odometer_gap_plausibility`, `confirmSuspiciousSessionEndDistanceBeforeSave`). Not applied at session start or standalone gap attribution.

## 13. Consumption estimation mode

- [x] 13.1 Vehicle setting: simple vs detailed consumption estimation mode (add vehicle + edit details); default detailed
- [x] 13.2 Simple mode: single L/100 km on hub card; reliability from same-mode plein→plein periods only
- [x] 13.3 Detailed mode: route / city / traffic breakdown when enough same-mode detailed sessions; borrower mix optional unless owner requires it (owner must use detailed)
- [x] 13.4 Mode transitions: carry reliable detailed average into simple; show simple estimate with insufficient-data message when switching to detailed
- [x] 13.5 FAQ: estimation limitations when not all users declare detailed driving mix (`helpFaqVehicleConsumptionEstimation`)
- [ ] 13.6 **Per-borrower detailed mix** (vehicle sharing module): switch to require route / city / traffic per emprunteur per vehicle; wire `shouldCollectDetailedDrivingMix` to sharing link instead of vehicle-level `requireDetailedDrivingMixForBorrowers`

## 14. Android E2E QA (Maestro, debug Android)

Single-device scenarios after programmatic seed + clock push (`docs/qa-android-e2e.md`). Multi-device sharing and relay flows remain manual or future scenarios.

- [x] 14.1 Scenario manifests + flows: `vehicle_add`, `vehicle_fuel_purchase`, `vehicle_use_session`, `vehicle_session_start_gap`, `vehicle_standalone_meter_gap`, `vehicle_consumption` (`qa/scenarios/`, `qa/flows/`).
- [x] 14.2 Vehicle seed helpers + postconditions (`qa_vehicle_seed_helpers.dart`, `qa_vehicle_consumption_seed.dart`, `qa_scenario_seed.dart`, matching tests).
- [x] 14.3 Hub semantics for consumption reliability and per-condition breakdown (`qa_vehicle_semantics.dart`, `vehicle_module_hub_screen.dart`).
- [x] 14.3b Sale export → import Maestro (`qa:run-vehicle-sale-export-import`; QA’ed 2026-07-14).
- [x] 14.3c Sale import undo Maestro (`qa:run-vehicle-sale-export-import-undo`; QA’ed 2026-07-14, `PASSED` `20260715T021251Z`).
- [ ] 14.4 Sharing-hub and multi-role scenarios (invite, accept, borrower session, gap notify).

## 15. Boat vehicles (deferred from initial release)

**Decision (2026-07-06):** initial store release supports **car, truck, motorcycle** only. Boat registration, horometer UX, hour-based maintenance preview, and boat consumption (§10.5) ship in a **future release**. Domain enum may retain `boat` for forward compatibility; v1 product surfaces must not offer boat until this section is delivered.

- [x] 15.1 Hide **boat** in add-vehicle kind picker until boat release ships (`VehicleKind.userSelectableKinds`)
- [ ] 15.2 Horometer labels, session forms, hub cards (engine hours), and sharing paths per deferred `odometer-logging` / `vehicle-domain-model` requirements
- [ ] 15.3 Hour-based maintenance alert preview and oil-change interval validation (50–500 h)
- [ ] 15.4 Boat consumption model (depends on §10.5)
