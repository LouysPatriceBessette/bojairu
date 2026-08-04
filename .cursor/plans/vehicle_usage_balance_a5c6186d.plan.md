---
name: Vehicle usage balance
overview: Implement the informative running usage-balance formula (owner + borrower, identical math), with navigation entry points you defined, gated on reliable consumption and a volume-weighted fuel price from the last 10 purchases—without the future payment/settlement flow.
todos:
  - id: spec-window-formula
    content: "Update OpenSpec usage-metrics: formula, reliability gate, P=last 10 weighted, running window from acceptedAt + future payment reset"
    status: completed
  - id: calc-service
    content: Pure VehicleUsageBalance calculator + unit tests (gates, gaps, T=0, tenths, contact identity)
    status: completed
  - id: owner-nav
    content: "Owner vehicle detail: Soldes des emprunteurs list + detail route"
    status: completed
  - id: borrower-nav
    content: "Borrower Autres actions: Solde d'utilisation + shared detail breakdown UI"
    status: completed
  - id: l10n-qa
    content: ARB strings + qa semantics for new tiles/screens
    status: completed
isProject: false
---

# Vehicle usage balance (running reconciliation)

## Confirmed formula (locked)

```text
SOLDE = (C/100)×D×P − (A+E) + (D×T)
```

| Symbol | Meaning | Source |
| --- | --- | --- |
| **C** | L/100 km | Current vehicle estimation mode (`VehicleConsumptionMetrics`); vehicle-wide |
| **D** | km (tenths preserved, no premature rounding) | Sessions + odometer gaps attributed to that borrower; **exclude** `unknown` |
| **P** | $/L volume-weighted | Last **10** fuel purchases on the vehicle (any recorder) with usable liters |
| **A** | $ fuel paid by this borrower | `FuelPurchases` where `recordedByContactId` = that borrower |
| **E** | $ maintenance by this borrower | `MaintenanceEvents` where `recordedByContactId` = that borrower |
| **T** | $/km compensation | `ratePerKmMinor` on the sharing link (`T ≥ 0`; if `0`, compensation term is 0) |

- Sign: **> 0** owed to Propriétaire; **< 0** credit for Emprunteur.
- Currency: **not managed** — all amounts assumed same currency.
- Violations / lease payments: **out of formula** (informative declaration only).
- This is **informative running** math; propose/accept ratios (`vehicle-expense-sharing`) and real **payment confirmation** are **out of scope** for this cut.

## Window (#11)

```text
windowStart = lastConfirmedPaymentAt ?? link.acceptedAt
windowEnd   = now
```

- **This cut:** no payment table → window = from `acceptedAt` (fallback: link creation / activation if `acceptedAt` null) through now.
- **Spec addition (required):** when the future payment mechanism confirms a payment, `windowStart` resets to that confirmation time (running balance after settlement).
- Facts (`D`, `A`, `E`) filtered to events whose timestamps fall in `[windowStart, now]`.
- **P** and **C** remain vehicle-level (not window-truncated for C; P = last 10 purchases vehicle-wide as answered).

## Gate: no displayable balance

Unavailable (same both roles) when **either**:

1. Consumption reliability is not `reliable` or `veryReliable`, or `hasSufficientData` is false; or
2. No usable fuel purchases to compute **P** (see #8 below).

Entry tiles can still open a detail that explains *why* (same copy both sides). Do not invent a fake number.

## Answer on #8 (liters + price) — important

| Layer | Reality |
| --- | --- |
| **UI save** ([`vehicle_quick_action_screens.dart`](mobile/lib/screens/vehicle/vehicle_quick_action_screens.dart)) | Cost **and** volume are both required to enable Save today |
| **OpenSpec** ([`fuel-purchase-tracking`](openspec/changes/vehicle-module/specs/fuel-purchase-tracking/spec.md)) | Volume is listed as **optional** |
| **DB** ([`vehicle_tables.dart`](mobile/lib/db/vehicle_tables.dart)) | `volumeLiters` is **nullable**; transport import may store null |

**Plan rule (no invention):** for **P**, only include purchases with `costMinor` set and `volumeLiters != null && volumeLiters > 0`. Take the **10 most recent** such rows by `purchasedAt`. If zero usable rows → no balance. Do **not** silently invent liters.

Tightening the OpenSpec/DB to make volume mandatory is a **separate** follow-up unless you ask for it in the same cut.

## #7

Only volume-weighted average makes sense:  
`P = Σ cost / Σ liters` over those ≤10 purchases. No simple mean of unit prices.

## Navigation (as specified; minimal UI, not visual polish)

**Propriétaire** — [`vehicle_detail_screen.dart`](mobile/lib/screens/vehicle/vehicle_detail_screen.dart): after Dommage/infraction, divider → **Soldes des emprunteurs** → divider → Journaux…

- List screen: one tile per sharing link (including **revoked**; delete-history flow later).
- Tap → detail for that borrower (identical breakdown widget).

**Emprunteur** — [`vehicle_sharing_other_actions_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_other_actions_screen.dart): after Dommage, divider → **Solde d'utilisation** → divider → Journaux → same detail widget for self.

Routes + ARB strings + QA semantics ids following existing vehicle/sharing patterns.

## Pure calculation layer (core)

New module under e.g. [`mobile/lib/vehicle/sharing/`](mobile/lib/vehicle/sharing/) (name TBD, e.g. `vehicle_usage_balance.dart`):

- Inputs: vehicle, link, contact id for “this borrower”, purchases, maintenance, uses, gaps, consumption snapshot.
- Resolve borrower identity carefully (owner DB uses peer `Contact.id`; borrower DB may use self sentinel — match existing sharing attribution helpers).
- Output: structured breakdown (`C`, `D`, `P`, `A`, `E`, `T`, estimated fuel cost, compensation, net) **or** `unavailable(reason)`.
- Money in **minor units** where possible; convert `ratePerKmMinor × D` and `(C/100)×D×P` with an explicit final rounding rule at the money boundary (same as rest of app display).
- Unit tests covering: T=0, negative/positive net, unknown gaps excluded, reliability gate, empty P, tenths on D, revoked link still computable.

## Spec updates (this cut)

- Amend [`vehicle-sharing-usage-metrics`](openspec/changes/vehicle-sharing-module/specs/vehicle-sharing-usage-metrics/spec.md): running informative balance formula, reliability gate, P from last 10, window from acceptance until payment exists.
- Note that **payment-confirmed window reset** is specified as future dependency (stub field / generation later).
- Mark tasks 3.x partially addressed as “informative running balance”; leave 4.x expense-sharing ratios **deferred** relative to this formula.
- Do **not** implement payment propose/confirm UI.

## Explicitly out of scope

- Payment / settlement confirmation flow
- Delete revoked-borrower history
- Multi-currency
- Violations/payments in the balance
- Hub card owed summary (optional later; not in your screenshot cut)
- Visual design polish beyond matching existing ListTile / Divider patterns

## Verification

- `./tool/flutterw analyze --fatal-infos` on touched Dart
- Unit tests for the pure calculator
- Skip full `flutter test` suite only if clearly unaffected beyond new tests + analyze; otherwise run targeted + full per project rule when logic ships
