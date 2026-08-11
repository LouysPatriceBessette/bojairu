## 1. Specification and store-mapping reference

- [x] 1.1 Confirm the canonical module identifier list at launch (e.g., `housing`, `vehicle`, `vehicle-sharing`) and document the rule for adding new modules. *(`docs/store-mapping.md` — 2026-08-08.)*
- [x] 1.2 Author a `docs/store-mapping.md` reference that lists module → Apple subscription group identifier and module → Google Play subscription product identifier (placeholders until products are created). *(`docs/store-mapping.md` — Play proposed ids; Apple TBD; Console create still pending.)*
- [x] 1.3 Document the bundle policy (which combinations are sold) and define the bundle product identifiers per platform. *(Four launch bundles + standalones in `docs/store-mapping.md`.)*
- [x] 1.4 Cross-link this change with `licensing-trial-and-plan-entitlement` so the housing lifecycle remains the canonical instance of the per-module model. *(Cross-refs in `docs/store-mapping.md`.)*

## 2. App entitlement layer

- [x] 2.1 Introduce a module identifier enumeration in the app code (housing first, vehicle deferred). *(`AppModuleId` — 2026-08-08.)*
- [x] 2.2 Refactor the entitlement state holder so it maintains one effective state per module (rather than a single global state). *(`ModuleEntitlementController`.)*
- [x] 2.3 Implement the "most favorable source wins" rule combining per-module receipts, bundle receipt projection, and local lifecycle, with a documented deterministic evaluation order. *(`ModuleEntitlementEvaluator`.)*
- [x] 2.4 Implement receipt validation paths that route per-module and bundle receipts into the correct module's effective state. *(`ReceiptToCandidates` — local only; no server upload in étape 1.)*
- [x] 2.5 Persist captured receipt metadata per module (Apple identifiers, Google Play identifiers) consistent with `store-product-mapping-per-module`. *(`LocalStoreReceiptStore`.)*
- [x] 2.6 Implement `module-subscription-dependencies` (block owner-side sharing unless both `vehicle` and `vehicle-sharing` are entitled). *(`VehicleModuleAccess.canOfferSharing`.)*

## 3. Module enable/disable and isolation

- [ ] 3.1 Add a per-module enable/disable toggle in settings, with copy explaining the difference between in-app disable and store cancellation.
- [ ] 3.2 Wire the disable toggle to stop module-scoped relay traffic for that module while leaving local data intact.
- [ ] 3.3 Implement re-enable behavior that resumes relay subscriptions without resurrecting expired proposals.
- [ ] 3.4 Verify on-device storage scoping ensures one module's queries never read another module's data.

## 4. Per-module export

- [ ] 4.1 Generalize the export action so each module exposes its own export, governed only by its own entitlement state.
- [ ] 4.2 Add module identification to export output (filename, header, or manifest entry).

## 5. Store-side provisioning (when a module is actually about to ship)

- [ ] 5.1 For the housing module: create its dedicated Apple subscription group and its Google Play subscription product (and base plans) when housing licensing is implemented (this is the existing `licensing-trial-and-plan-entitlement` work; this change confirms the layout).
- [ ] 5.2 Document the resulting identifiers in `docs/store-mapping.md`.
- [ ] 5.3 For future bundles: create the dedicated bundle subscription group on Apple and the bundle subscription product on Google Play; document identifiers.

## 6. Tests

- [x] 6.1 Unit tests for the "most favorable source wins" evaluation, including ties and overlap between standalone and bundle receipts. *(`module_entitlement_evaluator_test.dart`, `receipt_to_candidates_test.dart`.)*
- [x] 6.2 Unit tests for per-module state machine isolation (a delinquency on one module does not transition state on another). *(`module_entitlement_controller_test.dart`.)*
- [ ] 6.3 Unit tests for disable/enable behavior on relay traffic (no module-scoped envelopes generated while disabled; expired inbound proposals are not resurrected at re-enable).
- [ ] 6.4 Integration test verifying export availability under various per-module entitlement combinations (active-paid, read-only, delinquent).
- [x] 6.5 Documentation test that confirms `docs/store-mapping.md` lists each currently-shipping module and bundle. *(`store_product_catalog_test.dart` mirrors store-mapping ids.)*

## 7. Future — license catalog lifecycle procedure

- [ ] 7.1 Author an exact, complete procedure for **adding and removing** licenses (standalone products, bundles, and any future **free** license type that does not exist yet): store Console steps, `docs/store-mapping.md` / catalog / display-name mapping, entitlement projection, and app UI impact. Deferred to a later release; not part of the Licenses screen UI redesign.
