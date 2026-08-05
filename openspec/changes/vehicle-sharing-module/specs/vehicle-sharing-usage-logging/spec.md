## ADDED Requirements

### Requirement: Approved Emprunteurs and Propriétaires log vehicle uses
The system SHALL allow the **Propriétaire** or an **approved Emprunteur** to create a vehicle use session on a shared **land** vehicle with **odometer** readings before/after (per `odometer-logging`), attributed to the acting Contact.

**Role and ownership rules** (`vehicle-usage-role-separation`):

- **Propriétaire** on installation A uses the **owner path** on vehicles A owns.
- **Emprunteur** B on installation B uses the **borrower path** only on vehicles whose fixed owner is **another installation** (e.g., A). B MUST NOT use the borrower path on B's own vehicles.

Distance for a session is derived only from **actual start/end readings**, not from estimates. **Gap attribution** when a session start exceeds the latest reading is defined in `vehicle-odometer-gap-attribution`.

#### Scenario: Emprunteur starts and completes a use
- **WHEN** an approved Emprunteur on installation B starts a use on A's shared vehicle and saves before/after readings
- **THEN** the use is stored on the **Propriétaire's canonical vehicle record** on installation A (via relay)
- **THEN** the use is attributed to the Emprunteur Contact
- **THEN** B does not satisfy this scenario by saving only on B's device without cross-installation delivery

### Requirement: Emprunteur usage facts do not grant Propriétaire hub privileges
Emprunteur-entered uses MUST NOT allow editing Propriétaire-only settings, viewing alert tiles meant for the Propriétaire, or changing the vehicle owner. **Maintenance performed** from the sharing hub forwards a report to the Propriétaire rather than opening the Propriétaire maintenance editor on the Emprunteur device.

#### Scenario: Emprunteur cannot configure maintenance rules
- **WHEN** an Emprunteur views a shared vehicle
- **THEN** maintenance **reminder configuration** and alert tiles are not available
- **THEN** the Emprunteur MAY still submit a **Maintenance performed** quick action that forwards to the Propriétaire

### Requirement: Emprunteurs do not log session-scoped fuel purchases
The system MUST NOT provide a flow for Emprunteurs to log fuel purchases tied to a usage session. Fuel reconciliation uses **full-tank anchor purchases** and meter-derived distance, not per-session liter estimates.

#### Scenario: No borrower fuel entry on use completion
- **WHEN** an Emprunteur completes a vehicle use
- **THEN** the completion flow does not prompt for liters consumed on that session
- **THEN** fuel allocation relies on anchors and shared ratios per `vehicle-expense-sharing`

### Requirement: Session-start fuel catch-up from Propriétaire
When an Emprunteur starts a use session, the session-start envelope SHALL include the stable id of the Emprunteur's newest local fuel purchase when one exists (`lastKnownPurchaseId`). After the Propriétaire imports that session start, the Propriétaire SHALL reply with a **fuel purchase catch-up** envelope (dedicated kind) containing:

- purchases **strictly after** the cursor purchase when that id exists on the Propriétaire vehicle ledger, or
- the **latest full-tank** purchase and all purchases after it when the cursor is absent or unknown,

for any recorder. The catch-up envelope MUST NOT be sent when the selected set is empty. Fuel purchase ids SHALL be stable across installations (creator id preserved on import) so the cursor can match. The Emprunteur device SHALL upsert catch-up rows onto the shared vehicle record so session-end distance guards can see owner top-ups recorded after the Emprunteur's last known purchase.

#### Scenario: Catch-up after session start delivers owner top-up
- **WHEN** the Propriétaire records a non-full fuel purchase after the Emprunteur's last known purchase
- **AND** the Emprunteur starts a new use session (session start reaches the Propriétaire)
- **THEN** the Propriétaire sends a catch-up envelope including that purchase
- **THEN** the Emprunteur ledger stores that purchase under the same stable id

#### Scenario: Empty catch-up still acknowledges the Emprunteur
- **WHEN** the Propriétaire has no fuel purchases to add after the Emprunteur cursor (or last full-tank set)
- **THEN** the Propriétaire still sends a catch-up envelope with an empty purchase list
- **THEN** the Emprunteur marks the open session's fuel catch-up response as received

#### Scenario: Session-end distance guard waits for catch-up
- **WHEN** the Emprunteur has forwarded session start and has not yet received catch-up
- **THEN** the session-end excessive-distance guard is skipped
- **WHEN** catch-up is received (empty or not)
- **THEN** the guard applies again for that session

### Requirement: Shared vehicles use gap attribution for unlogged meter increases
On a shared vehicle, when a session **start** reading exceeds the latest stored reading, gap attribution per `vehicle-odometer-gap-attribution` SHALL offer the Propriétaire and active Emprunteurs as attribution targets. Attributed participants MUST receive **informational** notifications when another participant assigns them the gap. **Unknown** attributions MUST notify the Propriétaire (unless self). **Negative** gaps MUST notify the Propriétaire for photo verification (unless self). Only the **Propriétaire** MAY revise a stored gap attribution; the app MUST NOT implement an in-app contestation workflow.

#### Scenario: Gap between Emprunteur sessions
- **WHEN** Emprunteur B ends a session at 12 400 km
- **AND** Emprunteur C later starts a session at 12 650 km without B having logged an intervening reading
- **THEN** C is prompted to attribute the 250 km gap
- **WHEN** C attributes it to B
- **THEN** B is notified on their device(s)
