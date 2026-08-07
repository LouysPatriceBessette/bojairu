## Why

Sharing a vehicle fairly requires collaboration: owners invite borrowers, borrowers log usage, and participants settle the **usage balance** (rate × distance, fuel anchors, maintenance compensation, freeze/transfers). That collaboration is licensed separately from **`vehicle`** so a participant who only **borrows** (participant B) pays less than an owner (participant A) who maintains the asset and shares it.

An owner who wants to **offer** their vehicle for sharing needs **both** `vehicle` and `vehicle-sharing`. A borrower needs only `vehicle-sharing` plus **acceptance** by the vehicle owner. A Propriétaire may own up to **three** vehicles and have up to **five** distinct Emprunteurs counting toward the product cap; an Emprunteur may use multiple vehicles (same or different Propriétaires). Sharing one's own vehicle does not prevent borrowing another owner's vehicle.

This change **supersedes** the sharing, allocation, and group semantics of `car-sharing-module`. Reservations are **deferred** (wish list). **Housing-style category expense ratios are out of product** (see `vehicle-expense-sharing` scope note).

## What Changes

- Introduce the **`vehicle-sharing`** product module (identifier `vehicle-sharing`).
- Model **sharing relationships** per vehicle: owner (requires `vehicle` + `vehicle-sharing`) and approved borrowers (requires `vehicle-sharing` only).
- Allow **multiple borrowers per vehicle** and **multiple vehicles per borrower** (same or different owners), subject to Propriétaire caps (**three** owned vehicles, **five** distinct Emprunteurs — see `vehicle-sharing-domain-model`).
- Borrowers **add usage data** (odometer sessions, usage-scoped fuel facts) on the owner's vehicle record.
- **Borrower-visible metrics**: usage statistics (distance, fuel) limited to their own usage windows — not the vehicle's lifetime history.
- **Reconciliation**: both parties use the **usage balance** for the Emprunteur's window (owner sees per-Emprunteur balances). No second category-ratio allocator.
- Owner acceptance gate before a borrower can log usage on a vehicle.

## Capabilities

### New Capabilities

- `vehicle-sharing-domain-model`: Sharing links, owner/borrower roles, acceptance, multi-vehicle / multi-borrower rules.
- `vehicle-sharing-usage-logging`: Borrower (and owner) use sessions on a shared vehicle; Unknown-first gap handling and Propriétaire pending-corrections resolution per `vehicle-odometer-gap-attribution`.
- `vehicle-sharing-usage-metrics`: Borrower-scoped distance and fuel statistics; informative usage balance + freeze/transfers.
- `vehicle-expense-sharing`: **Out of product** — retained as a scope note only (no category ratios).
- `vehicle-sharing-licensing-and-delinquency`: EV/PP/PE entitlement roles, 1-week grace, delinquency effects per role.
- `vehicle-sharing-hub-ui`: Accessible vehicles, statistics, quick actions (forward routing), offer path.
- `vehicle-usage-role-separation`: One DB per installation; owner vs borrower path by navigation and vehicle ownership; forbid self-borrow; accessible vehicles require other installations + relay.

### Modified Capabilities

<!-- None at product-wide level. Depends on `vehicle-domain-model` and `vehicle` entitlement for owners who share. -->

## Impact

- **Licensing**: dependency rules added in `per-module-licensing-and-bundles` (`module-subscription-dependencies`).
- **Relay / sync**: sharing proposals and usage facts sync under `vehicle-sharing` scope.
- **Contacts**: borrowers and owners are connected Contacts; see `contacts-module-integration`.
- **Mobile UX**: invite/accept flows, borrower dashboard per shared vehicle, usage-balance review.
