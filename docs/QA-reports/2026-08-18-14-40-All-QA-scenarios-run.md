# Android Maestro catalog re-run — 17–18 August 2026

**Product:** Bojairũ (Android + iOS in production; Flutter web is local multi-instance QA only).  
**Platform verified here:** Android (emulator + one physical device). iOS automated and device QA remain deferred.  
**Window:** 17 August 2026 (after housing seeds became relative to today) through **18 August 2026, 14:40** (America/Toronto).  
**Operator:** developer catalog re-run. Agents did **not** launch Maestro.  
**Clock:** `device_date: current` (today). Housing “day after period end”, “last settlement day”, and similar states come from **seed dates relative to today**, not from pinning the emulator to 2027.  
**Relay:** production `https://sync.incoherences.org` for multi-device and FCM scenarios. Single-device housing / vehicle / sale / rent-reminder runs did **not** use the relay.  
**APK:** `app-dev-debug.apk` rebuilt after the relative-date seed change (and after last-day / wizard semantics). Later YAML-only and coordinator-only edits used `--skip-build`.

This report is the committed record of the checklist in `dev-ideas/` (operator notes, not in git). How to run the toolchain: `docs/qa-android-e2e.md`.

**Verdict:** every **catalog** scenario that was executed **passed**. Three vehicle-sharing **seed** scenarios were **not run** on purpose (starting-data fixtures for manual exploration, not catalog proof). A few **test-only** Maestro / selector / seed-clock adaptations were required after moving to `device_date: current`; they were not treated as product defects.

---

## Scope

| Included | Excluded |
| --- | --- |
| Single-device housing hub gating and plan-draft wizard | Vehicle-sharing seed fixtures (see § Not run) |
| Single-device vehicle owner paths | iOS |
| Sale export/import (+ undo) orchestrators | Flutter web as a product surface |
| Rent-payment reminder orchestrator (Monica-QA) | Play billing smoke / AAB upload |
| Two-AVD handshake, housing proposal, bug 1.22, vehicle-sharing **offer** | Full `cd mobile && ./tool/flutterw test` suite (developer-owned) |
| FCM wake: Monica-QA emulator + Louys Samsung Galaxy S25 | |

Success lines (orchestrator):

- Typical: `Scenario PASSED | <id>` or `Test PASSED | <id>`
- Rent reminders: `Done. Artifacts:` plus operator visual check of journal cards
- FCM: `Automation PASSED | fcm_wake_push_emulator_physical` **and** operator confirmation that the phone showed the notification

---

## Devices

| Role | Device | Used for |
| --- | --- | --- |
| Monica QA / housing single-device | AVD **Bojairu-QA** (`emulator-5554`) | §1–2, sale export/import |
| Monica QA | AVD **Monica-QA** (`emulator-5556`) | Rent reminders; multi-device inviter / proposer |
| Louys QA | AVD **Louys-QA** (`emulator-5554`) | Multi-device invitee / recipient / vehicle owner |
| Louys (physical) | Samsung Galaxy S25 (USB) | `fcm_wake_push` only |

---

## §0 APK

| Item | Result | Notes |
| --- | --- | --- |
| `qa:build-apk` → `app-dev-debug.apk` | Done | Required after relative housing seeds (and after last-day / wizard Dart). |

```bash
./tool/melosw run qa:build-apk > mobile/terminal.log 2>&1
```

---

## §1 Single emulator — Housing (Bojairu-QA)

No relay. Persona: Monica QA with a seeded plan. Clock = today.

| Scenario | Result | What was checked |
| --- | --- | --- |
| `settlement_open` | Pass | Term ended yesterday, published expense, non-zero balances → **Settle a due** tile present. |
| `settlement_last_day` | Pass | Today = last inclusive day of the one-month settlement window → settlement tile (last-day semantics id). |
| `settlement_closed` | Pass | Window ended yesterday → settlement tile gone; submit expense disabled. |
| `period_end_day` | Pass | Term ended yesterday, nothing to settle → expense tile disabled. |
| `renewal_fork_visible` | Pass | **New term from current plan** tile visible. |
| `voluntary_withdrawal_ack_j5` | Pass | Participation banner on last day to acknowledge Louys’s withdrawal. |
| `voluntary_withdrawal_effective` | Pass | Withdrawal already acknowledged and effective today → banner gone. |
| `proposal_wizard_expenses` | Pass | Draft wizard: three expenses, recurrence **15 then 20 of the current month**, summary, response-deadline dialog, Cancel. |
| `proposal_response_expired` | Pass | Open proposal past the response deadline → archive **Expired proposal**. |

Commands (each overwrites `mobile/terminal.log`):

```bash
./tool/melosw run qa:run-scenario -- settlement_open --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- settlement_last_day --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- settlement_closed --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- period_end_day --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- renewal_fork_visible --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- voluntary_withdrawal_ack_j5 --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- voluntary_withdrawal_effective --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- proposal_wizard_expenses > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- proposal_response_expired --skip-build > mobile/terminal.log 2>&1
```

(`proposal_wizard_expenses` was run **without** `--skip-build` after the recurrence-day semantics change.)

---

## §2 Single emulator — Vehicle (Bojairu-QA)

Clock = today. QA Civic seeded except `vehicle_add`.

| Scenario | Result | What was checked |
| --- | --- | --- |
| `vehicle_add` | Pass | Empty hub → create “Mon QA” (Honda Civic) until the hub card appears. |
| `vehicle_use_session` | Pass | Start session (50% tank), complete at 50 700 km / 25%. |
| `vehicle_fuel_purchase` | Pass | Fuel purchase 80 $, 45 L, 50 000 km; return to hub. |
| `vehicle_consumption` | Pass | Odometer **51 397,0 km** and L/100 on the Civic card. |
| `vehicle_session_start_gap` | Pass | Start at 50 100 km vs last 50 000; confirm differential; hub shows 50 100 km. |
| `vehicle_standalone_meter_gap` | Pass | Standalone meter reading 50 100 km; confirm; stay on detail. |

```bash
./tool/melosw run qa:run-scenario -- vehicle_add --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- vehicle_use_session --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- vehicle_fuel_purchase --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- vehicle_consumption --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- vehicle_session_start_gap --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-scenario -- vehicle_standalone_meter_gap --skip-build > mobile/terminal.log 2>&1
```

---

## §3 Single-emulator orchestrators (not in `qa/scenarios/`)

| Run | Result | Evidence |
| --- | --- | --- |
| `vehicle_sale_export_import` | Pass | `Scenario PASSED \| vehicle_sale_export_import` — artifacts `20260818T020420Z`. Export → full emulator stop → empty Louys seed → import → QA Civic card. No relay. |
| `vehicle_sale_export_import_undo` | Pass | `Scenario PASSED \| vehicle_sale_export_import_undo` — artifacts `20260818T021224Z`. Same path then **Undo import**. |
| Rent payment reminders (`qa:run-payment-reminder`) | Pass | `Done. Artifacts:` `20260818T024120Z`. AVD **Monica-QA**, no relay. Four clock advances (J−4, J−2, due day, overdue). Operator later confirmed the four journal cards (August J−4/J−2; September due + overdue). Overdue card uses peach/orange, not red. After the run the last tap is previous-month, so the live UI can remain on August — that is not a product miss. |

```bash
./tool/melosw run qa:run-vehicle-sale-export-import -- --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-vehicle-sale-export-import-undo -- --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-payment-reminder -- --skip-build > mobile/terminal.log 2>&1
```

---

## §4 Two emulators (Louys-QA + Monica-QA) — production relay

| Scenario | Result | Evidence |
| --- | --- | --- |
| `contact_handshake_happy_path` | Pass | `Test PASSED \| contact_handshake_happy_path` — artifacts `20260818T120746Z`. Both sides connected. |
| `contact_handshake_bug_91` | Pass | `Test PASSED \| contact_handshake_bug_91 (verdict: COULD_NOT_REPRODUCE — CASE CLOSED)` — artifacts `20260818T161635Z`. **4/4** clean bilateral handshakes (`clean=4`, `infra=0`). Inviter Contacts list shows Louys. |
| `housing_proposal_happy_path` | Pass | `Test PASSED \| housing_proposal_happy_path` — artifacts `20260818T173140Z`. Both land on `qa-housing-active-hub`. |
| `housing_proposal_bug_122` | Pass | `Test PASSED \| housing_proposal_bug_122 (verdict: COMPLETED)` — artifacts `20260818T175233Z`. Duplicate-Monica guard + happy path + anchor-reject banner. `completed=1`, `infra_fail=0`. |
| `vehicle_sharing_offer_happy_path` | Pass | `Test PASSED \| vehicle_sharing_offer_happy_path` — artifacts `20260818T181717Z`. Borrower taps offer notification and Accepts; owner taps accept notification; hub shows active share on QA Civic. |

```bash
./tool/melosw run qa:run-multi-scenario -- contact_handshake_happy_path --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- contact_handshake_bug_91 --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- housing_proposal_happy_path --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- housing_proposal_bug_122 --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_offer_happy_path --skip-build > mobile/terminal.log 2>&1
```

---

## §5 Emulator + physical phone (S25, USB)

| Scenario | Result | Evidence |
| --- | --- | --- |
| `fcm_wake_push` | Pass | `Automation PASSED \| fcm_wake_push_emulator_physical` — artifacts `20260818T182853Z`. Monica-QA submits a housing plan; Louys S25 process killed with `am kill` (not force-stop). **Operator confirmed the Android notification on the S25.** |

```bash
./tool/melosw run qa:run-fcm-wake-push -- --skip-build > mobile/terminal.log 2>&1
```

---

## Not run (by design)

These three are **seed fixtures**: they load a starting database for **manual** exploration. They are not catalog proof of a user journey. The operator chose **not** to re-run them for this review.

| Scenario | Purpose if run later |
| --- | --- |
| `vehicle_sharing_active_seed` | Direct seed of an already-active Civic share; hub asserts both sides; apps left open. |
| `vehicle_sharing_usage_history_seed_2nd_fill` | Active share plus journal through the 2nd fill. |
| `vehicle_sharing_usage_history_seed_3rd_fill` | Continuation: 3rd fill, Monica catch-up, session closed at 52 000 km. |

```bash
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_active_seed --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_usage_history_seed_2nd_fill --skip-build > mobile/terminal.log 2>&1
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_usage_history_seed_3rd_fill --skip-build > mobile/terminal.log 2>&1
```

---

## Test-only adaptations during this re-run

None of the following was treated as a product screenshot bug. Historically PASSED scenarios that failed on the first attempt after `device_date: current` were selector / seed-clock mismatches.

| When | Scenario | What failed | What changed |
| --- | --- | --- | --- |
| 17 Aug | `settlement_last_day` | In-app assert on the tile **subtitle** text. `_HubTile` uses `excludeSemantics`; label is the title only. | Same tile node: `qa-housing-hub-settlement-last-day` on the last inclusive window day, otherwise `qa-housing-hub-settlement-due`. A nested second `Semantics` id was tried and **reverted** (inner settlement id vanished). Evidence: Pass `20260817T235532Z`. |
| 17–18 Aug | `proposal_wizard_expenses` | Flow waited on `qa-housing-expense-recurrence-day-2027-06-15` while the picker showed **August 2026**. | First-month days 15 and 20 use `qa-housing-expense-recurrence-day-15` / `…-20`. Draft period relative to today. Evidence: Pass `20260818T011959Z` (APK rebuild). |
| 18 Aug | Rent reminders | Probe script `FAILED: no journal title` while Maestro had already seen the journal. | Coordinator **process** timeout around `maestro test` was 25 s; device attach ~19 s. Probe wall set to **90 s**. YAML wait unchanged. Evidence: `20260818T024120Z`. |
| 18 Aug | `contact_handshake_bug_91` | Assert `qa-contacts-row-louys-qa` on Monica while she was still on **Invitation codes**, not Contacts. First “CASE CLOSED” had `clean=0` / `infra=10`. | Inviter flows run `_navigate_inviter_to_contacts_list` before the Louys row. Attempts reduced **10 → 4**. Removed a 60 s **optional** `notVisible` wait on the invitation short-code (true or false did not change the verdict). Evidence: Pass `20260818T161635Z`, `clean=4`. |

Lessons: `.cursor/skills/maestro-scenario-avoid-carpet-tripping/SKILL.md` and `.cursor/rules/I-am-learning-Maestro-autonomously.mdc`.

---

## Counts

| Category | Count |
| --- | --- |
| Housing scenarios passed | 9 |
| Vehicle scenarios passed | 6 |
| Single-device orchestrators passed | 3 |
| Two-AVD scenarios passed | 5 |
| FCM (emulator + S25) passed | 1 |
| **Total executed and passed** | **24** |
| APK rebuild (prerequisite, not a scenario) | 1 |
| Seed fixtures not executed | 3 |
| Product bugs opened from this catalog re-run | 0 |

---

## Related OpenSpec

Dated testimony of this review: `openspec/changes/repo-maintenance-backlog/tasks.md` (Done). Module E2E task lists remain in their changes (`housing-post-agreement-settlement-window`, `housing-active-agreement-operations`, `housing-plan-proposal-offer-and-responses`, `contacts-module`, `vehicle-module`, `vehicle-sharing-module`, `housing-scheduled-payment-reminders`, `closed-app-push-delivery`).
