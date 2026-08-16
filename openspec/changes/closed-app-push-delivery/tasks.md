> **Implementation status (2026-07-08).** Relay schema v2 (`routing_push_tokens`),
> register/unregister endpoints, FCM wake dispatcher (feature-flagged), daily
> stats loopback + cron scripts, Android keep-alive (WorkManager + resume/wake
> refresh), client registration gates, predecessor spec alignment, operator docs,
> automated tests, client wake-eligible Housing plan categories (**12.1**,
> **12.2**), **Android FCM wake field validation**, and **FCM wake manual QA**
> (`fcm_wake_push_emulator_physical`) are **implemented and validated in the repo /
> on VPS**. Production enablement (`WAKE_PUSH_DISPATCH_ENABLED`) is **on** for
> current Android QA. Tasks **7.4**, **10.5 (iOS only)**, **11.2**, **11.3 (APNs
> only)**, **11.6**, and **12.3–12.4** remain **open or deferred**. Task **12.5**
> (operator FCM notice CLI) is **implemented in the repo** (needs the next relay
> image recreate on the VPS). Privacy
> sign-off for transport routing tokens + `last_seen_at` is **recorded** (task 1.1;
> see `design.md` § 1). APNs code exists in relay but is **out of scope** for
> current functional QA (FCM-only).

## 1. Privacy and Spec Orchestration

- [x] 1.1 Confirm with the product owner that the relaxed privacy posture (transport routing tokens with TTL, plus `last_seen_at`) is acceptable for the next relay audit and record the decision in this folder. *(Product decision 2026-06-21 — acceptable for next relay audit; recorded in `design.md` § 1.)*
- [x] 1.2 Identify whether `privacy-first-sync-architecture`, `relay-sync-no-persistence`, and `notification-permission-management` can still be amended in place before archival, or whether a follow-up change is required after archival; record the chosen orchestration path. *(Decision 2026-06-21: amend in place — `spec-orchestration.md`.)*
- [x] 1.3 If amending in place: update the predecessor change's spec deltas to align with the contracts in `specs/closed-app-push-delivery/spec.md` (transport routing tokens exception, wake-push dispatch clarification, and the master-switch / category linkage to registration). If post-archival: schedule a follow-up OpenSpec change for the same purpose. *(Updated specs under `privacy-first-sync-architecture/` and `notification-permission-management/`.)*
- [x] 1.4 Update `docs/relay-audit-checklist.md` and `docs/relay-deployment.md` to add explicit audit items for the routing push token table, its TTL, its purge job, and FCM/APNs credentials, as required by the `Documented operational configuration` requirement. *(Checklist § routing push tokens + `docs/relay-deployment.md` “Daily closed-app push statistics”; scheduled-notification schema docs still thin.)*

## 2. Relay Schema and TTL

- [x] 2.1 Add a relay migration creating the `routing_push_tokens` table with columns `recipient_routing_id`, `provider`, `push_token`, `expires_at`, `last_seen_at`, `country`, primary key `(recipient_routing_id, provider, push_token)`, index on `recipient_routing_id`, index on `expires_at`. The `country` column defaults to `UNDISCLOSED`. *(See `relay/internal/store/schema/0002_routing_push_tokens.sql`.)*
- [x] 2.2 Introduce relay configuration: `ROUTING_PUSH_TOKEN_TTL_SECONDS` (default 1209600 = 14 days). *Implementation note (2026-05-19): purge cadence is governed by the existing `SWEEPER_INTERVAL` (default 1m) rather than the originally proposed `ROUTING_PUSH_TOKEN_PURGE_INTERVAL_SECONDS`; see `design.md` § 10.*
- [x] 2.3 Implement the purge job that deletes rows where `expires_at <= now()` on the configured interval. Increment a `purge_count` counter atomically for use by the statistics endpoint. *(Sweeper: `relay/internal/sweeper/sweeper.go` → `PurgeExpiredRoutingPushTokens` + `relay_day_metrics`.)*
- [x] 2.4 Implement opportunistic purge on read paths that already touch the table (registration, dispatch).

## 3. Relay Registration Endpoints

- [x] 3.1 Implement `POST /v1/routing/push/register` accepting `{ provider, push_token, recipient_routing_id, country }`, authenticated against the same routing-identity proof used for envelope ingestion. `country` is required at the protocol level; an omitted or unrecognized value is coerced server-side to `UNDISCLOSED`. *(Wire field: `recipient_identity` in JSON — see `relay/internal/api/routing_push.go`.)*
- [x] 3.2 Implement `POST /v1/routing/push/unregister` accepting `{ provider, push_token, recipient_routing_id }` with the same authentication contract.
- [x] 3.3 Return the resulting `expires_at` in the register response so the client can schedule keep-alive.
- [x] 3.4 Add unit and integration tests covering authenticated success, unauthenticated rejection, TTL refresh on re-register, unregister deletion, country accepted, country `UNDISCLOSED` accepted, and invalid country coerced to `UNDISCLOSED`. *(Unit: `relay/internal/store/routing_push_tokens_test.go` — `NormalizeCountryCode`. Integration: `relay/internal/integration/routing_push_integration_test.go` — register/unregister lifecycle, `no_active_routing`, country normalization; requires `RELAY_INTEGRATION_TEST_DSN`.)*

## 4. Relay Wake Dispatch

- [x] 4.1 Add FCM v1 dispatcher reading `FCM_SERVICE_ACCOUNT_JSON_PATH`. *(See `relay/internal/push/fcm.go`.)*
- [x] 4.2 Add APNs dispatcher reading `APNS_AUTH_KEY_PATH`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_ENVIRONMENT`. *(See `relay/internal/push/apns.go`; functional QA deferred — FCM-only for now.)*
- [x] 4.3 Hook the dispatcher into the envelope persistence path: after a successful envelope write, look up active rows for the envelope recipient and fan out a data-only wake push `{ "v": 1, "kind": "wake_for_inbox", "recipient": "<routing-id>" }`. *(See `relay/internal/api/api.go` when `WakePushDispatchEnabled`.)*
- [x] 4.4 Treat dispatch as best-effort: log per-token failures with provider and error class, never block envelope delivery, eagerly purge rows whose provider reports a permanent token error. Increment `dispatch_success_count` and `dispatch_failure_count` atomically for use by the statistics endpoint.
- [x] 4.5 Add a feature flag that disables dispatch without affecting registration acceptance so the relay can ship the schema and endpoints ahead of the dispatcher being enabled in production. *(`WAKE_PUSH_DISPATCH_ENABLED`, default false.)*
- [x] 4.6 Add an opt-in fallback (`APNS_GENERIC_ALERT_ENABLED`) that, on iOS only, adds a constant non-personalized alert to the push when field testing shows iOS throttling. Default: off. *(Wired via `APNS_GENERIC_ALERT_BODY` in relay config.)*

## 5. Daily Statistics: Loopback Endpoint, Cron, and Append-Only File

- [x] 5.1 Implement `GET /internal/stats/daily?date=YYYY-MM-DD` in the relay. Listen exclusively on `STATS_LISTEN_ADDR` (default `127.0.0.1:9091`; set to `-` to disable). *Originally proposed as `STATS_ENDPOINT_LISTEN_ADDR`; renamed at implementation — see `design.md` § 10.* Reject any request that does not arrive over the loopback interface. Default `date` to the previous calendar day in UTC.
- [x] 5.2 Compute the response in code (no ad-hoc queries) so the audit reviewer can inspect what fields are derivable: `active_total`, `by_country` (subject to the suppression rule below), `by_provider`, `dispatch_success_count`, `dispatch_failure_count`, `purge_count`, `routing_push_tokens_row_count`.
- [x] 5.3 Implement the country suppression rule in a named source constant `kCountrySuppressionThreshold = 10` (or language-appropriate equivalent). Sum all countries with strictly less than 10 active devices into an `OTHER` bucket. Treat `UNDISCLOSED` as its own bucket, never folded into `OTHER`. *(See `relay/internal/stats/handler.go` + `handler_test.go`.)*
- [x] 5.4 Implement and ship a cron job (in the same repository, packaged with the relay deployment artifacts) that runs at `7 0 * * *` UTC (i.e. 00:07 UTC daily), calls the endpoint for the previous calendar day, and appends one JSON line to `STATS_FILE_PATH` (default `/srv/compartarenta-stats/daily.jsonl`, read by `relay/scripts/daily-stats-append.sh` — the binary itself does not write the file).
- [x] 5.5 Make the cron idempotent: if the target date already has a line in the file, do nothing.
- [x] 5.6 Document, in a brief operator-facing README colocated with the cron script, the file format, how to publish or share the file, and the explicit guarantee that the relay DB itself is never queried by humans. *(See `relay/scripts/README-daily-stats.md` + `docs/relay-deployment.md`.)*
- [x] 5.7 Unit tests: suppression threshold is applied correctly across boundary cases (0, 9, 10, 11 devices); endpoint refuses non-loopback callers; cron append-only behavior; cron idempotency on re-run for the same day. *(`relay/internal/stats/handler_test.go`; cron idempotency in `relay/internal/integration/push_delivery_integration_test.go` — integration tests require `RELAY_INTEGRATION_TEST_DSN`.)*

## 6. Mobile Client: Token Plumbing

- [x] 6.1 Add `ClosedAppPushRegistrationService` under `mobile/lib/notifications/` with `register(routingId, provider, pushToken, country)` and `unregister(routingId, provider, pushToken)` calls to the relay.
- [x] 6.2 Reuse existing routing identity authentication when calling the relay; no new auth scheme is introduced on the client.
- [x] 6.3 Wire the existing `PushNotificationService` token acquisition and refresh listener to call into `ClosedAppPushRegistrationService`. Source the current country value from the country-disclosure preference (see Section 9b). *(Installed from `app.dart`; `onTokenRefresh` → `sync()`.)*
- [x] 6.4 Skip all calls when the platform is web; web continues to operate via foreground polling and developer test notifications only.

## 7. Mobile Client: Keep-Alive

- [x] 7.1 Refresh registration on app cold start and foreground resume when more than half the TTL has elapsed since the last refresh. *(`ClosedAppPushRegistrationService.syncIfNeeded` + `app.dart` resume hook.)*
- [x] 7.2 Refresh registration on receipt of any wake push. *(Foreground + background wake paths call `sync(force: true)` / `runClosedAppPushRegistrationRefreshOnce()`.)*
- [x] 7.3 Schedule an Android `WorkManager` periodic refresh task with reasonable network and battery constraints. *(`closed_app_push_workmanager_io.dart` + `bootstrap.dart`.)*
- [ ] 7.4 Schedule an iOS `BGAppRefreshTask` for opportunistic refresh. *(Deferred — APNs / iOS out of current functional scope.)*
- [x] 7.5 Re-register on FCM and APNs token rotation events; unregister the previous token before registering the new one. *(`onTokenRefreshed` + `PushNotificationService` token listener.)*
- [x] 7.6 Gate registration on the existing app-level master notification switch and on any wake-eligible category preference. When either is disabled, unregister and skip future refreshes. *(`hasWakeEligibleCategoryEnabled` + `_shouldRegister` in `ClosedAppPushRegistrationService`.)*

## 8. Mobile Client: Wake Handler

- [x] 8.1 Extend the existing background message handler (`push_notification_background.dart`) to recognize `kind = "wake_for_inbox"` payloads.
- [x] 8.2 On wake receipt, trigger a one-shot poll cycle for the recipient routing id. *(See `runWakeInboxPollOnce` → `processAllPendingHandshakes` + `pollSteadyStateInboxes` + `pollHousingPaymentReminders`; `AppDatabase.bindProcessScope` in background isolate — 2026-07-08.)*
- [x] 8.3 After polling, run the existing decrypt + local notification builders for whichever envelope kinds match V1 scope (Contacts add request only in this change). *(Poll path covers Contacts handshakes, housing inbox, and relay-scheduled payment reminders — broader than original V1 Contacts-only scope.)*
- [x] 8.4 Ensure the wake handler honors the existing master switch and category preferences before surfacing a local notification. *(Per-kind builders consult `AppPreferences`.)*

## 9. Mobile Client: Settings Integration

- [x] 9.1 Surface the closed-app push wake mechanism as a transparent infrastructure feature, not a new user-facing toggle. Documentation under Settings > Notifications can mention "wake from sleep" if helpful, but no new switch is added in V1. *(`settingsNotificationsWakeFromSleepBody` under master switch.)*
- [x] 9.2 Verify that toggling the master switch or the Contacts add request category correctly triggers register / unregister calls. *(Master switch + category prefs re-sync registration via `app.dart` listener.)*

## 9b. Mobile Client: Country Disclosure (Opt-In)

- [x] 9b.1 Add an app-level preference `countryDisclosureEnabled` (default off) and `disclosedCountryCode` (default null, meaning `UNDISCLOSED` on the wire). *(Stored as `notificationCountryStatisticsEnabled` / `notificationCountryStatisticsCode` in `AppPreferences`.)*
- [x] 9b.2 Add a Settings entry (placement: Settings > Notifications, or Settings > Privacy if a Privacy section exists) with a localized switch labeled in FR / EN / ES along the lines of "Disclose my country for anonymous statistics" and a localized country dropdown that is enabled only when the switch is on.
- [x] 9b.3 Provide the country dropdown using ISO 3166-1 alpha-2 codes. Display localized country names in FR / EN / ES; the stored value is always the ISO code. Either ship a small built-in map for the three target locales or reuse an existing localized country list source already vetted for the project. *(See `routing_push_country_codes.dart` + picker sheet.)*
- [x] 9b.4 On every register/refresh call, send the current effective country: the selected ISO code when the switch is on, or `UNDISCLOSED` when the switch is off, when no country has been picked yet, or on web (which never registers anyway).
- [x] 9b.5 When the user toggles the switch or changes the selected country, trigger an immediate register-with-current-country call so the relay row reflects the new value before the next opportunistic refresh.
- [x] 9b.6 Tests: switch off → `UNDISCLOSED` is sent; switch on without selection → `UNDISCLOSED`; switch on with selection → ISO code is sent; toggling the switch off after a disclosure → next call sends `UNDISCLOSED` and the relay overwrites. *(`mobile/test/closed_app_push_registration_service_test.dart`.)*

## 10. Testing

- [x] 10.1 Relay unit tests: TTL refresh, expired row purge, provider permanent-error eager purge, fan-out to multiple tokens, best-effort dispatch failure isolation, country accepted / coerced. *(Store + stats unit tests; dispatch/purge/fan-out in `push_delivery_integration_test.go` with DSN.)*
- [x] 10.2 Relay integration tests: end-to-end envelope ingestion triggers wake dispatch to a mocked FCM/APNs provider; daily statistics endpoint produces correct aggregates with seeded data; cron job appends one valid JSON line per day and is idempotent. *(`relay/internal/integration/push_delivery_integration_test.go` — requires `RELAY_INTEGRATION_TEST_DSN`.)*
- [x] 10.3 Mobile unit tests: register/unregister calls under master-switch and category combinations, keep-alive refresh windows, token rotation handling, country preference behavior (Section 9b.6). *(`mobile/test/closed_app_push_registration_service_test.dart`.)*
- [x] 10.4 Mobile integration tests: wake handler triggers a poll and produces the existing Contacts add request notification. *(`mobile/test/wake_inbox_poll_integration_test.dart`.)*
- [x] 10.5 Field test on TestFlight and Play Store internal track for at least one week to validate iOS background throttling assumptions and Android battery optimization behavior. *(Android validated 2026-07-08: physical device `R3CY202HKYL`, run `20260708T235740Z`, scenario `fcm_wake_push_emulator_physical` — FCM wake → poll → housing proposal notification tray; logcat confirms no `GCM CANCELLED` / no `processScope` error. TestFlight / iOS deferred.)*
- [x] 10.6 FCM wake manual QA scenario: seeded Monica emulator + physical recipient, `tool/qa_fcm_wake_establish_relay_routing.sh`, recipient `am kill` (not `force-stop`), proposer submit-only Maestro flow, operator/logcat notification check. *(Manifest `qa/multi_scenarios/fcm_wake_push_emulator_physical.yaml`; entry `./tool/melosw run qa:run-fcm-wake-push`; validated 2026-07-08.)*

## 11. Operations and Audit

- [x] 11.1 Document the new schema (including the `country` column), TTL, dispatch contract, statistics endpoint, cron, and stats file under `docs/relay-deployment.md` and `docs/relay-state-schema.md` (or equivalent) so the audit reviewer can trace the contract.
- [ ] 11.2 Confirm with the auditor that the privacy posture relaxation described in `specs/closed-app-push-delivery/spec.md` is acceptable before enabling the dispatcher in production. Specifically have the auditor confirm: TTL default of 14 days, hardcoded country suppression threshold of 10, loopback-only statistics endpoint, append-only stats file, no humans querying the DB.
- [x] 11.3 Provision FCM Service Account JSON and APNs auth key in the relay deployment environment; document rotation procedure. Time the Apple Developer Program subscription to coincide with the first real-device iOS test rather than at project kickoff (see design.md §11 "Account and secrets sequencing"). *(FCM: provisioned on VPS, `roles/firebasecloudmessaging.admin` on service account, `WAKE_PUSH_DISPATCH_ENABLED` — validated 2026-07-08. APNs auth key deferred.)*
- [x] 11.4 Cut a relay release with the schema and endpoints behind the dispatcher flag; verify that running with the flag off has zero behavioral impact on existing clients. *(v0.2.0 baseline recorded with dispatch disabled — see `docs/relay-audit-log.md`.)*
- [x] 11.5 Enable the dispatcher flag in production after audit sign-off and after field testing completes. *(Enabled for current VPS Android QA; housing proposal wake notification validated on physical device 2026-07-08. Formal auditor sign-off tracked under **11.2**.)*
- [ ] 11.6 Install the cron job under the operating-system user that owns the relay process. Verify after one full day that the stats file received its first line at 00:07 UTC.

## 12. Follow-Up Scope (Out of V1, Tracked Here)

- [x] 12.1 After V1 stabilizes, opt the Contacts add request response notification into wake dispatch on the client side (no relay change required). *(Contacts add request was already wake-eligible in V1; unchanged.)*
- [x] 12.2 After V1 stabilizes, opt Housing plan offer and response notifications into wake dispatch on the client side (no relay change required). *(See `AppPreferences.hasWakeEligibleCategoryEnabled` — `notificationHousingPlanSubmission` + `notificationHousingDecisionChange`; test in `closed_app_push_registration_service_test.dart`.)*
- [ ] 12.3 Reassess the TTL default after one quarter of production data on active-device counts.
- [ ] 12.4 Decide whether iOS degraded-mode generic alert should ship by default based on field-test data.
- [x] 12.5 **Operator manual notification trigger.** VPS-only CLI `relay operator-notice` (not from the app, not a public HTTP API). FCM data-only `kind=operator_notice` with optional `target_build` and `consult_site`; long copy stays on `https://bojairu.app`. Fan-out is distinct non-expired FCM tokens (Android only; no APNs). In-app page shows the Play update affordance only when the installed build is strictly below the target. Spec detail: `specs/closed-app-push-delivery/spec.md`. Ops command: `deploy/2026-07-24-HOW-TO-DEPLOY.md` (Operator notice) and `docs/relay-deployment.md`.
