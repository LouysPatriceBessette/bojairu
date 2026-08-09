# Store product mapping (modules and bundles)

This document is the canonical reference for **module → store subscription** identifiers and the **bundle policy** for Bojairũ.

Product semantics: OpenSpec change `per-module-licensing-and-bundles` (`store-product-mapping-per-module`, `bundle-product-mapping`, `module-subscription-dependencies`). Housing plan lifecycle remains defined by `licensing-trial-and-plan-entitlement`.

**Status (2026-08-08):** Google Play catalog **created** in [Google Play Console](https://play.google.com/console) for `app.incoherences.bojairu` — seven subscriptions, each with an active auto-renewing base plan `monthly` at **CA$4.00** / month. Identifiers below match Console. Apple App Store rows remain placeholders only (implementation and QA deferred).

**Application id (Play):** `app.incoherences.bojairu` (dev builds use `.dev` suffix; subscription products are attached to the Play app that sells them — use the production application id for production catalog).

---

## Canonical modules at launch

| Module id (code) | User-facing role (summary) |
| --- | --- |
| `housing` | Housing / roommate plans |
| `vehicle` | Owned vehicles (Propriétaire solo use) |
| `vehicle-sharing` | Vehicle sharing; Emprunteur may hold this alone; lending out as Propriétaire also requires `vehicle` |

### Rule for adding a new module later

1. Choose a new stable module id (lowercase, hyphenated).
2. Add a **new** Google Play subscription product (do not reuse an existing module’s `productId`).
3. Add a **new** Apple subscription group when shipping on iOS (do not put two modules in the same group).
4. Update this document and the bundle policy **before** selling the module.
5. Do not rename store identifiers after the module has production purchases.

---

## Bundle policy (what we sell)

Only the combinations listed here are sold as bundle SKUs. Do not invent additional combinations in the stores without updating this policy first.

| Bundle policy id | Included modules | Notes |
| --- | --- | --- |
| `housing_vehicle_sharing` | `housing`, `vehicle-sharing` | Does **not** unlock Propriétaire lending; lending still needs `vehicle` as well |
| `vehicle_vehicle_sharing` | `vehicle`, `vehicle-sharing` | Typical Propriétaire who shares out vehicles |
| `housing_vehicle` | `housing`, `vehicle` | No sharing-out without also entitling `vehicle-sharing` |
| `all_modules` | `housing`, `vehicle`, `vehicle-sharing` | Full set |

**Not sold as bundles:** every other 2- or 3-module combination beyond the table above.

**Standalone products:** each of `housing`, `vehicle`, and `vehicle-sharing` remains purchasable alone.

**Dependency (product, not store):** offering a vehicle as Propriétaire requires effective entitlement on both `vehicle` and `vehicle-sharing` (via standalones and/or a bundle that covers both). Borrowing requires `vehicle-sharing` only.

**Receipt projection:** a valid bundle receipt grants at least `active-paid` on every included module for as long as the bundle is valid. If a standalone and a bundle both cover a module, the **most favorable** source wins (see `module-entitlement-model`).

**Overlap:** buying a bundle does not automatically cancel existing standalone subscriptions; the user manages cancellations in the store’s subscription UI.

---

## Google Play — subscription products

Layout rule: **one Play subscription product per module**, plus **one Play subscription product per bundle**. Each product exposes a single **auto-renewing monthly** base plan at launch (no annual base plan for now).

Prices: **CA$4.00** / month for every product below (same amount for standalones and bundles; set in Console 2026-08-08). Primary listing currency: CAD.

### Per-module products

| Module | `productId` | Base plan id | Base plan | Price | Live status |
| --- | --- | --- | --- | --- | --- |
| `housing` | `bojairu.housing` | `monthly` | Monthly, auto-renewing | CA$4.00 | Created 2026-08-08 |
| `vehicle` | `bojairu.vehicle` | `monthly` | Monthly, auto-renewing | CA$4.00 | Created 2026-08-08 |
| `vehicle-sharing` | `bojairu.vehicle_sharing` | `monthly` | Monthly, auto-renewing | CA$4.00 | Created 2026-08-08 |

### Bundle products

| Bundle policy id | `productId` | Base plan id | Included modules | Price | Live status |
| --- | --- | --- | --- | --- | --- |
| `housing_vehicle_sharing` | `bojairu.bundle.housing_vehicle_sharing` | `monthly` | `housing`, `vehicle-sharing` | CA$4.00 | Created 2026-08-08 |
| `vehicle_vehicle_sharing` | `bojairu.bundle.vehicle_vehicle_sharing` | `monthly` | `vehicle`, `vehicle-sharing` | CA$4.00 | Created 2026-08-08 |
| `housing_vehicle` | `bojairu.bundle.housing_vehicle` | `monthly` | `housing`, `vehicle` | CA$4.00 | Created 2026-08-08 |
| `all_modules` | `bojairu.bundle.all_modules` | `monthly` | `housing`, `vehicle`, `vehicle-sharing` | CA$4.00 | Created 2026-08-08 |

### Play Console provisioning checklist (operator)

In **Google Play Console** → the Bojairũ app (`app.incoherences.bojairu`) → **Monetize with Play** → **Products** → **Subscriptions**:

1. [x] Create each of the seven subscription products using the `productId` values above.
2. [x] For each product, add one **base plan** `monthly` (auto-renewing, monthly billing period).
3. [x] Set prices (CA$4.00 / month; Console may convert to other regions).
4. [x] Activate the base plans; configure license testers for purchase tests.
   - **Where (account-level, not inside the app):** Google Play Console → leave the app → **Settings** → **License testing** (FR: **Paramètres** → **Test de licence**).
   - **Not** Monetize → Monetization setup, and **not** Testing → Internal testing → Testers.
   - **Done:** list **Piste Interne** selected (2026-08-08); reconfirmed with device Play account match (2026-08-09). Do **not** ask the operator to re-verify this unless the phone Google account changes or a purchase is charged for real.
5. [x] Update the **Live status** column in this file to `Created` and note the date (2026-08-08).

Creating these products does **not** by itself change behavior of already-installed APKs; the app must query these ids (billing step 1).

---

## Apple App Store — placeholders (deferred)

Apple requires **one subscription group per module** and **a dedicated group per bundle product**. Identifiers below are placeholders until App Store Connect products are created.

| Kind | Module / bundle | Placeholder subscription group | Placeholder product id |
| --- | --- | --- | --- |
| Module | `housing` | `bojairu.housing` (TBD) | `bojairu.housing.monthly` (TBD) |
| Module | `vehicle` | `bojairu.vehicle` (TBD) | `bojairu.vehicle.monthly` (TBD) |
| Module | `vehicle-sharing` | `bojairu.vehicle_sharing` (TBD) | `bojairu.vehicle_sharing.monthly` (TBD) |
| Bundle | `housing_vehicle_sharing` | `bojairu.bundle.housing_vehicle_sharing` (TBD) | same + `.monthly` (TBD) |
| Bundle | `vehicle_vehicle_sharing` | `bojairu.bundle.vehicle_vehicle_sharing` (TBD) | same + `.monthly` (TBD) |
| Bundle | `housing_vehicle` | `bojairu.bundle.housing_vehicle` (TBD) | same + `.monthly` (TBD) |
| Bundle | `all_modules` | `bojairu.bundle.all_modules` (TBD) | same + `.monthly` (TBD) |

---

## Cross-references

- OpenSpec: `openspec/changes/per-module-licensing-and-bundles/`
- Housing licensing lifecycle: `openspec/changes/licensing-trial-and-plan-entitlement/`
- Roadmap mention: `docs/development-roadmap.md` (modular licensing section)
- Entitlement server Phase B (Play receipt validation): `openspec/changes/entitlement-server/tasks.md` item 5.2
