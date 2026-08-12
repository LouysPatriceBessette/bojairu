## ADDED Requirements

### Requirement: Closed-app wake transport
The system SHALL provide a closed-app push transport that lets the relay wake the client app on Android and iOS so the app can poll the relay, decrypt envelopes locally, and surface notifications through the existing on-device notification builders. The wake transport SHALL be designed as a generic mechanism reusable for all current and future notification kinds.

#### Scenario: Relay envelope arrives for a registered recipient
- **WHEN** the relay accepts and persists an envelope for a recipient routing id
- **AND** at least one non-expired routing push token is registered for that recipient
- **THEN** the relay dispatches a wake push to every registered routing push token for that recipient

#### Scenario: Relay envelope arrives for an unregistered recipient
- **WHEN** the relay accepts and persists an envelope for a recipient routing id
- **AND** no non-expired routing push token is registered for that recipient
- **THEN** the relay does not dispatch any wake push and continues normal envelope persistence

#### Scenario: Closed app receives wake push
- **WHEN** an Android or iOS device receives a wake push for its recipient routing id while the app is closed
- **THEN** the device launches the app background isolate
- **AND** the app polls the relay, decrypts pending envelopes, and surfaces a local notification using the existing on-device notification builder

### Requirement: Wake push payload is data-only and content-free
The system SHALL ensure that wake push payloads contain no plaintext business content. The relay SHALL emit a payload composed of a schema version field `v`, a `kind` discriminator, and the target recipient routing id, and nothing else. The relay SHALL NOT include envelope identifiers, sender identity, business-domain metadata, or human-readable strings derived from envelope contents. The initial schema version SHALL be `1`.

#### Scenario: Wake payload minimal shape
- **WHEN** the relay dispatches a wake push
- **THEN** the push body contains exactly the schema version `v` (integer, initial value `1`), a payload kind (e.g. `"wake_for_inbox"`), and the recipient routing id
- **AND** the push body does not contain envelope ciphertext, envelope identifiers, sender identifiers, business-domain message types, expense amounts, contact display names, or any plaintext title or body derived from envelope content

#### Scenario: Client handles unknown payload version
- **WHEN** the app receives a wake push whose `v` is higher than the value it knows about
- **THEN** the app falls back to its default wake handler (poll the relay and decrypt) without crashing on the unrecognized fields

#### Scenario: iOS degraded mode generic alert
- **WHEN** the relay is configured to ship a generic alert because iOS data-only delivery is being throttled
- **THEN** the alert text is a constant, non-personalized string that does not depend on envelope content
- **AND** the localized user-facing string is owned and shown by the mobile app, not embedded by the relay

### Requirement: V1 functional surface
The system SHALL initially wire the wake transport functionally only for Contacts add request envelopes. All other notification categories SHALL continue to operate exactly as before this change, including their existing polling-based local notification path and their existing app-level controls.

#### Scenario: Contacts add request triggers wake
- **WHEN** a peer submits a Contacts add request and the relay accepts the resulting envelope
- **THEN** the relay dispatches a wake push as described in this capability
- **AND** the receiving app, after polling and decrypting, surfaces the existing Contacts add request notification according to user preferences

#### Scenario: Other notification kinds remain on polling-only path
- **WHEN** the relay accepts an envelope whose business kind is not Contacts add request
- **THEN** the relay still dispatches a wake push if the recipient is registered, but no additional V1 client-side behavior is required
- **AND** the existing polling-based local notification path continues to deliver these notifications without regression

### Requirement: Platform scope
The system SHALL implement closed-app push delivery on Android via FCM HTTP v1 and on iOS via APNs. Web push SHALL NOT be implemented.

#### Scenario: Android registration uses FCM
- **WHEN** an Android client registers for closed-app push delivery
- **THEN** the registration is recorded with provider `fcm` and an FCM registration token

#### Scenario: iOS registration uses APNs
- **WHEN** an iOS client registers for closed-app push delivery
- **THEN** the registration is recorded with provider `apns` and an APNs device token

#### Scenario: Web is not registered
- **WHEN** the app runs on web
- **THEN** the client SHALL NOT call the closed-app push registration endpoints
- **AND** the relay SHALL NOT accept registrations whose provider value is reserved for web push

### Requirement: Routing push token fan-out
The relay SHALL support multiple non-expired routing push tokens per recipient routing id and SHALL dispatch a wake push to every registered token for the recipient on each qualifying envelope.

The **product** assumes **one active installation per user identity** (see `data-locality-and-client-storage`). Multiple tokens for the same routing id are therefore expected only for transport reasons (token refresh, OS reinstall, overlapping registrations during migration)—not for simultaneous multi-device use of the same person’s data.

#### Scenario: Token refresh overlap
- **WHEN** a client refreshes its FCM or APNs token and re-registers before the prior row expires
- **THEN** the relay MAY briefly hold more than one non-expired token for the same recipient routing id
- **AND** wake dispatch MAY target each registered token until TTL purge removes stale rows

#### Scenario: Per-token dispatch failure does not block others
- **WHEN** dispatch to one of several registered tokens fails
- **THEN** the relay still attempts dispatch to the remaining tokens
- **AND** the per-token error is logged with provider and error class but without envelope context

### Requirement: Routing push token registration
The system SHALL expose explicit registration and unregistration endpoints on the relay. Registration SHALL be authenticated to bind the token to the holder of the recipient routing identity, using the same mechanism that authenticates envelope ingestion for that routing id. Each registration SHALL set or refresh an `expires_at` based on a configured time-to-live. Each registration request SHALL also carry the current country disclosure value (an ISO 3166-1 alpha-2 country code or the literal `UNDISCLOSED`); the relay SHALL persist that value in the corresponding row without history.

#### Scenario: Authenticated registration is accepted
- **WHEN** an authenticated client posts a registration request with provider, push token, recipient routing id, and country disclosure value
- **THEN** the relay creates or refreshes a row in the routing push token store using all four fields
- **AND** the relay returns the resulting `expires_at` so the client can schedule keep-alive refresh

#### Scenario: Unauthenticated registration is rejected
- **WHEN** a registration request arrives without valid authentication for the supplied recipient routing id
- **THEN** the relay rejects the request and does not store any data

#### Scenario: Missing or invalid country value defaults to UNDISCLOSED
- **WHEN** a registration request omits the country value or supplies a value that is not a recognized ISO 3166-1 alpha-2 code and is not `UNDISCLOSED`
- **THEN** the relay stores `UNDISCLOSED` for that row and proceeds normally

#### Scenario: Client unregisters
- **WHEN** the client posts an unregister request for an existing (recipient, provider, push token) tuple
- **THEN** the relay deletes the corresponding row

### Requirement: Strict TTL on routing push tokens
The system SHALL enforce a hard time-to-live on every routing push token row. The relay SHALL purge rows whose `expires_at` has passed. The relay SHALL NOT extend TTL automatically beyond the configured maximum even if the client refreshes aggressively. The default TTL SHALL be 14 days and SHALL be configurable through a relay environment variable; changing the configured value SHALL NOT alter `expires_at` of rows already in the table.

#### Scenario: TTL expiry triggers purge
- **WHEN** a routing push token row reaches its `expires_at` and the client has not refreshed
- **THEN** the relay purges the row during the next purge cycle or on the next access, whichever comes first

#### Scenario: Refresh resets TTL
- **WHEN** an authenticated client refreshes a registration before `expires_at`
- **THEN** the relay updates `expires_at` to now plus the configured TTL
- **AND** the relay updates `last_seen_at`

#### Scenario: Operator reconfigures the TTL
- **WHEN** the operator changes the configured TTL value and restarts the relay
- **THEN** the new value applies to subsequent registrations and refreshes
- **AND** existing rows keep their previously assigned `expires_at` and migrate to the new value only on their next refresh or replacement

#### Scenario: Token reported invalid by provider is purged
- **WHEN** the FCM or APNs provider returns a permanent error indicating the token is no longer valid
- **THEN** the relay purges the corresponding row promptly, without waiting for TTL expiry

### Requirement: Client-side keep-alive
The system SHALL implement a client-side keep-alive that opportunistically refreshes routing push token registrations while the device is genuinely active. The keep-alive SHALL refresh on app cold start, on foreground resume, on receipt of a wake push, on FCM/APNs token rotation, and on opportunistic background execution scheduled through the platform background task APIs.

#### Scenario: App foreground triggers refresh
- **WHEN** the app moves to the foreground and has previously registered a routing push token
- **THEN** the client refreshes the registration if more than a configured fraction of the TTL has elapsed since the last refresh

#### Scenario: Background task refresh succeeds
- **WHEN** the OS executes the app's scheduled background refresh task
- **AND** the device still has system notification permission
- **AND** network is available
- **THEN** the client refreshes the registration and reschedules the next background task

#### Scenario: Background task is denied or throttled
- **WHEN** the OS does not schedule the background refresh task within the planned window
- **THEN** the client SHALL NOT block other functionality
- **AND** the registration SHALL be refreshed on the next foreground resume or wake push, whichever happens first

#### Scenario: Token rotation triggers re-registration
- **WHEN** FCM or APNs reports a new push token to the client
- **THEN** the client SHALL unregister the previous token and register the new token

### Requirement: Natural expiry on inactivity, uninstall, or permission revocation
The system SHALL ensure that an uninstalled app, a powered-off device, or a device whose OS notification permission has been revoked causes the routing push token to expire silently within at most one TTL cycle, with no special server-side detection logic required.

#### Scenario: Uninstalled app expires silently
- **WHEN** the app is uninstalled and no client refresh occurs for the duration of the TTL
- **THEN** the relay purges the corresponding row at `expires_at`

#### Scenario: OS revoked permission expires silently
- **WHEN** the user revokes notification permission in OS settings and the client cannot deliver an unregistration request
- **THEN** the next provider dispatch will return a permanent error
- **AND** the relay purges the row promptly per the TTL provider-error rule

#### Scenario: Device offline longer than TTL expires silently
- **WHEN** the device is offline for longer than one TTL cycle and no refresh occurs
- **THEN** the relay purges the row at `expires_at`

### Requirement: Daily aggregate statistics through a localhost-only endpoint and append-only file
The system SHALL expose aggregate statistics through a single relay endpoint bound exclusively to the loopback interface, accessible only to the operating-system user that owns the relay process. The system SHALL NOT expose any per-row data outside the dispatch path. Operators SHALL NOT query the routing token database directly to obtain these statistics; the endpoint is the only sanctioned surface, and a cron job, whose source code lives in this repository, is the only sanctioned consumer.

The endpoint SHALL compute, for a given target date (default: the previous calendar day in UTC), an aggregate summary of active devices, country distribution when applicable, and purely technical counters. The cron job SHALL run once per day at 00:07 UTC, call the endpoint for the previous calendar day, and append exactly one JSON line to a stats file on disk. The stats file SHALL be the only persistent surface of these statistics, SHALL be append-only, and SHALL never be modified retroactively for past days.

#### Scenario: Endpoint is loopback-only
- **WHEN** a request to the stats endpoint originates from any source other than the loopback interface
- **THEN** the relay rejects the request without revealing whether the endpoint exists

#### Scenario: Endpoint computes counts for the previous calendar day
- **WHEN** the endpoint is called without a target date
- **THEN** the endpoint computes the count of distinct routing push token rows whose `last_seen_at` falls within the previous calendar day in UTC (from 00:00:00 UTC inclusive to the next 00:00:00 UTC exclusive)
- **AND** the endpoint returns the active total, the per-country breakdown subject to suppression rules, and the technical counters described below

#### Scenario: Cron job appends a single line per day
- **WHEN** the cron job runs at 00:07 UTC
- **THEN** it appends exactly one JSON line to the stats file containing the previous day's date and the endpoint response
- **AND** previous lines in the stats file remain untouched

#### Scenario: Per-row data is never exported
- **WHEN** the endpoint serves a request
- **THEN** the response contains aggregate counts only
- **AND** the response does not include routing identifiers, push tokens, raw `last_seen_at` values, country values per row, or any other per-row attribute

#### Scenario: Routing push table is not joined with subscription data
- **WHEN** the relay processes a subscription validation or any other server-side operation outside push dispatch and stats aggregation
- **THEN** the operation SHALL NOT read or join the routing push token table

### Requirement: Technical counters share the same daily statistics line
The system SHALL include, in the daily statistics line, a set of purely technical counters covering wake dispatch outcomes, TTL purge volume, and the current row count of the routing push token table. These counters SHALL contain no user-related dimensions.

#### Scenario: Daily statistics line includes technical counters
- **WHEN** the cron job writes its daily line
- **THEN** the line includes `dispatch_success_count` and `dispatch_failure_count` covering the previous calendar day in UTC
- **AND** the line includes `purge_count` for the previous calendar day in UTC
- **AND** the line includes `routing_push_tokens_row_count` measured at the moment the endpoint is called

#### Scenario: Technical counters carry no user-related labels
- **WHEN** the relay produces the technical counters
- **THEN** the counters do not include routing identifiers, push tokens, country labels, or per-provider breakdowns beyond a single aggregate provider distribution

### Requirement: User-disclosed country aggregation, opt-in only
The system SHALL allow each user to opt in to disclosing a country of use for the sole purpose of contributing to aggregate per-country counts in the daily statistics file. The setting SHALL be off on fresh installs and SHALL be revocable at any time from app settings. The relay SHALL store at most one country value per routing push token row, carried alongside the keep-alive payload. The relay SHALL NOT retain any history of past country values. The country value SHALL be the only user-declared dimension allowed in the routing push token table.

The system SHALL suppress small country populations in the daily statistics file. Countries whose active-device count for the day is strictly less than 10 SHALL be merged into an `OTHER` bucket. The suppression threshold SHALL be hardcoded in source so it is visible to anyone auditing the repository, SHALL NOT be configurable through environment variables or runtime parameters, and SHALL be reviewed only through code review.

#### Scenario: Fresh install defaults to opt-out
- **WHEN** the user installs the app for the first time
- **THEN** the country-disclosure preference is off
- **AND** the client sends an `UNDISCLOSED` country value on every register and refresh until the user opts in

#### Scenario: User opts in and selects a country
- **WHEN** the user enables the country-disclosure preference and picks a country from the localized dropdown
- **THEN** subsequent register and refresh calls send the corresponding ISO 3166-1 alpha-2 country code
- **AND** the relay overwrites any previously stored country value for this row

#### Scenario: User opts out
- **WHEN** the user disables the country-disclosure preference
- **THEN** the next register or refresh call sends `UNDISCLOSED`
- **AND** the relay overwrites any previously stored country value for this row

#### Scenario: User changes country
- **WHEN** an opted-in user selects a different country
- **THEN** the next register or refresh call sends the new code
- **AND** the relay overwrites the previously stored code, with no history retained

#### Scenario: Country picker is localized
- **WHEN** the user opens the country picker
- **THEN** country names are shown in the user's app language (FR, EN, ES)
- **AND** the stored value remains the ISO 3166-1 alpha-2 code regardless of display language

#### Scenario: Country with at least the threshold count is reported
- **WHEN** the endpoint computes the daily statistics
- **AND** a country has 10 or more active devices in the previous calendar day in UTC
- **THEN** the country is reported under its ISO code in the per-country breakdown

#### Scenario: Country below the threshold is bucketed into OTHER
- **WHEN** a country has between 1 and 9 active devices in the previous calendar day in UTC
- **THEN** the country code is not reported individually
- **AND** the affected devices are summed into the `OTHER` bucket

#### Scenario: UNDISCLOSED has its own bucket
- **WHEN** the endpoint computes the daily statistics
- **THEN** devices whose stored country is `UNDISCLOSED` are reported in an `UNDISCLOSED` bucket, separate from `OTHER`

#### Scenario: No additional user-declared dimension is allowed
- **WHEN** a future change considers adding another user-declared dimension to the routing push token table
- **THEN** that change requires a separate spec amendment because this requirement bounds the user-declared columns to `country` only

### Requirement: User control governs wake registration
The system SHALL make closed-app push registration conditional on the app-level master notification switch and on the relevant category preferences. When a user disables the master switch or disables every wake-eligible category, the client SHALL unregister and SHALL NOT re-register until the user re-enables a wake-eligible setting.

#### Scenario: Master switch off prevents registration
- **WHEN** the app-level master notification switch is off
- **THEN** the client SHALL NOT register a routing push token
- **AND** the client SHALL unregister any previously registered token for this device

#### Scenario: User turns the master switch off after a previous registration
- **WHEN** the user turns the master switch off
- **THEN** the client unregisters the routing push token best-effort
- **AND** if unregistration cannot reach the relay, the registration expires naturally at TTL

#### Scenario: Wake-eligible category preference governs registration
- **WHEN** every wake-eligible notification category is disabled
- **THEN** the client SHALL NOT register a routing push token, even if the master switch is on

### Requirement: Wake dispatch is best-effort and never blocks envelope delivery
The system SHALL treat wake push dispatch as a best-effort side effect of envelope persistence. A wake push dispatch failure SHALL NOT prevent envelope persistence, SHALL NOT prevent retrieval through polling, and SHALL NOT affect any other envelope semantics.

#### Scenario: Push provider unreachable
- **WHEN** the FCM or APNs provider is temporarily unreachable
- **THEN** the relay logs the dispatch failure
- **AND** the relay still persists the envelope normally and serves it via polling

#### Scenario: Push provider rate-limited
- **WHEN** the push provider rate-limits the relay
- **THEN** the relay backs off and may drop wake dispatches as a load-shedding measure
- **AND** the envelope still becomes available via polling

### Requirement: Documented operational configuration
The system SHALL require the relay deployment documentation, the relay state schema documentation, and the relay audit checklist to be updated to describe routing push tokens, their TTL, their purge job, the FCM and APNs credentials needed for dispatch, the loopback-only daily statistics endpoint, the cron job that consumes it, and the stats file produced.

#### Scenario: Deployment documentation describes credentials
- **WHEN** the change ships
- **THEN** the relay deployment documentation lists `FCM_SERVICE_ACCOUNT_JSON_PATH`, the APNs auth key path, key id, team id, bundle id, and environment selection, and explains where these secrets must live in production

#### Scenario: Audit checklist covers the routing push table
- **WHEN** the change ships
- **THEN** the relay audit checklist contains items asking the reviewer to confirm the routing push table schema (including the single optional `country` column), TTL enforcement, the absence of extra columns beyond those specified in this capability, and the hardcoded country suppression threshold

#### Scenario: Deployment documentation describes the statistics pipeline
- **WHEN** the change ships
- **THEN** the relay deployment documentation describes the loopback-only stats endpoint, the cron job that calls it at 00:07 UTC, the location and format of the append-only stats file, and the operating-system user that owns both the relay process and the cron job

### Requirement: Operator manual notification trigger (deferred)
**Status:** deferred until the next coordinated **relay + entitlement** server update. Not part of V1 closed-app wake delivery.

The product SHALL support an **operator-only** command that manually triggers a notification to open an in-app message page. The trigger SHALL be invocable **only** from the production VPS under the secured Linux account that operates the relay (and entitlement) stack — not from the mobile app and not via a public unauthenticated HTTP surface.

The notification SHALL use a **new push `kind`** (distinct from inbox wake). An illustrative minimal operator payload shape (to be refined at implementation) is `{ "version": <number>, "message": <boolean> }` alongside schema/`kind` fields designed then.

The in-app message page SHALL compare the installed app **build number** to the build number carried with the notification and SHALL show or hide an update affordance accordingly. The same mechanism MAY present a message that directs the user to consult content on the **static website**, with or without a build-number change.

Detail design (fan-out targets, privacy relative to the content-free inbox-wake rule, entitlement role if any, exact CLI, UX copy) SHALL be written when that server update is implemented — see task **12.5**.

#### Scenario: Operator triggers from VPS only
- **WHEN** an authorized operator on the VPS runs the secured CLI for this feature under the stack’s Linux service account
- **THEN** the system emits the operator notification `kind` toward registered devices as designed for that release
- **AND** the trigger is not exposed as a mobile-app or public Internet endpoint

#### Scenario: Message page gates update affordance on build number
- **WHEN** the app opens the operator message page from that notification
- **AND** the notification carries a target build number
- **THEN** the page compares that value to the installed build number and shows the update affordance only when the comparison policy for that release says an update is relevant

#### Scenario: Message may point at static website
- **WHEN** the operator notification is configured as a consult-message (per the refined payload)
- **THEN** the in-app page MAY direct the user to the static website for the full message
- **AND** this MAY occur with or without a change in the advertised build number
