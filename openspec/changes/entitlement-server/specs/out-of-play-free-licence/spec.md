## ADDED Requirements

### Requirement: Operators can grant an installation a free all-modules licence
The Entitlement service SHALL allow an authenticated operator to grant an
existing installation access to `housing`, `vehicle`, and `vehicle-sharing`
without a Google Play or App Store purchase.

The service SHALL store the operator name, grant date, and expiry date on the
existing `installations` row. The expiry SHALL be 100 years after creation.

#### Scenario: SET creates a 100-year all-modules grant
- **WHEN** the operator supplies a name and a registered installation ID
- **AND** the installation has a registered Firebase token
- **AND** the installation has no existing free licence
- **AND** the installation has no non-cancelled, non-expired Google Play subscription
- **THEN** Entitlement stores a free licence expiring 100 years after creation
- **THEN** the licence covers `housing`, `vehicle`, and `vehicle-sharing`
- **THEN** Entitlement sends a silent `grant` message containing the synthetic all-modules receipt

#### Scenario: SET rejects an existing free licence
- **WHEN** SET targets an installation whose `free_user_name` is already set
- **THEN** SET returns an error
- **THEN** the existing grant remains unchanged

#### Scenario: SET rejects a paid subscription still in effect
- **WHEN** SET targets an installation with a non-cancelled Google Play subscription
- **AND** that subscription has not expired
- **THEN** SET returns `paid_license_still_valid`
- **THEN** no free licence remains from that failed operation

#### Scenario: A cancelled subscription does not block SET
- **WHEN** the stored Google Play state is `SUBSCRIPTION_STATE_CANCELED`
- **AND** the paid access remains valid until its expiry date
- **THEN** SET may create the free licence

#### Scenario: SET requires a reachable installation
- **WHEN** the installation has not registered
- **OR** it has no registered Firebase token
- **OR** the Entitlement Firebase sender is unavailable or rejects the message
- **THEN** SET returns an error
- **THEN** no free licence remains from that failed operation

### Requirement: Operators can list active free licences
The Entitlement service SHALL return active free licences as CSV with the
columns `Nom,InstallationId`, ordered by operator name.

#### Scenario: GET excludes expired and absent grants
- **WHEN** the operator requests the free-licence list
- **THEN** rows with a future `free_license_expires_at` and a non-null `free_user_name` are returned
- **THEN** expired grants and installations without grants are omitted

### Requirement: Operators can revoke a free licence immediately
The Entitlement service SHALL send a silent `revoke` message before clearing
the free-licence columns.

#### Scenario: DELETE revokes local and server access
- **WHEN** DELETE targets an active free licence
- **THEN** Entitlement first sends the silent `revoke` message to its registered Firebase token
- **THEN** Entitlement clears the free-licence name, grant date, and expiry date
- **THEN** Entitlement reprojects the installation's housing licence
- **THEN** an active housing plan becomes read-only immediately when no paid entitlement remains

#### Scenario: DELETE push failure preserves the grant
- **WHEN** Firebase rejects the silent `revoke` message
- **THEN** DELETE returns an error
- **THEN** Entitlement preserves the free licence

### Requirement: The mobile app treats the grant as a paid all-modules receipt
The mobile app SHALL store an active grant as a synthetic local receipt with
product ID `bojairu.bundle.all_modules`, platform `server_grant`, a stable
installation-specific token, the server-provided dates, and automatic renewal
disabled.

#### Scenario: Grant opens all modules without Play actions
- **WHEN** the app receives or fetches a valid `server_grant` receipt
- **THEN** all three module entitlements become `activePaid`
- **THEN** the Licences screen displays the all-modules licence
- **THEN** the Licences screen does not offer Google Play cancellation or resubscription for that receipt

#### Scenario: Reconciliation removes a stale grant only
- **WHEN** a successful licence response contains no active `server_grant`
- **THEN** the app removes its local `server_grant` receipt
- **THEN** Google Play and App Store receipts remain unchanged

#### Scenario: The app reconciles grants at entitlement checkpoints
- **WHEN** the app starts, resumes, opens or resumes the Licences screen, or performs a release-mode licence checkpoint
- **THEN** it fetches the current Entitlement licence state

#### Scenario: Silent messages apply in foreground and background
- **WHEN** a valid installation-specific `grant` or `revoke` data message arrives
- **THEN** the app updates the synthetic receipt without displaying a user notification

### Requirement: Entitlement addresses licence pushes by installation ID
The app SHALL register its current Firebase token with Entitlement using its
installation ID. Entitlement SHALL send licence data messages directly and
SHALL NOT require a relay protocol or relay source change.

#### Scenario: Firebase token refresh updates Entitlement
- **WHEN** Firebase issues a new token
- **THEN** the app registers the new token for its current installation ID

### Requirement: Users can read their installation ID
The mobile app SHALL display the complete installation ID under
**Settings > About**.

#### Scenario: User retrieves an ID for the operator
- **WHEN** the user opens Settings and then About
- **THEN** the full installation ID is visible

### Requirement: Free licences follow installation migration
The Entitlement installation migration SHALL copy the free-licence name,
grant date, and expiry date to the new installation row while preserving the
new installation's own Firebase token.

#### Scenario: Migrated installation retains its grant
- **WHEN** Entitlement migrates an old installation ID to a new installation ID
- **THEN** the active free licence belongs to the new installation ID
- **THEN** future grant and revoke messages target the new installation's Firebase token

### Requirement: Deployment exposes operator scripts and Firebase configuration
The tracked operator scripts SHALL live under `deploy/free-licence/` as
`free-license-get.sh`, `free-license-set.sh`, and `free-license-delete.sh`.

Entitlement SHALL read the Firebase service-account path from
`FCM_SERVICE_ACCOUNT_JSON_PATH`. Deployment SHALL mount that file read-only,
separately from the Google Play service-account configuration.

#### Scenario: VPS operator scripts call the local Entitlement endpoint
- **WHEN** the scripts run on the VPS with `ENTITLEMENT_INTERNAL_TOKEN`
- **THEN** they call `http://127.0.0.1:8081/v1/free-licenses`
- **THEN** no public operator endpoint is required
