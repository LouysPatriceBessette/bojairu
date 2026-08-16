## ADDED Requirements

### Requirement: Terminology — Propriétaire and Emprunteur
User-facing copy SHALL use **Propriétaire** (FR) / **Emprunteur** (FR) equivalents in each locale for the two sharing parties. Specifications use **owner** and **borrower** as English technical terms for the same roles.

### Requirement: Sharing links connect Propriétaire, one vehicle, and one Emprunteur
The system SHALL represent an approved sharing relationship as a **VehicleSharingLink** with at least:
- `vehicleId` (one specific vehicle owned by the Propriétaire)
- `ownerContactId`
- `borrowerContactId`
- `status` (pending, active, expired, revoked)

Exactly **two parties** participate in each link. There is no multi-borrower group entity beyond separate pairwise links per Emprunteur.

#### Scenario: Propriétaire offers one specific vehicle to a connected Contact
- **WHEN** a Propriétaire with effective `vehicle` and `vehicle-sharing` entitlement selects **one owned vehicle** and a **connected Contact** to invite
- **THEN** the system creates a sharing link in pending state for that vehicle and Contact only
- **THEN** the offer copy states that the Emprunteur accepts responsibilities tied to **that vehicle's** use

#### Scenario: Propriétaire is deemed to have accepted their own offer
- **WHEN** the Propriétaire sends a vehicle offer
- **THEN** the Propriétaire side of the link is treated as already accepted (no separate Propriétaire acceptance step)
- **THEN** the link activates only when the Emprunteur accepts

#### Scenario: Emprunteur accepts sharing
- **WHEN** an Emprunteur with effective PE (see `vehicle-sharing-licensing-and-delinquency`) accepts a pending offer
- **THEN** the link becomes active
- **THEN** the Emprunteur may log usage on **that vehicle only**

### Requirement: Offer response deadline before send
Before posting a vehicle-sharing offer, the Propriétaire SHALL choose a **response deadline** from the product standard validity presets (3h / 8h / 24h / 48h). The chosen instant SHALL be persisted on the sharing link as `expiresAt` (UTC) and included in the encrypted offer payload for peers.

#### Scenario: Deadline dialog before dispatch
- **WHEN** the Propriétaire taps send on the invite form
- **THEN** the app asks for a response window using the standard duration presets
- **THEN** cancel abandons send without creating a new pending link
- **THEN** continue creates the pending link with `expiresAt = now + selected duration` and posts the offer

#### Scenario: Local expiry of pending offers
- **WHEN** wall-clock passes `expiresAt` while the link is still pending
- **THEN** the local installation marks the link `expired` and MUST NOT treat it as accept-able
- **THEN** this local refusal remains the fallback if the peer already holds the offer JSON

### Requirement: Relay does not deliver expired sharing offers
When posting a vehicle sharing offer or reactivation proposal, the client SHALL supply the product deadline as plaintext `expires_at` on `POST /v1/envelopes`. The relay SHALL retain the envelope until that instant and SHALL NOT return it on inbox poll afterwards. Envelopes without `expires_at` SHALL be retained at most seven days.

Decision-deadline reminders for these offers SHALL use the same recipe A lead times as contacts invitations (soon ping to the Emprunteur; at-deadline ping to the Propriétaire if still unanswered).

#### Scenario: Inbox omits an expired offer
- **WHEN** an offer envelope's `expires_at` is in the past and still undelivered
- **THEN** `GET /v1/inbox/{recipient}` does not include that envelope

### Requirement: No reverse discovery path for Emprunteurs
The system MUST NOT provide a flow where an Emprunteur browses or requests access to unspecified vehicles from a Propriétaire's fleet. The **only** entry path is: **Propriétaire offers this vehicle → Emprunteur accepts or declines**.

#### Scenario: Borrower cannot request from owner vehicle list
- **WHEN** an Emprunteur wants access to a Propriétaire's vehicle
- **THEN** there is no UI to pick from the Propriétaire's vehicle list without a prior offer
- **THEN** the Emprunteur must wait for a Propriétaire-initiated offer for a specific vehicle

### Requirement: Offering sharing requires both vehicle modules on the Propriétaire
The system MUST NOT allow a Propriétaire to publish a vehicle offer unless they have effective entitlement on **`vehicle` and `vehicle-sharing`** (EV + PP).

#### Scenario: Propriétaire with vehicle only cannot offer
- **WHEN** a user has `vehicle` but not `vehicle-sharing`
- **THEN** the offer action is unavailable or blocked with guidance to subscribe to `vehicle-sharing`

### Requirement: Borrowing requires vehicle-sharing on the Emprunteur device
An **Emprunteur** SHALL log usage only when they have effective **PE** (`vehicle-sharing` paid entitlement or bundle coverage) and an **active** sharing link for that vehicle.

#### Scenario: Emprunteur without vehicle subscription uses shared vehicle
- **WHEN** participant B has `vehicle-sharing` only (PE) and an active link on A's vehicle
- **THEN** B can log usage on that vehicle
- **THEN** B cannot register a new owned vehicle

### Requirement: Multiple vehicles and multiple Emprunteurs within Propriétaire caps
The system SHALL support:
- one Propriétaire sharing **up to three owned vehicles** (each with separate pairwise links),
- one Propriétaire having at most **five distinct Emprunteurs** across all owned vehicles who currently hold an **active**, **pending offer**, or **reactivate-pending** link (same Contact on two vehicles counts once),
- one Emprunteur using **multiple vehicles** (same or different Propriétaires, without a product cap on the Emprunteur side),
- one Propriétaire **borrowing another Propriétaire's vehicle** while sharing their own.

The system MUST NOT allow a Propriétaire to exceed **three** owned vehicles (see `vehicle-domain-model`) or to create / propose a sharing relationship with a **sixth distinct** Emprunteur while five others already count toward the cap. Pending invitations and reactivation proposals count toward the five until they expire (or are accepted / revoked). When inviting a Contact who would occupy the **fifth** slot, the Propriétaire SHALL see clear guidance that further distinct invitations will be blocked while that slot remains occupied.

#### Scenario: Propriétaire borrows while sharing out
- **WHEN** A shares their car with B and also has an active link as Emprunteur on C's vehicle
- **THEN** A can log owner uses on their car and Emprunteur uses on C's car
- **THEN** B can log Emprunteur uses on A's car only

#### Scenario: Same Emprunteur on two owned vehicles counts once toward the cap
- **WHEN** Emprunteur B has active links on two vehicles owned by Propriétaire A
- **THEN** B counts as one Emprunteur toward A's limit of five

#### Scenario: Pending invitation counts toward the cap
- **WHEN** a Propriétaire has four distinct Contacts with active links and one pending invitation to a fifth Contact
- **THEN** that fifth Contact counts toward the limit of five
- **AND** an offer to a sixth distinct Contact is blocked until the pending invitation expires or a counted Emprunteur is revoked

#### Scenario: Propriétaire cannot invite a sixth distinct Emprunteur
- **WHEN** a Propriétaire already has five distinct Contacts counting toward the cap (active and/or pending / reactivate-pending)
- **AND** they attempt to offer a vehicle to a sixth distinct Contact
- **THEN** the system blocks the new offer
- **THEN** the user sees clear guidance that the limit is five Emprunteurs per Propriétaire

#### Scenario: Fifth-slot warning before invite
- **WHEN** a Propriétaire has four distinct Contacts counting toward the cap
- **AND** they invite a fifth distinct Contact
- **THEN** the system allows the invite after showing guidance that this fills the last slot

### Requirement: Reactivation proposals expire like offers
Before proposing reactivation of a revoked sharing link, the Propriétaire SHALL choose a response deadline from the product standard validity presets (3h / 8h / 24h / 48h). The chosen instant SHALL be persisted as `expiresAt` on the link and included in the reactivation propose payload. When wall-clock passes `expiresAt` while the link is still `reactivatePending`, the link SHALL return to **revoked** (as if no reactivation had been proposed).

#### Scenario: Reactivation expires back to revoked
- **WHEN** a link is `reactivatePending` with `expiresAt` in the past
- **THEN** local expiry processing sets the link status to `revoked`
- **THEN** that Emprunteur no longer counts toward the five unless they have another counting link

### Requirement: Revoking sharing stops new Emprunteur usage
When a Propriétaire revokes a sharing link, the Emprunteur MUST NOT log new usage on that vehicle after revocation. Historical usage facts remain on the vehicle record for the Propriétaire's reconciliation.

#### Scenario: Propriétaire revokes Emprunteur
- **WHEN** the Propriétaire revokes an active link with B
- **THEN** B can no longer start new uses on that vehicle
- **THEN** past uses attributed to B remain on the Propriétaire's vehicle record

### Requirement: Local user cannot be Emprunteur on a vehicle they own
On any installation, the **local user** (onboarding identity / self) MUST NOT act as **Emprunteur** on a vehicle whose **fixed owner** is that same local user. See `vehicle-usage-role-separation` for navigation rules, UI blocks, and the **no-exceptions** rule for QA seeds and E2E tests.

#### Scenario: Self-borrow is forbidden
- **WHEN** the local user attempts a borrower-path save on a vehicle they own
- **THEN** the save is refused
- **THEN** the vehicle does not appear under **Accessible vehicles** as an Emprunteur entry

### Requirement: Accessible vehicles are owned on other installations
A vehicle that a local user may use as **Emprunteur** MUST have a fixed owner who is a **different local participant** on **another app installation**, introduced through connected Contacts and **relay sync**. Self-owned vehicles MUST NOT appear as Emprunteur-accessible vehicles.

#### Scenario: Empty accessible list without cross-installation sync
- **WHEN** the database contains only vehicles owned by the local user and no synced sharing data from other installations
- **THEN** the Emprunteur **Accessible vehicles** list is empty
- **THEN** this is correct product behavior, not an incomplete local simulation of sharing
