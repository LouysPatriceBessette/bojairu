## ADDED Requirements

### Requirement: Owner sees lifetime and windowed vehicle metrics
On the **Propriétaire's** device, the system SHALL compute and display:
- total distance over the vehicle lifetime and over selectable windows
- consumption per km using full-tank anchors (see `fuel-purchase-tracking`)
- methodology / explainability for each displayed metric

For each plein→plein interval, fuel volume SHALL be the sum of **all** fuel purchases recorded after the opening full-tank anchor through and including the closing full-tank purchase (partial top-ups between anchors count). The opening full-tank volume itself SHALL NOT be included. Distance for the interval SHALL be the meter delta between those two full-tank anchors (not distance after the last full tank until a new full tank closes the period).

These metrics SHALL include distance from **all** attributed uses (owner and approved borrowers).

#### Scenario: Owner sees total distance including borrower uses
- **WHEN** an owner opens metrics for a vehicle that has borrower-attributed uses
- **THEN** total distance includes borrower sessions
- **THEN** the owner can inspect which uses contributed to the total

#### Scenario: Partial top-up between full tanks counts in consumption
- **WHEN** a vehicle has full-tank purchases A then C, with a non-full purchase B between them (by meter)
- **THEN** the A→C interval fuel volume includes B's liters plus C's liters
- **THEN** A's liters are excluded (opening anchor only)

### Requirement: Display the last full-tank anchor used for consumption
The system MUST display the date of the last full-tank entry used as the start anchor for the currently displayed consumption calculation.

#### Scenario: Owner sees full-tank anchor date
- **WHEN** the owner views consumption between full-tank entries
- **THEN** the system shows the date/time of the last full-tank entry used

### Requirement: Suggest full tank after long gaps (owner only) — deferred
**Deferred to a future release (2026-07-14).** When implemented, if the last full-tank anchor is older than one month, the system SHOULD suggest a full-tank refill the next time the **owner** records a non-full fuel purchase.

**Current release:** the system MUST NOT require this suggestion or notification; fuel purchases save without a stale-anchor prompt.

#### Scenario (future): Owner notification after non-full entry when last full is stale
- **WHEN** (future release) the owner records a fuel purchase with full tank = false
- **AND** the last full-tank entry for the vehicle is older than one month
- **THEN** the system shows or schedules a reminder suggesting a full-tank refill to improve consumption accuracy

#### Scenario (current): No stale full-tank gate on save
- **WHEN** the owner records a fuel purchase with full tank = false
- **AND** the last full-tank entry is older than one month
- **THEN** the purchase is saved without a mandatory stale-anchor suggestion

### Requirement: Handle insufficient data gracefully
The system MUST NOT present misleading metrics when data is insufficient (e.g., division by zero).

#### Scenario: No distance yields insufficient data
- **WHEN** a selected window has zero total distance
- **THEN** consumption per km is shown as unavailable with an explanation
