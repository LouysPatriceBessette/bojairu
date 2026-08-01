## ADDED Requirements

### Requirement: Vehicle sharing hub is the Emprunteur and cross-borrow operations home
When the user taps **Vehicle sharing** on the app home and holds effective **`vehicle-sharing`** entitlement (PE and/or PP context), the app SHALL present the **Vehicle sharing hub** — a scrollable operations home parallel to the Vehicle module hub.

**Navigation:** `App home → Vehicle sharing → Vehicle sharing hub` (see `vehicle-app-home-navigation`). Vehicle sharing is **not** nested under the **Vehicle** home affordance.

### Requirement: Hub section — Accessible vehicles
The hub SHALL include an **Accessible vehicles** section listing vehicles the local user may use as **Emprunteur** through an active sharing link, where the vehicle's **fixed owner is another participant on another app installation** (see `vehicle-usage-role-separation`).

The list MUST NOT include vehicles owned by the **local user** on this installation. Pending offers and active links on self-owned vehicles MUST NOT surface here as Emprunteur entries.

When PP settlement preview is implemented, owned vehicles MAY appear in **separate** Propriétaire settlement surfaces — not as duplicates of **My vehicles** on the Vehicle hub and not as Emprunteur-accessible rows.

For each Emprunteur-accessible vehicle, the card SHOULD surface at minimum:

- **Amount owed or credit** (settlement position from `vehicle-expense-sharing` with detail level TBD in implementation — summary amount on card, breakdown on drill-down is acceptable for first pass)
- Vehicle label and **Propriétaire** identity when the viewer is Emprunteur

Cards SHALL NOT show Propriétaire-only lifetime consumption or maintenance alert tiles.

#### Scenario: Borrower sees shared vehicle balance
- **WHEN** an Emprunteur on installation B has an active link on A's car (A is another installation)
- **THEN** the car appears under **Accessible vehicles** with owed/credit summary when allocation data exists

#### Scenario: Locally owned vehicles never listed as Emprunteur accessible
- **WHEN** the local user opens the Vehicle sharing hub and owns car V on this installation
- **THEN** V does not appear under **Accessible vehicles** as an Emprunteur row
- **THEN** the user records owner-path usage on V only through the **Vehicle** hub

### Requirement: Hub section — Statistics
The hub SHALL include **Statistics** scoped to **accessible vehicles** and **Emprunteur windows** (per `vehicle-sharing-usage-metrics`):

- **My mileage** (attributed uses only)
- **My expenses**: fuel, violations, insurance, permits (maintenance MAY appear when forwarded events affect the user's reconciliation window — registration grouping optional on first pass)
- **Compensation paid** (amounts the user paid to others through sharing settlements)

#### Scenario: Borrower statistics exclude others' usage
- **WHEN** an Emprunteur opens **Statistics** on the Vehicle sharing hub
- **THEN** mileage and expenses reflect only that user's attributed windows

### Requirement: Hub row — Quick actions
The hub SHALL expose the same quick-action set as the Vehicle module hub (see `vehicle-quick-actions-ui`):

- Odometer reading
- Fuel purchase
- Maintenance performed
- Damage or violation report

Submissions follow **forward-to-Propriétaire** routing for shared vehicles.

#### Scenario: Quick action forwards to owner
- **WHEN** an Emprunteur submits **Fuel purchase** with full tank = true from this hub
- **THEN** the purchase is sent to the Propriétaire's canonical record per domain rules

### Requirement: Propriétaire offers a vehicle from sharing context
The app SHALL provide a path from the Vehicle sharing hub (or owned vehicle detail) for a Propriétaire with EV+PP to **offer this vehicle** to a connected Contact per `vehicle-sharing-domain-model`. This flow is **not** fully wireframed here; first implementation MAY use a simple invite + accept pattern.

#### Scenario: Offer path exists
- **WHEN** a Propriétaire with both modules taps offer sharing on a owned vehicle
- **THEN** the user can select a connected Contact and send a vehicle-specific offer

### Requirement: Propriétaire sees pending outbound invitations on shares detail
On the per-vehicle **Partages** / shares detail screen, while a sharing link is **pending**, the app SHALL show an outbound invitation status line that names the invitee and the send date/time (locale-formatted), not an empty “none” state that hides the pending offer.

#### Scenario: Pending invitation visible after send
- **WHEN** the Propriétaire has sent an offer that is still pending
- **THEN** the shares detail for that vehicle shows a line equivalent to “invitation sent to {name} on {dateTime}”
- **THEN** active Emprunteurs remain listed separately when present

### Requirement: Hub is a guide not a layout straitjacket
As with the Vehicle module hub, layout and visual hierarchy are **guidance for the first implementation** only. Reordering sections or merging statistics into cards is allowed if capabilities remain reachable.
