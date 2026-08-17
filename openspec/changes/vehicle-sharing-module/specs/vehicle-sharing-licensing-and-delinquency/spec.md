## ADDED Requirements

### Requirement: Three entitlement roles in a two-party sharing relationship
A sharing relationship between a **Propriétaire** (owner) and an **Emprunteur** (borrower) involves three functional entitlement roles, mapped to store modules as follows:

| Role code | Meaning | Store module | Device |
| --- | --- | --- | --- |
| **EV** | Vehicle entity (owned vehicle data) | `vehicle` | Propriétaire |
| **PP** | Propriétaire-side sharing (offer, receive borrower data) | `vehicle-sharing` | Propriétaire |
| **PE** | Emprunteur-side sharing (accept offer, submit usage data) | `vehicle-sharing` | Emprunteur |

`vehicle-sharing` is one purchasable module; **PP** and **PE** are role-specific gates on the Propriétaire and Emprunteur devices respectively. **`vehicle-sharing` has no trial period and no grace period.** Without a paid `vehicle-sharing` license, sharing actions are unavailable.

### Requirement: Vehicle module grace does not grant sharing-out actions
When the Propriétaire's **`vehicle`** license is in payment-default grace, existing shares remain active and borrower envelopes are still applied. The Propriétaire SHALL NOT invite, revoke, or reactivate shares unless **both** `vehicle` and `vehicle-sharing` are **active-paid** (not trial, not grace).

#### Scenario: Grace on vehicle keeps inbound borrower facts
- **WHEN** the Propriétaire's `vehicle` subscription is in delinquent-grace and `vehicle-sharing` is active-paid
- **THEN** borrower usage envelopes are applied to the owner ledger
- **THEN** invite, revoke, and reactivate controls are disabled

### Requirement: EV read-only or unpaid sharing — hold borrower envelopes
When `vehicle` is `delinquent-readonly` **or** `vehicle-sharing` is not `active-paid` on the Propriétaire device:

- Invite, revoke, and reactivate are disabled.
- Inbound borrower-to-owner envelopes SHALL be stored locally and SHALL NOT be applied to the vehicle ledger.
- On restore to a writable sharing-out state, held envelopes SHALL be applied in receive order.
- The owner SHALL receive a local notification titled "Sharing disabled" when this state begins, and once more on the first held inbound packet (then silence).

#### Scenario: Owner vehicle trial does not allow new shares
- **WHEN** the Propriétaire is in `active-trial` on `vehicle`
- **THEN** add-share / invite / revoke / reactivate remain disabled
- **THEN** an active share cannot be created during that trial

### Requirement: PE requires paid vehicle-sharing only
Borrower actions (accept offer, log usage on accessible vehicles) require `vehicle-sharing` **active-paid**. There is no trial and no grace. The `vehicle` license SHALL NOT gate borrower-path actions.

#### Scenario: Unpaid borrower cannot act
- **WHEN** an Emprunteur's `vehicle-sharing` is not active-paid
- **THEN** accept and accessible-vehicle action controls are disabled

### Requirement: Export remains available under all delinquency states
Regardless of EV, PP, or PE delinquency, each affected user SHALL retain the ability to export their locally accumulated module data per `module-enable-disable-and-data-isolation` and housing export precedent.

#### Scenario: Delinquent owner exports vehicle history
- **WHEN** EV is read-only after trial or after vehicle payment-default grace
- **THEN** the Propriétaire can still export vehicle data from their device
