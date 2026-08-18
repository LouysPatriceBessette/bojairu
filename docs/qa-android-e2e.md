# Manual Android QA / E2E

This document is the **user guide** for Bojairũ's local Android QA toolchain:
a pinned emulator, programmable clock, programmatic database seeding, and Maestro
UI flows with screenshots.

Runs are **manual** on your machine. There is **no CI** integration for this
toolchain.

## Catalog run reports

Operator-verified catalog runs (dated) live under `docs/QA-reports/`.

Latest full Android Maestro catalog re-run after housing seeds used dates
**relative to today** (`device_date: current`):  
[`docs/QA-reports/2026-08-18-14-40-All-QA-scenarios-run.md`](QA-reports/2026-08-18-14-40-All-QA-scenarios-run.md)
(17–18 August 2026). Three vehicle-sharing **seed** fixtures were left unrun by
design (manual starting data). iOS QA remains deferred.

## What you get

| Layer | Role |
| --- | --- |
| **Emulator** | Fixed AVD `Bojairu-QA` (API 34, Pixel 7 profile) |
| **Clock** | Push a scenario date on the emulator only (`set_android_date.sh`) |
| **Seed** | Populate Drift + prefs from Dart (`qa_scenario_seed.dart`, debug Android) |
| **Maestro** | Navigate the app, assert UI, capture screenshots |
| **Orchestrator** | Shell scripts tie the layers together per scenario or for a full run |
| **Guardrails** | Manifest validation, Maestro ↔ Dart semantics checks, HTML report |

## Prerequisites

- **Android SDK** with `platform-tools`, `emulator`, and `cmdline-tools`
- `ANDROID_SDK_ROOT` or `ANDROID_HOME` (defaults to `~/Android/Sdk` when present)
- **Java 17+** (Gradle / Flutter Android builds)
- **Flutter** deps resolved for `mobile/` (scripts call `./tool/flutterw` via melos)
- **Python 3** (manifest parsing, verification, HTML report)
- **Network** for the first system-image download and Maestro CLI install
- **Maestro CLI** (installed once via `./tool/install_maestro.sh` → `~/.maestro/bin`)

Use a **physical device only if you know what you are doing**. By default, QA
scripts target the **emulator** (`emulator-*`) and refuse to change a phone's
clock.

## One-time setup

From the repository root:

```bash
./tool/melosw run qa:create-avd
./tool/melosw run qa:install-maestro
./tool/melosw run qa:build-apk
```

For a locked-in Simulation build (already in sandbox on install; red ribbon
visible but exit disabled), pass `--simulation`:

```bash
./tool/melosw run qa:build-apk -- --simulation
```

Then install/run that APK without rebuilding:

```bash
./tool/melosw run run:dev -- --skip-build
./tool/melosw run run:dev -- --skip-build --fresh   # wipe app data
```

(or `./tool/melosw run qa:install-apk`).

Equivalent shell scripts: `./tool/create_qa_avd.sh`, `./tool/install_maestro.sh`,
`./tool/build_qa_apk.sh` (optional `--simulation`).

Verify the toolchain:

```bash
./tool/melosw run qa:verify
```

This checks phase-0 prerequisites (SDK, AVD, Maestro, optional APK/emulator),
validates all scenario manifests, and verifies Maestro `qa-*` ids against Dart
`Semantics.identifier` strings.

### Defaults (override via environment)

| Variable | Default |
| --- | --- |
| `COMPARTARENTA_QA_AVD_NAME` | `Bojairu-QA` |
| `COMPARTARENTA_QA_APP_ID` | `app.incoherences.bojairu.dev` |
| `COMPARTARENTA_QA_SYSTEM_IMAGE` | `system-images;android-34;google_apis;x86_64` |
| `COMPARTARENTA_QA_DEVICE_PROFILE` | `pixel_7` |
| `COMPARTARENTA_QA_DEFAULT_TIMEZONE` | `America/Toronto` |
| `COMPARTARENTA_QA_API_BASE_URL` | `https://sync.incoherences.org` |
| `COMPARTARENTA_QA_APK_PATH` | `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk` |

Local runtime state (clock snapshots) lives under `qa/.local/` (gitignored).
Scenario outputs live under `qa/artifacts/` (gitignored).

## Quick start

### Run one scenario end-to-end

```bash
./tool/melosw run qa:run-scenario -- settlement_open
```

This single command:

1. Starts the QA emulator (or waits if already running)
2. Builds and installs the dev debug APK (unless you pass `--skip-build` / `--skip-install`)
3. Sets the emulator clock from the scenario manifest
4. Seeds the database (clears app data, cold-starts once, applies seed)
5. Runs the Maestro flow with screenshots
6. Restores automatic date/time on the emulator

Artifacts: `qa/artifacts/settlement_open/<UTC-timestamp>/`

### Named device-state snapshots (manual populate → steal → restore)

For Play screenshots (or any loop that needs the **same** starting UI state),
populate the debug app **yourself**, then steal a named long-lived dump to disk
and restore it after wipe as often as you need. Snapshots are **not** inventing
seed data in Dart.

Storage (gitignored): `qa/db_seeds/<name>/`

```bash
# Device already populated (./tool/melosw run run:dev or QA APK)
./tool/melosw run qa:db-snapshot-steal -- --name play-screenshots-v1

# Later: wipe app data and reload that snapshot
./tool/melosw run qa:db-snapshot-restore -- --name play-screenshots-v1
```

Requires **debug** APK (`run-as`). Captures Drift SQLite (+ WAL/SHM when present),
`FlutterSharedPreferences.xml`, and a debug export of the relay identity private
key (EncryptedSharedPreferences cannot survive `pm clear`). Override device with
`ANDROID_SERIAL=…`. Overwrite an existing name with `--force` on steal.

Scripts: `tool/run_db_snapshot_steal.sh`, `tool/run_db_snapshot_restore.sh`.

### Vehicle sale export → import (single emulator)

Local-only portability path (no relay). Mid-run reseed, so it is **not** under
`qa/scenarios/` / `qa:run-all-scenarios`.

```bash
./tool/melosw run qa:run-vehicle-sale-export-import
```

Phases: seed seller history → Maestro export → pull debug zip → **full emulator
stop + cold boot** → seed empty buyer → push import zip → Maestro import → assert
`qa-vehicle-card-qa-civic`.

(The mid-run reseed needs a full AVD restart: a second `pm clear` on the same
running emulator often hangs bootstrap / System UI and never writes
`seed_applied`.)

Artifacts: `qa/artifacts/vehicle_sale_export_import/<UTC-timestamp>/`

Same phases 1–6, then import until « Défaire l'importation » is visible and
tapped (observe undo; no rename / import-confirm path):

```bash
./tool/melosw run qa:run-vehicle-sale-export-import-undo
```

Artifacts: `qa/artifacts/vehicle_sale_export_import_undo/<UTC-timestamp>/`

### Run every scenario + HTML report

```bash
./tool/melosw run qa:run-all-scenarios
```

Discovers all `qa/scenarios/*.yaml`, validates manifests and semantics first, then
runs each scenario sequentially. Output:

```
qa/artifacts/run-<UTC-timestamp>/
  index.html          ← open in a browser
  results.json
  period_end_day/     ← per-scenario Maestro output + PNG screenshots
  settlement_open/
  …
```

The APK is built/installed only for the **first** scenario. The emulator clock
is restored **once** after the full run.

Options (pass after `--` with melos):

| Flag | Effect |
| --- | --- |
| `--skip-build` | Reuse existing `app-dev-debug.apk` |
| `--skip-install` | Do not `adb install` |
| `--skip-restore` | Leave emulator clock as-is after the run |
| `--rebuild-each` | Build and install before **every** scenario (slow; debugging) |

### Manual exploration (no Maestro)

```bash
./tool/melosw run qa:start-emulator
./tool/melosw run qa:build-apk
./tool/melosw run qa:install-apk

./tool/melosw run qa:seed -- settlement_open
# … use the app on the emulator …
./tool/restore_android_date.sh
```

Faster emulator resume (snapshot): `./tool/start_qa_emulator.sh --quick`

### Multi-device scenarios (two emulators)

Some flows (e.g. contact handshake) need **two Android emulators** coordinated by a shell orchestrator.

**One-time:** create persona AVDs (in addition to `Bojairu-QA`):

```bash
COMPARTARENTA_QA_AVD_NAME=Louys-QA ./tool/melosw run qa:create-avd
COMPARTARENTA_QA_AVD_NAME=Monica-QA ./tool/melosw run qa:create-avd
```

**Happy path (inviter Monica-QA + invitee Louys-QA):**

```bash
./tool/melosw run qa:run-multi-scenario -- contact_handshake_happy_path
```

**Bug 9.1 probe (4 attempts, writes `bug_91_result.txt`):**

```bash
./tool/melosw run qa:run-multi-scenario -- contact_handshake_bug_91
```

**Housing proposal happy path (proposer Monica-QA + recipient Louys-QA, both Android):**

The coordinator runs **sequentially**: Monica completes the full plan wizard and sends;
Louys opens Housing, accepts the proposal, and lands on the **active agreement hub**
(`qa-housing-active-hub`). Monica then asserts the same hub — not an invite screen
showing “Louys Accepté” (unanimous activation remounts both devices to the hub).

Rebuild the debug APK after changing QA semantics or flows (do not use `--skip-build`
until a successful run with a fresh build):

```bash
./tool/melosw run qa:run-multi-scenario -- housing_proposal_happy_path
```

**Vehicle sharing offer happy path (owner Louys-QA + borrower Monica-QA):**

Seeds install a **pre-connected** Louys↔Monica pair (fixed debug keys; no
handshake phase) and QA Civic on Louys. The multi-scenario runner seeds once;
the coordinator does **not** `pm clear` again. Monica is warm-started and kept
polling during Louys’s send; the coordinator waits for logcat
`vehicle_sharing_offer imported` before the shade. `KEYCODE_HOME` only
backgrounds an app for shade taps (it does **not** kill the process — force-stop
would clear local notifications). Flow:

1. Louys offers QA Civic (response-deadline dialog → Continue) → outbound pending
   on Partages.
2. Monica: shade assert + **tap** offer notification → hub → **Accepter** →
   accessible QA Civic card.
3. Louys: wait `vehicle_sharing_offer_accept applied=true` and
   `vehicle_sharing_offer_accept notification shown` → shade **tap** accept
   notification → hub shows active-share check
   (`qa-vehicle-sharing-shareable-active-qa-civic`). Accept-notification
   navigation skips push only when already on the hub route itself, so a tap
   from Partages (`/vehicle-sharing/:id/shares`) still opens the hub.

```bash
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_offer_happy_path
```

**Vehicle sharing active seed (manual follow-up):**

Seeds both AVDs directly to the **end state** of
`vehicle_sharing_offer_happy_path` (connected Louys↔Monica, active QA Civic
share — no offer/accept/notification path). Asserts Louys hub green check and
Monica accessible card (session + other-actions chips), then leaves both apps
on home for manual exploration.

At seed, both emulators get the same wall clock: `device_date: current` means
**host now** (date and time) in `America/Toronto`, not a fixed 09:00. The
manifest sets `skip_restore: true` so those clocks stay aligned for manual
follow-up (a single-AVD restore would leave Monica skewed).

```bash
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_active_seed
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_usage_history_seed_2nd_fill
./tool/melosw run qa:run-multi-scenario -- vehicle_sharing_usage_history_seed_3rd_fill
```

`vehicle_sharing_usage_history_seed_3rd_fill` extends the 2nd-fill journal with
the owner's 20 L non-full top-up and 3rd plein, Monica's catch-up of those
fuels (including fill-3), and her closed session ending at 52 000.0 km (synced
onto Louys). Asserts hubs only, then leaves both apps for manual follow-up.

After product Dart changes under `mobile/`, rebuild the APK (omit `--skip-build`).
YAML/bash-only: `--skip-build` is fine.

**Bug 1.22 regression (1 attempt, four phases, writes `bug_122_result.txt`) — resolved Jul 2026:**

Regression guard and duplicate-handshake outcomes after device-binding merge (commit `4489d77`).

1. **Monica drift** — Louys keeps contacts; assert **no** duplicate Monica (`index: 1`, no
   `qa-contacts-duplicate-connected-monica-qa`). **REPRODUCED** if duplicate returns.
2. **Louys drift (no active plan)** — Monica shows **merge** informative dialog
   (`qa-contacts-duplicate-dialog-inviter-merged`).
3. **Housing happy path** — send, accept, active hub (establishes active plan on Monica).
4. **Louys drift (active plan)** — Monica shows **anchor reject** dialog; Louys receives
   notification **#19** and **invitee** informative dialog (must restore data).

**PASS** = `verdict=COMPLETED` in `bug_122_result.txt`.

```bash
./tool/melosw run qa:run-multi-scenario -- housing_proposal_bug_122
```

Manifests live under `qa/multi_scenarios/`. Each declares `role_*` blocks (AVD, seed, flow) and a `coordinator` script in `tool/coordinators/`. Optional `skip_restore: true` keeps the seeded emulator clocks (same as CLI `--skip-restore`). The inviter exports the invitation short code to `app_flutter/compartarenta_qa_handshake_code.txt` for the orchestrator to pass to the invitee Maestro flow (`INVITE_CODE`).

**Relay / TLS note:** scenarios that hit the production relay
(`https://sync.incoherences.org`) must keep `device_date` **inside the relay
certificate validity window**. Prefer `device_date: current` for contact
handshake, housing proposal, FCM wake, and any other flow that calls the relay.
Pinned past dates (e.g. an old calendar day before the cert `notBefore`) yield
`CERTIFICATE_VERIFY_FAILED: certificate is not yet valid`; dates past
`notAfter` yield `certificate has expired`. Housing hub-gating scenarios
(settlement, period end, renewal, withdrawal, expired proposal) use
`device_date: current` and seed `periodEnd` **relative to today** (they do not
talk to the relay during the Maestro run).

Artifacts: `qa/artifacts/multi-<scenario-id>/<UTC-timestamp>/`.

### FCM wake push (emulator + physical device)

Manual check for **closed-app FCM wake** only. Setup is **seeded** (paired contacts +
housing draft on Monica); automation is **kill recipient process → submit plan**
(`am kill`, not `am force-stop` — force-stop blocks FCM delivery on Android).

**Prerequisites:**

1. Physical phone (`R3CY202HKYL` by default), USB debugging, Firebase in the dev flavor.
2. Monica-QA AVD; relay FCM wake enabled on VPS.

The script **builds and installs** the current dev debug APK on **both** emulator and phone
(arm64 + x86_64 fat APK). Recipient `pm clear` wipes app data; the runner **re-grants**
`POST_NOTIFICATIONS` via adb before the seed cold start (Android 13+).

**Run:**

```bash
./tool/melosw run qa:run-fcm-wake-push
```

Pipeline:

1. Seed Monica (`fcm_wake_push_proposer`) — DB + housing draft
2. `tool/qa_fcm_wake_establish_relay_routing.sh` — `handshake/establish` on VPS (**before** recipient cold start)
3. Seed phone (`fcm_wake_push_recipient`) — shell waits for `routing_push.last_refresh_ms` in prefs **before** `am kill`
4. `am kill` on phone (process ended; app not force-stopped — FCM can still wake)
5. Monica taps **Soumettre** (submit-only Maestro flow)
6. Operator watches phone ~45s; relay must not log `push.wake.send_failed`

Manifest: `qa/multi_scenarios/fcm_wake_push_emulator_physical.yaml`. Coordinator:
`tool/coordinators/fcm_wake_push.sh`.

### Housing payment reminders (#10 before-due ×3 + #11 overdue, simulated)

Single **Monica-QA** emulator — **no relay** (client notification display + tap only).

1. Compute monthly Loyer schedule from `device_date: current`
   (`tool/qa_housing_payment_reminder_dates.py`: J−4, J−2, **due day J**, overdue = J+1 @ 14:00 local).
2. **Seed once** (active plan) on J−4 — do **not** `pm clear` between phases so journal
   rows accumulate.
3. **Phase 1** — before_due J−4 → one before-due journal card (July).
4. **Phase 2** — before_due J−2 → two before-due cards (July).
5. **Phase 3** — before_due due day J → before-due card (August); month-prev still has both July cards.
6. **Phase 4** — overdue → red overdue card (+ due-day card on August); July cards persist.

Per phase: `KEYCODE_HOME` → shade-closed screencap MD5 baseline → `expand-notifications` → Maestro tap on **product** shade title (`Rappel de paiement` / `Paiement en retard`, not `#N`) → probe `qa-housing-monthly-expenses-screen`. If missing and MD5 still matches shade-closed → open app and navigate by id (`qa-housing-hub-journals` → `qa-housing-journals-monthly-expenses`). If missing and MD5 differs → fail (shade still open / unknown UI).

**Run:**

```bash
./tool/melosw run qa:run-payment-reminder
```

Manifest: `qa/multi_scenarios/housing_payment_reminder_before_due.yaml`. Coordinator:
`tool/coordinators/housing_payment_reminder.sh`.

## Repository layout

```
qa/
  scenarios/*.yaml       Single-device scenario manifests
  multi_scenarios/*.yaml Multi-device manifests (roles + coordinator)
  flows/*.yaml           Maestro flows (UI steps, assertions, screenshots)
  artifacts/             Run output (gitignored)
  db_seeds/              Named long-lived device dumps (gitignored; steal/restore)
  .local/                Clock restore state (gitignored)

mobile/lib/debug/
  qa_scenario_seed.dart       Seed dispatch + postconditions (debug Android)
  qa_scenario_seed_helpers.dart   Shared housing seed builders
  qa_db_snapshot.dart         Identity export/restore markers for db_seeds

tool/
  run_scenario.sh        One scenario end-to-end
  run_multi_device_scenario.sh  Multi-emulator orchestrator entry point
  run_fcm_wake_push_scenario.sh Emulator + physical FCM wake manual scenario
  run_housing_payment_reminder_scenario.sh Housing payment reminder #10 (simulated, no relay)
  run_db_snapshot_steal.sh   Pull named state into qa/db_seeds/<name>/
  run_db_snapshot_restore.sh pm clear + restore from qa/db_seeds/<name>/
  coordinators/          Per-domain coordination scripts (contact handshake, …)
  run_all_scenarios.sh   All manifests + aggregated report
  seed_qa_scenario.sh    Seed only (used by run_scenario)
  qa_scenario_manifest.py   Parse / list / validate manifests
  verify_qa_semantics.py    Maestro qa-* ids ↔ Dart identifiers
  qa_run_report.py       Generate index.html from results.json
  verify_qa.sh           Full verification entry point
  …                      Emulator, APK, clock, Maestro install scripts
```

## How a scenario works

Each scenario is defined by a **manifest** in `qa/scenarios/<id>.yaml`:

```yaml
id: settlement_open
description: Day after periodEnd, non-zero balances — settlement open
device_date: current
timezone: America/Toronto
seed: settlement_open
flow: qa/flows/settlement_open.yaml
screenshot_prefix: settlement_open
```

| Field | Purpose |
| --- | --- |
| `id` | Scenario name; **must match** the filename stem (`settlement_open.yaml`) |
| `device_date` | Passed to `set_android_date.sh` (emulator only). Use `current` for host wall clock **now** in `timezone` (date + time), or a pinned ISO local datetime |
| `timezone` | IANA timezone for the clock push |
| `seed` | Id consumed by `kQaScenarioIds` in `qa_scenario_seed.dart` |
| `flow` | Maestro YAML path relative to repo root |

**Pipeline** (`run_scenario.sh`):

```
emulator → build/install APK → set clock → seed (pm clear + marker + cold start)
→ Maestro test → restore clock → write artifacts
```

On success the orchestrator prints an explicit final line containing **`PASSED`**
and the scenario id (e.g. `Scenario PASSED | <id>. Artifacts: …`). Multi-device
entry points use `Test PASSED | <id>`. Do not treat a bare `complete` / `Done`
line as the pass verdict.

**Seeding** (debug builds only):

1. `adb shell pm clear` on the dev app id
2. Write scenario id to `app_flutter/compartarenta_qa_seed` via `run-as`
3. Cold-start the app; `maybeApplyQaAndroidSeed` in bootstrap clears Drift, seeds, deletes marker
4. `force-stop` so Maestro can `launchApp` on a clean process with data intact

Seeds set **French UI** (`prefs.languageCode=fr`) so Maestro text assertions match.

## Scenario catalog

Nine manifests ship today (housing hub + plan-draft wizard). Hub-gating seeds
place `periodEnd` relative to **today** (emulator clock = `device_date: current`).

| Scenario id | Device date | Expected UI |
| --- | --- | --- |
| `period_end_day` | current | Expense tile disabled (zero balances; term ended yesterday) |
| `settlement_open` | current | Settlement tile visible (term ended yesterday, non-zero balances) |
| `settlement_last_day` | current | Settlement tile + “available until” subtitle (today = last window day) |
| `settlement_closed` | current | Expense and settlement closed (window ended yesterday) |
| `renewal_fork_visible` | current | “New term from current plan” tile (term ended yesterday) |
| `voluntary_withdrawal_ack_j5` | current | Participation banner (last ack day) |
| `voluntary_withdrawal_effective` | current | Withdrawal applied; no banner |
| `proposal_response_expired` | current | Archive list shows expired proposal |
| `proposal_wizard_expenses` | current | Plan-draft wizard: 3 expenses (equal / custom / Like), summary + response deadline |

List manifests from the shell:

```bash
python3 tool/qa_scenario_manifest.py --list
```

## Melos commands

Prefer `./tool/melosw` over `dart run melos` (avoids redundant `pub get`).

| Command | Action |
| --- | --- |
| `qa:create-avd` | Create `Bojairu-QA` AVD |
| `qa:start-emulator` | Start emulator (cold boot) |
| `qa:install-maestro` | Install Maestro CLI |
| `qa:build-apk` | Build `app-dev-debug.apk` (optional `-- --simulation`) |
| `qa:install-apk` | Install APK on running emulator |
| `qa:verify` | Full toolchain verification |
| `qa:validate-scenarios` | Manifest / seed / flow checks only |
| `qa:verify-semantics` | Maestro ↔ Dart id alignment only |
| `qa:seed` | Seed one scenario (`-- <id>`) |
| `qa:run-scenario` | One full scenario (`-- <id> [options]`) |
| `qa:run-all-scenarios` | All scenarios + `index.html` |
| `qa:run-fcm-wake-push` | FCM wake manual (Monica emulator + physical phone) |
| `qa:run-payment-reminder` | Housing payment reminder #10 — single emulator, simulated delivery |
| `qa:db-snapshot-steal` | Pull named state into `qa/db_seeds/<name>/` (`-- --name <slug>`) |
| `qa:db-snapshot-restore` | `pm clear` + restore from `qa/db_seeds/<name>/` |

Examples:

```bash
./tool/melosw run qa:run-scenario -- settlement_open --skip-build
./tool/melosw run qa:run-all-scenarios -- --skip-restore
./tool/melosw run qa:run-all-scenarios -- --skip-build --skip-install
./tool/melosw run qa:run-all-scenarios -- --no-retry
./tool/melosw run qa:seed -- voluntary_withdrawal_ack_j5
./tool/melosw run qa:db-snapshot-steal -- --name play-screenshots-v1
./tool/melosw run qa:db-snapshot-restore -- --name play-screenshots-v1
```

## Shell script reference

| Script | Purpose |
| --- | --- |
| `tool/qa_env.sh` | Shared constants and adb helpers (sourced by other scripts) |
| `tool/run_db_snapshot_steal.sh` | Named steal into `qa/db_seeds/<name>/` |
| `tool/run_db_snapshot_restore.sh` | `pm clear` + restore from `qa/db_seeds/<name>/` |
| `tool/create_qa_avd.sh` | Create the QA AVD |
| `tool/start_qa_emulator.sh` | Start emulator (`--quick` for snapshot resume) |
| `tool/set_android_date.sh` | Set emulator date/time |
| `tool/restore_android_date.sh` | Restore automatic date/time |
| `tool/install_maestro.sh` | Install Maestro to `~/.maestro/bin` |
| `tool/build_qa_apk.sh` | Build dev debug APK (`--simulation` → `SIMULATION=true`) |
| `tool/install_qa_apk.sh` | `adb install -r` on emulator |
| `tool/seed_qa_scenario.sh` | Seed one scenario |
| `tool/run_scenario.sh` | Full single-scenario orchestrator |
| `tool/run_all_scenarios.sh` | Discover all scenarios + HTML report |
| `tool/qa_finalize_run.sh` | Write `finished_at`, build `index.html`, restore clock |
| `tool/verify_qa.sh` | Combined verification |
| `tool/verify_qa_phase0.sh` | Prerequisites only (called by `verify_qa.sh`) |
| `tool/qa_scenario_manifest.py` | `--list`, `--validate`, or `manifest key` |
| `tool/verify_qa_semantics.py` | Maestro `qa-*` ↔ Dart check |
| `tool/qa_run_report.py` | Build `index.html` for a run directory |

### `run_scenario.sh` options

```bash
./tool/run_scenario.sh <scenario-id> [--skip-build] [--skip-install] [--skip-restore] [--artifact-dir DIR]
```

| Option | Effect |
| --- | --- |
| `--skip-build` | Do not run `build_qa_apk.sh` |
| `--skip-install` | Do not run `install_qa_apk.sh` |
| `--skip-restore` | Do not restore emulator clock after the scenario |
| `--artifact-dir DIR` | Write Maestro output to `DIR` (used by `run_all_scenarios.sh`) |

### `run_all_scenarios.sh` options

```bash
./tool/run_all_scenarios.sh [--skip-build] [--skip-install] [--skip-restore] [--rebuild-each] [--no-retry]
```

| Option | Effect |
| --- | --- |
| `--skip-build` / `--skip-install` | Passed to every scenario (first scenario still builds unless both set) |
| `--skip-restore` | Do not restore emulator clock after the full run |
| `--rebuild-each` | Build and install APK before every scenario |
| `--no-retry` | Do not retry failed scenarios once after System UI recovery |

Default artifact path when `--artifact-dir` is omitted:
`qa/artifacts/<scenario-id>/<UTC-timestamp>/`

## Maestro

### Maestro MCP (Cursor / AI agents)

Maestro 2.6+ ships an MCP server so agents can inspect a live emulator and run
flows before editing YAML. This repo configures it in `.cursor/mcp.json` (wrapper:
`tool/maestro_mcp.sh`).

1. Install CLI: `./tool/melosw run qa:install-maestro`
2. In Cursor: **Settings → Tools & MCP** — enable the **maestro** server (or restart
   Cursor after pulling `.cursor/mcp.json`).
3. Start QA emulators (`qa:run-multi-scenario` bootstrap or `qa/run-emulators.sh`).
4. Use MCP to list devices, inspect hierarchy, and trial-run a flow on `--udid`.

MCP does **not** replace multi-device shell coordinators (`tool/coordinators/`).
Project-specific agent guidance: `.cursor/skills/maestro-compartarenta/`.

Official docs: [Maestro MCP](https://docs.maestro.dev/get-started/maestro-mcp).

### Application id

Every flow must declare the **dev** package:

```yaml
appId: app.incoherences.bojairu.dev
```

Maestro is invoked with `--udid <emulator-serial>` so a plugged-in phone is never
driven by mistake.

**Text selectors** (`assertVisible: "…"`) are treated as **regular expressions** and
must match the **entire** accessibility label of a node. Use `.*substring.*` for
partial matches (e.g. a subtitle with a date, or a banner prefixed with a name).

**`inputText`** (Maestro CLI) accepts **ASCII only** — no accented letters (see
[mobile-dev-inc/maestro#146](https://github.com/mobile-dev-inc/maestro/issues/146)).
Use unaccented QA fixture strings in flows (e.g. `Electricite`); keep French
**UI labels** in `tapOn` / `assertVisible` where Maestro reads rendered text, not
keyboard input.

Split grid **amount** and **percent** fields clear their text on focus so a new
value replaces the equal-share default (Maestro and manual entry).

Like-template dropdown: `qa-housing-expense-like-template`; menu options
`qa-housing-expense-like-option-<slug>` (e.g. `…-electricite` in
`proposal_wizard_expenses`).

Wizard expense rows: `qa-housing-wizard-expense-<slug>` (e.g. `…-loyer`,
`…-electricite`, `…-internet` in `proposal_wizard_expenses`). Prefer ids over
`assertVisible` on titles — list row text is not always exposed to Maestro.

Recurrence date range (debug builds): `showAppDateRangePicker` uses a Maestro-aware
picker. The 15th and 20th of the picker's first month (the 1st of today in
`showExpenseRecurrenceFlow`) use stable ids `qa-housing-expense-recurrence-day-15`
and `qa-housing-expense-recurrence-day-20` so `proposal_wizard_expenses` does not
pin a calendar year. Other days keep `qa-housing-expense-recurrence-day-YYYY-MM-DD`
so duplicate day numbers in later months stay unambiguous. Turning
**`qa-housing-expense-recurring-switch`** ON opens that picker immediately (no
separate “Définir la récurrence” tap). Flow after the switch: start day, end day,
then **`qa-housing-expense-recurrence-range-save`** (`enabled: true`) — the picker
does not auto-close after the end date.

### Shared subflow

`qa/flows/_enter_housing_hub.yaml` — launch app, tap housing tile (`qa-home-housing`),
wait for `qa-housing-active-hub`. Reused by most housing hub scenarios via `runFlow`
(`file: _enter_housing_hub.yaml`, path relative to the calling flow).

`_dismiss_ime_done.yaml` — tap Gboard's IME checkmark (bottom-right) to dismiss the
soft keyboard after `inputText`. Used by `proposal_wizard_expenses` on the pinned
Pixel 7 QA AVD; prefer this over `hideKeyboard` when the keyboard covers form actions.

`_save_expense_line.yaml` — dismiss IME (`_dismiss_ime_done.yaml`), wait until
`qa-housing-expense-form-save` is **visible**, then tap it (form
`bottomNavigationBar`; do not `scrollUntilVisible` for this id; do not refocus
text fields before save — that reopens the keyboard and hides the bar).

`qa-housing-expense-form` wraps the scrollable **body** only; the save id is a
sibling in `bottomNavigationBar` (not nested under the form container).

Prefer `id: "qa-home-housing"` over tapping `"Logement"` text: the home tile wraps
`Semantics(identifier: …)`, which is not always exposed as a plain text node to Maestro.

### Screenshots

`takeScreenshot: <name>` in flows writes PNGs into the scenario artifact
directory. The aggregated `index.html` thumbnails these files.

Capture a screenshot **only when a visible screen change is expected** — duplicate
frames hurt visual QA review.

| Pattern | Screenshots |
| --- | --- |
| Hub scenarios (`runFlow: _enter_housing_hub.yaml`) | `01_home` (settled home), `02_housing_hub` (after Logement tap) |
| `proposal_response_expired` | `01_home`, `02_expired_archive` (archive list) |
| `proposal_wizard_expenses` | `01_home`, `02_wizard_expenses_step`, `03_three_expenses`, `04_summary`, `05_response_deadline` |
| Scenario-specific asserts | No extra PNG after assertions on the same screen |

Before `01_home`, flows call `waitForAnimationToEnd` so the native Android splash
is gone. Hub scenarios assert tile/banner state on `02_housing_hub` without a
third identical capture.

## Semantics identifiers (`qa-*`)

Maestro does **not** see Flutter `Key`s. It uses the Android accessibility tree.
Stable targeting uses `Semantics(identifier: 'qa-…')` in **debug** builds, referenced
from flows as:

```yaml
- extendedWaitUntil:
    visible:
      id: "qa-housing-hub-settlement-due"
```

| Id | Surface |
| --- | --- |
| `qa-home-housing` | Home → Logement tile |
| `qa-housing-active-hub` | Active agreement hub screen |
| `qa-housing-hub-journals` | Active hub → Journals tile |
| `qa-housing-journals-monthly-expenses` | Journals menu → Accepted expenses |
| `qa-housing-monthly-expenses-screen` | Accepted expenses AppBar title |
| `qa-housing-hub-settlement-due` | Settlement-due expense tile (window open, not last day) |
| `qa-housing-hub-settlement-last-day` | Same settlement tile when today is the inclusive last window day |
| `qa-housing-hub-enter-expense` | Active-period expense entry tile |
| `qa-housing-hub-expense-disabled` | Disabled expense tile |
| `qa-housing-hub-renewal-fork` | Renewal fork tile |
| `qa-housing-participation-banner` | Participation change banner |
| `qa-housing-archive-expired` | Expired proposal archive card |
| `qa-housing-wizard-expenses-step` | Plan-draft wizard — expenses step header |
| `qa-housing-wizard-add-expense` | Wizard — add expense (+) |
| `qa-housing-wizard-next` | Wizard — Next / Finish footer |
| `qa-housing-wizard-summary` | Plan summary after wizard |
| `qa-housing-expense-form` | Full-screen expense line form |
| `qa-housing-expense-form-save` | Expense form — Enregistrer |
| `qa-housing-expense-name` | Expense form — name field |
| `qa-housing-expense-amount` | Expense form — amount field |
| `qa-housing-expense-split-pct-0` / `-1` | Split grid — percent row (0-based) |
| `qa-housing-expense-recurrence-confirm` | Recurrence confirm dialog |
| `qa-housing-expense-recurring-switch` | Expense form — Récurrent toggle |
| `qa-home-vehicle-sharing` | Home → Partage de véhicule tile |
| `qa-vehicle-sharing-hub` | Vehicle sharing hub AppBar title |
| `qa-vehicle-sharing-shareable-qa-civic` | Hub → shareable QA Civic row |
| `qa-vehicle-sharing-add-share` | Shares detail → Ajouter un partage |
| `qa-vehicle-sharing-invite-disclaimer-ok` | Invite form disclaimer Ok |
| `qa-vehicle-sharing-invite-send` | Invite form → Envoyer l'invitation |
| `qa-vehicle-sharing-pending-qa-civic` | Hub pending offer label |
| `qa-vehicle-sharing-pending-accept` | Hub pending → Accepter |
| `qa-vehicle-sharing-accessible-qa-civic` | Hub accessible vehicle after accept |

**Verifier** (`verify_qa_semantics.py`):

- Every `qa-*` id in `qa/flows/**/*.yaml` must appear in `mobile/lib/**/*.dart`
- **`screens/car_sharing/`** is excluded (immature vehicle module)
- Dart ids not used in any flow → **warning** only (not a failure)

```bash
./tool/melosw run qa:verify-semantics
```

**Convention** when adding flows: `qa-<module>-<surface>-<state>` in Dart first,
then reference the same string in Maestro YAML.

## Verification

| Check | Command |
| --- | --- |
| Full | `./tool/melosw run qa:verify` |
| Manifests only | `./tool/melosw run qa:validate-scenarios` |
| Semantics only | `./tool/melosw run qa:verify-semantics` |
| Seed unit tests | `cd mobile && ./tool/flutterw test test/qa_scenario_seed_test.dart` |
| Tooling unit tests | `python3 tool/qa_tools_test.py -v` |

Manifest validation enforces:

- Required keys: `id`, `device_date`, `timezone`, `seed`, `flow`
- `seed` ∈ `kQaScenarioIds` in `qa_scenario_seed.dart`
- Flow file exists
- Filename stem matches `id`

## Adding a new scenario

1. **Implement seed** in `mobile/lib/debug/qa_scenario_seed.dart` (+ helpers if needed);
   add id to `kQaScenarioIds` and `mobile/test/qa_scenario_seed_test.dart`.
2. **Create manifest** `qa/scenarios/<id>.yaml` (filename stem = `id`).
3. **Create Maestro flow** `qa/flows/<id>.yaml`; add `Semantics.identifier` for any
   new `id:` assertions.
4. **Validate**:
   ```bash
   ./tool/melosw run qa:validate-scenarios
   ./tool/melosw run qa:verify-semantics
   ```
5. **Run**:
   ```bash
   ./tool/melosw run qa:run-scenario -- <id>
   ```

No edit to `run_all_scenarios.sh` is required — discovery is automatic.

## Troubleshooting

| Symptom | Things to check |
| --- | --- |
| Maestro not found | `./tool/install_maestro.sh`; ensure `~/.maestro/bin` on `PATH` |
| Wrong device targeted | Unplug phone or ensure only emulator shows `adb devices` as `device` |
| Seed timeout | Debug APK installed; `adb logcat -d \| grep 'qa seed'` |
| `run-as` seed failed | App must be debug flavor with `run-as` enabled |
| Maestro id not found | Identifier only in `kDebugMode`; rebuild APK after Dart changes |
| Clock not restored | Run `./tool/restore_android_date.sh`; check `qa/.local/clock-restore.env` |
| Stale APK | Omit `--skip-build` or run `./tool/melosw run qa:build-apk` |
| Maestro cannot see visible text (e.g. “Logement”) | Use `id: "qa-…"` — custom `Semantics` tiles expose `identifier`, not always searchable text |
| Text assert fails though string is on screen | Maestro `text` selectors are **regex** matching the **whole** node (e.g. subtitle includes a date; banner includes a name). Use `.*partial.*` or prefer `id: "qa-…"` |
| Maestro `Invalid File Path` on `runFlow` | Subflow `file:` must be **relative to the calling flow** (e.g. `_enter_housing_hub.yaml`, not `qa/flows/…`) |
| MissingPluginException after reinstall | Stop melos, force-quit app, cold start again (see melos workflow rules) |
| `System UI keeps stopping` during `run-all-scenarios` | Emulator instability after manual clock jumps / repeated `pm clear` — not a Maestro selector bug. `run_all_scenarios` retries each failed scenario once after `qa_recover_system_ui` (restarts `com.android.systemui`). If it persists: cold-boot the AVD (`qa:start-emulator` without `--quick`) |
| Maestro hangs on `Launch app` (no output for minutes) | Do **not** run `killall com.android.systemui` before every scenario (removed from the normal path). Cold-boot the emulator, then retry. `run_scenario.sh` caps Maestro at `COMPARTARENTA_QA_MAESTRO_TIMEOUT_SEC` (default 600 s) |
| Intermittent `qa-home-housing` not visible with System UI dialog on screen | Dismiss/recover System UI first; failure screenshots under `qa/artifacts/` usually show the modal |

`run_all_scenarios.sh` accepts `--no-retry` to disable the single automatic retry per scenario.

## Out of scope

This toolchain does **not** cover:

- CI / GitHub Actions headless runs
- Flutter **web** (Monica / Roberr dev browsers)
- Multi-device sync (separate apps per machine)
- Entitlement trial/grace tied to VPS clock
- Relay push cron / production relay-dependent flows without fixtures
- Vehicle / car-sharing module (`screens/car_sharing/`)

For the original design notes and effort estimates, see the personal roadmap in
`dev-ideas/2026-06-24-Comment-tester-E2E-à-implémenter.md` (gitignored).
