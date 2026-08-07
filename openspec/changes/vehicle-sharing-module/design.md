## Context

Two-module licensing model using product roles **Propriétaire** and **Emprunteur**:

| Role | Subscriptions (store) | Functional roles |
| --- | --- | --- |
| **Propriétaire** | `vehicle` + `vehicle-sharing` | EV + PP |
| **Emprunteur** | `vehicle-sharing` only | PE |
| **Propriétaire solo** | `vehicle` only | EV |

See `vehicle-sharing-licensing-and-delinquency` for EV/PP/PE delinquency rules and `vehicle-module-licensing` for the 2-week **`vehicle`** trial. **`vehicle-sharing` has no trial period.**

## Goals / Non-Goals

**Goals:**

- Propriétaire-initiated offer of **one specific vehicle** to a connected Contact; Emprunteur accepts (no reverse fleet browse).
- Exactly two parties per link; Propriétaire deemed to have accepted their own offer.
- Emprunteur writes usage facts on the Propriétaire's canonical vehicle record; no session-scoped fuel entry.
- Both parties may record **full-tank anchors**.
- Scoped visibility: Emprunteur metrics and usage-balance reconciliation **only for their usage windows**.
- Single reconciliation surface: **usage balance** (not housing-style category ratios).

**Non-Goals:**

- Advance reservations (wish list).
- Emprunteur maintenance reminders or lifetime owner metrics.
- Automatic ownership transfer on sale (sale export strips sharing metadata — see `vehicle-data-portability`).
- Category expense ratios / propose-accept allocation for Fuel, Maintenance, Payments, or Violations (`vehicle-expense-sharing` out of product).
- At-save gap attribution picker notifying the attributed peer (gaps stay Unknown until Propriétaire pending-corrections resolution).

## Decisions

- **Usage role separation (canonical spec: `vehicle-usage-role-separation`)**
  - **Decision**: on each installation, **one local database** holds owner-path and borrower-path vehicle data. The active role is chosen by **navigation** (Vehicle hub vs Vehicle sharing hub), not by splitting storage.
  - **Decision**: the local user MUST NEVER be Emprunteur on a vehicle they own — including QA seeds and E2E tests.
  - **Decision**: **Accessible vehicles** are owned by participants on **other installations**; cross-participant sharing requires **relay**. An empty accessible list with only self-owned vehicles locally is correct until sync delivers external owners' vehicles.
  - **Rationale**: prevents conflating "same DB on one phone" with "sharing works without relay across Monica / Louys / Roberr".

- **Propriétaire-only offer path**
  - **Decision**: only the Propriétaire can offer a **specific** vehicle; Emprunteurs cannot browse a Propriétaire's fleet to request access.
  - **Rationale**: avoids ambiguous multi-vehicle discovery; matches Contacts-based invite flow.

- **Two parties; Propriétaire pre-accepted**
  - **Decision**: each link is pairwise; sending an offer counts as Propriétaire acceptance.
  - **Rationale**: only the Emprunteur must accept responsibilities.

- **Full-tank anchors by either party; no session fuel**
  - **Decision**: Propriétaire or Emprunteur may mark full-tank purchases; Emprunteurs do not log liters per session.
  - **Rationale**: session-level consumption estimates are unreliable; odometer readings are factual.

- **Three functional licenses in a relationship (EV, PP, PE)**
  - **Decision**: documented in `vehicle-sharing-licensing-and-delinquency` with 1-week grace per module instance.
  - **Rationale**: independent delinquency on owner vs borrower devices.

- **Boat horometer deferred from initial release (2026-07-06)**
  - **Decision**: initial **`vehicle-sharing`** release supports **land vehicles** (odometer) only. **Boat** with **engine hour meter (horomètre)** is deferred to a future release alongside `vehicle-module` boat work — see `vehicle-module` `design.md` § Decisions.
  - **Future direction**: when boat ships, boats use engine hour meter readings; land vehicles use odometer. See deferred `odometer-logging` requirements and user-facing terminology dictionary.

## Risks / Trade-offs

- **[Emprunteur submits while Propriétaire PP disabled]** → Mitigation: clear error to Emprunteur; local queue may hold until restored or fail fast per spec.
- **[Borrower logs without owner online]** → Mitigation: local-first queue + relay sync; monotonic meter rules on merge.

## UI architecture (first-pass guide)

Parallel hub to `vehicle-hub-ui`. Separate **Vehicle sharing** affordance on app home per `vehicle-app-home-navigation`. See `vehicle-sharing-hub-ui` and shared `vehicle-quick-actions-ui`.
