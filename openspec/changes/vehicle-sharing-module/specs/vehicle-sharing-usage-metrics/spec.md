## ADDED Requirements

### Requirement: Borrower sees usage statistics only for their windows
On a borrower's device, the system SHALL display distance and fuel-related statistics **only** for usage attributed to that borrower (per use session and selectable windows). The borrower MUST NOT see the vehicle's full lifetime owner metrics.

#### Scenario: Borrower metrics exclude others' uses
- **WHEN** borrower B opens statistics for a shared vehicle also used by D
- **THEN** B sees totals for B's sessions only
- **THEN** B does not see D's distance totals or the owner's full lifetime consumption chart

### Requirement: Informative running usage balance (same formula both roles)
The system SHALL compute an **informative** running usage balance for each Propriétaire–Emprunteur sharing link with the locked formula:

```text
SOLDE = (C/100)×D×P − (A+E) + (D×T)
```

Where:

- **C** = vehicle-wide average consumption in L/100 km from the vehicle's **current** consumption estimation mode
- **D** = distance in km attributed to that Emprunteur in the running window (closed use sessions + odometer gaps attributed to that Emprunteur; tenths preserved until money rounding)
- **P** = volume-weighted average fuel price per litre from the **10 most recent** fuel purchases on the vehicle that have both a positive `volumeLiters` and a cost (any recorder)
- **A** = sum of fuel purchase costs recorded by that Emprunteur in the running window
- **E** = sum of maintenance costs recorded by that Emprunteur in the running window
- **T** = usage compensation rate per km from the sharing link (`ratePerKmMinor`; MUST be ≥ 0; when 0 the compensation term is 0)

Sign: **SOLDE > 0** means amount owed to the Propriétaire; **SOLDE < 0** means a credit for the Emprunteur.

The **same** formula and breakdown SHALL be shown on the Propriétaire path (per Emprunteur) and on the Emprunteur path (self). This balance is **informational**; it does **not** record payments. Propose/accept category ratios (`vehicle-expense-sharing`) remain a separate capability.

Violations and lease/payment expenses MUST NOT enter this formula.

#### Scenario: Positive balance owed to owner
- **WHEN** estimated fuel cost plus compensation exceeds the Emprunteur's fuel and maintenance payments in the window
- **THEN** the displayed balance is positive (owed to Propriétaire)

#### Scenario: Zero compensation rate
- **WHEN** the link's `ratePerKmMinor` is 0
- **THEN** the compensation term contributes 0 to the balance

### Requirement: Running window from acceptance until confirmed payment
The running window for **D**, **A**, and **E** SHALL be:

```text
windowStart = lastConfirmedUsagePaymentAt ?? link.acceptedAt (else link.createdAt)
windowEnd   = now
```

**C** and **P** remain vehicle-level (not limited to the running window for C; P uses the last 10 usable purchases vehicle-wide).

When a future **usage-payment confirmation** mechanism records a confirmed payment between the parties for this link, `windowStart` SHALL reset to that confirmation time. Until that mechanism exists, `lastConfirmedUsagePaymentAt` is absent and the window starts at acceptance (or link creation).

#### Scenario: Window starts at acceptance before any payment
- **WHEN** no confirmed usage payment exists for the link
- **THEN** attributed distance and Emprunteur costs are included from `acceptedAt` (or `createdAt` if acceptance timestamp is missing) onward

### Requirement: Balance unavailable without reliable consumption or fuel price
The system MUST NOT display a numeric usage balance when either:

1. Vehicle consumption is not at reliability **`reliable`** or **`veryReliable`** (or has insufficient data for an estimate), or
2. No usable fuel purchases exist to compute **P** (purchases with positive liters and cost)

Both roles SHALL see the same unavailable state with an explanation. Entry tiles MAY remain navigable.

#### Scenario: Preliminary consumption only
- **WHEN** consumption reliability is `preliminary` or `none`
- **THEN** the usage balance is unavailable (no invented number)

#### Scenario: No usable fuel purchases for P
- **WHEN** the vehicle has zero fuel purchases with both positive volume and cost
- **THEN** the usage balance is unavailable

### Requirement: Unknown-attributed gaps excluded from borrower owed inputs
Distance from gap records attributed to **Unknown** MUST NOT be included when computing an Emprunteur's attributed usage or owed share for reconciliation. The Propriétaire effectively carries Unknown usage in allocation math until they revise attribution to a named participant (see `vehicle-odometer-gap-attribution`).

#### Scenario: Borrower reconciliation ignores Unknown gaps
- **WHEN** borrower B opens reconciliation for a window containing an Unknown-attributed gap
- **THEN** that gap distance is excluded from B's attributed totals
- **THEN** the breakdown explains that Unknown gaps are Propriétaire-side until revised

### Requirement: Owner lists Emprunteur balances including revoked links
The Propriétaire SHALL be able to open a per-Emprunteur balance list for a vehicle that includes **active** and **revoked** links that have been accepted. Deleting historical data for a revoked Emprunteur requires a separate flow (out of scope for the informative balance cut).

#### Scenario: Revoked Emprunteur still listed
- **WHEN** the Propriétaire opens borrower balances after revoking Emprunteur B
- **THEN** B remains listed and the running balance for B remains computable from retained facts

### Requirement: Handle insufficient borrower data
The system MUST handle insufficient borrower-scoped data without showing misleading metrics.

#### Scenario: Borrower with no uses in window
- **WHEN** a borrower has zero attributed distance in the running window but C and P are available
- **THEN** the balance MAY still be shown (D = 0) using A, E, and the formula

### Requirement: Calendar-window ratio allocation (deferred relative to informative balance)
Category ratio allocation and calendar-month reconciliation UI from earlier drafts (`vehicle-expense-sharing`) remain specified separately and are **not** required for the informative running balance above.

#### Scenario: Borrower opens reconciliation for a month (deferred)
- **WHEN** borrower B opens a future calendar-window allocation view
- **THEN** included uses and fuel facts are limited to B's attributed sessions intersecting that window
- **THEN** the breakdown is sufficient to compute B's share per active ratios
