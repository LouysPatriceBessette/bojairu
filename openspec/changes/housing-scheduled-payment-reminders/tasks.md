# Tasks — relay scheduled notifications

> **Implementation status (2026-07-13).** **Housing payment reminders** (relay
> schema v3, reconciliation API, reminder cron, client
> `HousingPaymentReminderService`, Settings category, overdue/before-due journal,
> EN/FR/ES copy, Settings timezone → relay upsert **2.2b**, operator docs **1.5**)
> are **implemented** for native (Android) paths. Maestro QA for inventory **#10**
> (before_due ×3) and **#11** (overdue) is **done** via simulated client display +
> tap (**3.4**). End-to-end relay path **3.3** is **won't do** (wake push and
> in-app payment-reminder notifications already proven). Relay cron claim
> integration test (**3.1**) remains **open**.

## 0. Product decisions

- [x] OQ.1 Relay replaces local scheduling for **housing payment** reminders.
- [x] OQ.2 Tiered before-date (W&lt;20 / 20–40 / &gt;40) **including due day J**; **14:00** local; relay IANA timezone.
- [x] OQ.3 Overdue payment reminders in scope.
- [x] OQ.4 Fifth relay category; scheduling timestamps allowed.
- [x] OQ.5 Web out of scope.
- [x] OQ.6 Coverage: `unitMinor` + sliding period + carry between periods.
- [x] OQ.7 `everyNDays` sliding window.
- [x] OQ.8 Housing payment: unanimity-establishing client only for schedule reconciliation.

## 1. Relay (release + audit)

- [x] 1.1 Migration `0003_scheduled_notifications.sql` (`scheduled_notification_*`, `recipient_notification_timezone`) + `schema_shape_test.go`. *(See `relay/internal/store/schema/0003_scheduled_notifications.sql`; version bump asserted in `schema_shape_test.go`.)*
- [x] 1.2 Reconciliation ingest + timezone upsert + tiered `fire_at` computation (14:00 local). *(See `relay/internal/api/scheduling.go`, `relay/internal/store/scheduled_notifications.go`, `relay/internal/scheduling/firetimes.go` + tests.)*
- [x] 1.3 Reminder cron + metrics + `REMINDER_CRON_ENABLED`. *(See `relay/internal/remindercron/remindercron.go`, `relay/cmd/relay/main.go`.)*
- [x] 1.4 On fire: mark row, enqueue `scheduled_reminder_due`, dispatch wake. *(Fires claimed in store; wake push when `WakePushDispatchEnabled`; client pulls pending rows via `GET /v1/scheduling/pending` rather than a steady-state envelope — see `relay_scheduling.dart`.)*
- [x] 1.5 Audit checklist + deployment docs. *(See `docs/relay-deployment-scheduled-notifications.md` + link from `docs/relay-deployment.md`.)*

## 2. Client — housing payment reminders

- [x] 2.1 Sliding-window period + carry attribution helper (adapt from chart carry). *(See `payment_period_coverage.dart`, `housing_payment_reminder_service.dart`; unit test in `payment_period_coverage_test.dart`.)*
- [x] 2.2 Reconciliation on E.1–E.4 and publish (unanimity sender); timezone upsert on E.1 + activation import. *(See `HandshakeOrchestrator._reconcileHousingPaymentRemindersAfterActivation`, `_maybeReconcileHousingRemindersAfterExpenseAccept`.)*
- [x] 2.2b Settings timezone change → upsert + pending fire recompute when active housing plan. *(See `HousingPaymentReminderService.onTimeZonePreferenceChanged`, `HandshakeOrchestrator.syncHousingPaymentReminderTimezone`, listener in `app.dart`.)*
- [x] 2.3 Envelope codecs + metadata strip. *(Delivered via scheduling HTTP JSON codecs in `relay_scheduling.dart` / `RelayClient.fetchPendingReminderDeliveries` — not a steady-state encrypted envelope kind.)*
- [x] 2.4 Notification builder + Settings category + deep link. *(See `PushNotificationService.showLocalHousingPaymentReminderNotification`, Settings switch `notificationHousingPaymentReminders`; payload `housing_payment_reminder|…` → Accepted expenses journal; Maestro QA **#10/#11** via **3.4**.)*
- [x] 2.5 Overdue / before-due journal: local persistence + cards in `HousingMonthlyExpensesScreen` (no card navigation). *(Table `housingPaymentOverdueJournalEntries`; before_due + overdue cards; Maestro **3.4**.)*
- [x] 2.6 l10n EN/FR/ES for overdue journal copy. *(ARB keys `housingOverdueJournalCardBody`, payment reminder push strings.)*

## 3. Tests

- [ ] 3.1 Relay: cron claim, tiered before-date table, timezone reschedule, skip past fires, 14:00-not-midnight. *(Tiered 14:00 table covered in `firetimes_test.go`; cron claim integration tests still open.)*
- [x] 3.2 Client: coverage + carry; before-date vs overdue recipient rules; overdue journal card. *(See `payment_period_coverage_test.dart`, `housing_payment_reminder_recipients_test.dart`, `housing_ready_specs_tasks_test.dart`; overdue journal card UI in `housing_monthly_expenses_screen.dart` — widget test still open.)*
- [x] 3.3 Integration: activation → fire → wake → notification (native). **Won't do (2026-07-13):** wake push is already proven functional; housing payment-reminder notifications on the app side are too. Nothing further to demonstrate for this chain.
- [x] 3.4 **Android E2E QA (Maestro):** inventory **#10** before_due (J−4, J−2, due day J) + **#11** overdue — simulated local notification display + shade tap + Accepted expenses journal asserts; no relay. *(Manifest `qa/multi_scenarios/housing_payment_reminder_before_due.yaml`; `./tool/melosw run qa:run-payment-reminder`; QA’ed 2026-07-13.)*

## 4. Invitation expiry (deferred)

> Product decisions for `contacts_invitation_expiry` (`before_expiry` +
> `expired`, lead-time table, FR/EN copy, Settings gating) are locked in
> `specs/scheduling-deadline-and-invitation-reminders/spec.md` and design
> **D-invitation** (2026-07-13). **Do not implement** until a relay release
> adds client-supplied `fires[]` ingest (may share with proposal deadline
> `housing_proposal_deadline`). No new SQL migration expected (`0003` already
> allows the domain).

- [x] 4.1 Relay: authenticated upsert/cancel for domain `contacts_invitation_expiry` accepting client `fires[]` (`fire_at` wall-clock); skip/no-op for past instants already handled client-side; cancel by invitation `scope_key`.
- [x] 4.2 Client: on invitation create, register `before_expiry` + `expired` per validity table; cancel on used/revoked/extend; deliver via pending-deliveries → local notification; gate on `notificationContactInvitationExpiration`; deep link to outstanding invitations; EN/FR/ES ARB.
- [x] 4.3 Tests: lead-time helper unit tests; revoke/use cancel; notification copy; optional Maestro simulated display later.
- [x] 4.4 Mark `contacts-module` task **3.7** done when 4.1–4.2 land; update operator docs if new HTTP paths are added.

## Dependencies

- `closed-app-push-delivery`
- `housing-active-agreement-operations` (published expenses, activation)
- `housing-unified-expense-entry` (recurrence, payment responsible)
- Task **3.9** relay-visible expense metadata (align fields)
