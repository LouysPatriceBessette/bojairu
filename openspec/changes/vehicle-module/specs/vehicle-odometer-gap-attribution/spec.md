## ADDED Requirements

### Requirement: Sessions use start and end meter readings
The app SHOULD prompt users to record a **session start** reading when beginning a vehicle use and a **session end** reading when completing it (see `odometer-logging`). Quick-action and session flows SHOULD make both steps easy; completing only a start reading leaves the session **open** until an end reading is saved.

#### Scenario: Recommended start-then-end flow
- **WHEN** a user begins a vehicle use from a quick action or session entry
- **THEN** the app prompts for a **start** meter reading first
- **WHEN** the user later completes the use
- **THEN** the app prompts for an **end** meter reading on the same session

### Requirement: Positive unlogged gap detected at session start
When the user saves a **session start** reading **greater than** the vehicle's **most recent** stored meter reading (whether that prior reading was a session start, session end, or standalone reading), the system SHALL compute the **gap**:

\[
\text{gap} = \text{startReading} - \text{latestReading}
\]

using the vehicle's odometer unit (km or mi per vehicle settings).

If `gap` is zero, no gap confirmation is required.

#### Scenario: Gap confirmation on new session start
- **WHEN** the latest stored reading for a vehicle is 12 400 km
- **AND** the user saves a new session start reading of 12 650 km
- **THEN** the system computes a gap of 250 km
- **THEN** the app confirms the divergence (and may warn if the gap exceeds one-tank plausibility) before finalizing the session start

#### Scenario: No gap when readings match
- **WHEN** the latest stored reading is 12 400 km
- **AND** the new session start reading is 12 400 km
- **THEN** no gap confirmation is shown

### Requirement: Positive gaps are stored as Unknown until the Propriétaire resolves them
After the user confirms a **positive** gap, the system SHALL persist a gap record on the Propriétaire's canonical vehicle record with `attributedContactId = unknown` (product: **Inconnu** / **I don't know**). The app MUST **not** ask “who is this gap attributable to?” at save time for Self / another participant / Unknown.

Until the **Propriétaire** resolves the pending correction, that distance remains **Unknown** and MUST NOT enter Emprunteur owed inputs (see `vehicle-sharing-usage-metrics`).

The Propriétaire SHALL resolve via **pending corrections**: either **correct a meter reading** (photo verification) **or** attribute the unlogged distance by adding missing use session(s) / assigning participants. Emprunteurs MUST NOT override stored gap attribution.

The app MUST NOT provide an in-app contestation workflow.

#### Scenario: Gap always starts as Unknown
- **WHEN** any participant confirms a positive gap at session start
- **THEN** the gap is stored with `attributedContactId = unknown`
- **THEN** session start may continue with the new reading linked as the trigger

#### Scenario: Propriétaire resolves by correcting a reading
- **WHEN** the Propriétaire opens pending corrections for a gap
- **AND** chooses to correct a prior or trigger reading
- **THEN** the gap is cleared through the correction flow
- **THEN** subsequent usage-balance math no longer treats that stretch as Unknown unlogged gap

#### Scenario: Propriétaire resolves by assigning missing sessions
- **WHEN** the Propriétaire adds one or more missing use sessions covering the gap distance
- **THEN** distance is attributed to the chosen participant(s) for usage-balance purposes
- **THEN** the pending gap record is removed

#### Scenario: Emprunteur cannot revise attribution
- **WHEN** an Emprunteur views a gap they triggered
- **THEN** they cannot change attribution; only the Propriétaire may resolve

### Requirement: Notify the Propriétaire when a sharing Emprunteur creates a session-start gap
When an **Emprunteur** on another installation starts a use and the import creates a positive-gap / open-session conflict requiring Propriétaire attention, the Propriétaire's device SHALL show an **informational** local notification directing them to pending corrections (no self-notification when the Propriétaire is the acting user).

The product does **not** require notifying a peer merely because a gap was “attributed” to them at save time — attribution at save time is not product behavior.

#### Scenario: Emprunteur session start creates a gap on the Propriétaire device
- **WHEN** Emprunteur B's session start is imported on Propriétaire A's device with a pending gap / correction reading
- **THEN** A receives a local notification to review pending corrections
- **THEN** the gap remains Unknown until A resolves it

#### Scenario: Propriétaire creates a gap on their own vehicle
- **WHEN** Propriétaire A confirms a positive gap while logging on their own vehicle
- **THEN** the gap is stored as Unknown
- **THEN** no gap notification is sent to A (self-action)
- **THEN** A may resolve via pending corrections on the same device

### Requirement: Persist gap facts on the vehicle record
Each detected **positive** gap SHALL be stored with at least:

- `latestReadingBeforeGap` (value + timestamp reference)
- `startReadingAfterGap` (the new session start)
- `gapAmount` (derived, positive)
- `attributedContactId` (initially `unknown`; may change only through Propriétaire resolution that clears or replaces the gap)
- `recordedByContactId` (who confirmed the divergence)
- `recordedAt`
- links to correction / previous / trigger readings as implemented

Gap distance while Unknown is a **factual input** separate from the session's own \(end - start\) usage for that session.

#### Scenario: Gap stored before session continues
- **WHEN** the user completes positive-gap confirmation
- **THEN** the gap record is persisted as Unknown
- **THEN** the new session start reading remains linked to the opening session

### Requirement: Negative gap handling with photo verification
When a new meter reading is **lower than** the vehicle's latest stored reading, the system SHALL treat this as a **negative gap** (reading decreased). The new reading MUST follow the meter photo rules in `odometer-logging` (photo file required when the value changed; session end always requires a photo). Negative-gap handling relies on those photos for visual verification when a photo file is present.

If the acting user **is** the Propriétaire, the app SHALL show a dialog stating the negative gap amount and offering exactly two choices before finalizing the save:

1. **Maintain current reading, investigate later** — persist the new reading with a negative-gap acknowledgment and a **journal entry**; the Propriétaire may correct prior readings later. A dedicated push reminder after maintain is **not** required for the current release.
2. **Cancel current entry** — discard the in-progress reading so the Propriétaire can verify the prior reading and correct it first.

If the acting user is **not** the Propriétaire, the reading is saved with the required photo; the Propriétaire investigates via journal / pending corrections when the fact reaches their device. Prefer notifying the Propriétaire when a sharing Emprunteur creates a meter conflict that needs verification (same pending-corrections attention model as positive gaps). The notification MUST NOT be sent when the Propriétaire is the acting user (**no self-notification**).

The app MUST NOT provide an in-app contestation workflow; only the **Propriétaire** MAY later correct readings.

#### Scenario: Propriétaire chooses to maintain lower reading
- **WHEN** the Propriétaire saves a reading lower than the latest stored reading
- **THEN** the app shows the negative-gap dialog
- **WHEN** the Propriétaire chooses **Maintain current reading, investigate later**
- **THEN** the new reading is persisted with negative-gap acknowledgment and journal entry
- **THEN** no self-notification is sent

#### Scenario: Propriétaire cancels to verify prior reading
- **WHEN** the Propriétaire chooses **Cancel current entry** on the negative-gap dialog
- **THEN** the in-progress reading is not saved
- **THEN** the Propriétaire can open the prior reading to verify its photo and correct if needed

### Requirement: Gap handling applies on shared and solo-owned vehicles
Positive gap detection and Unknown persistence SHALL run for **any** session start reading on a vehicle, whether or not sharing is active. Negative gap handling applies to **any** meter reading save, shared or solo.

#### Scenario: Solo owner with unexplained positive gap
- **WHEN** a Propriétaire with no active Emprunteurs logs a session start above the latest reading
- **THEN** after confirmation the gap is stored as Unknown
- **THEN** the Propriétaire resolves it via pending corrections when ready
