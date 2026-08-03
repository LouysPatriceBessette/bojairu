---
name: maestro-scenario-avoid-carpet-tripping
description: >-
  Mandatory workflow for creating or extending ANY Bojairũ Maestro scenario
  (single-device qa/scenarios or multi-device coordinators). Use on every new
  scenario request, Maestro flow edit, coordinator change, or qa-* semantics
  work. Enforces code-first automation (tap existing buttons by id), skills +
  MCP usage, sequential multi-device runs, no blind patching, and no vandalizing
  recent working code. Learned from Jul 11–12 2026 agent failures (~24 h wasted).
---

# How to avoid tripping over all flowers of the carpet when creating Maestro scenarios

**Applies to:** every new or extended Maestro scenario — `qa/scenarios/*`, `qa/multi_scenarios/*`, `qa/flows/*`, `tool/coordinators/*`, and any `qa-*` semantics added to support a flow.

**Budget target:** ~**3 hours** for a scenario comparable in scope to existing ones (handshake pair, housing wizard, settlement probe). Not 24.

**What a Maestro scenario IS here:** a **click script** on buttons and fields that **already exist** in the Flutter app, identified by `qa-*` semantics. Your job is to **compose** YAML from code and repo helpers — not to invent UX, theorize about sync, or rewrite the app until you have a **démonstration** (see `no-probability-coding.mdc` lexicon).

---

## What went wrong (Jul 11–12, 2026) — do not repeat

These failures happened across **many** agents and turns; they are **not** tied to one scenario id:

| Failure mode | What agents did instead of the right thing |
|--------------|---------------------------------------------|
| **Patch sans artefact** | Patched YAML/coordinator from habit without reading the screen’s Dart or the failing artifact |
| **Théorisation** | Blamed relay, race, stale data — without log line, screenshot, or Maestro hierarchy |
| **Code à l’aveugle** | Added `tapOn id:` without checking `Semantics` (`clickable`, `onTap`, `excludeSemantics`) in source |
| **Vandalisme** | Reverted or rewrote working code from minutes earlier; edited **shared** `_*.yaml` for one broken path |
| **Skills ignorés** | `maestro-compartarenta`, `maestro-e2e`, Maestro MCP installed but not read/used before edit |
| **Scope creep** | After user PASSED: refactored wizard, IDs everywhere, orchestrator, seed — broke what worked |
| **Masquage QA** | Removed assertions, added tolerances, or skipped steps so a **bug** would not fail the run |
| **Parallel multi-device** | `inviter-standby &` + invitee foreground → races and hour-long flakes |
| **`tapOn` COMPLETED ≠ action** | Treated tap as success; sheet/dialog never opened (`excludeSemantics` without `onTap`) |
| **No validation loop** | Claimed fixed / « almost done » without green run + artifact |

**User installed skills precisely to stop blind YAML.** If you skip Step 0 below, you repeat the same 24 h disaster on the next scenario.

Skill lessons and bans for premature “success” claims: `no-probability-coding.mdc` (lexicon) + `I-am-learning-Maestro-autonomously.mdc`.

---

## Step 0 — Mandatory reads (before the first edit)

```
[ ] This skill (full file)
[ ] .cursor/skills/maestro-compartarenta/SKILL.md + reference.md
[ ] .cursor/skills/maestro-e2e/rules/selectors.md + rules/platforms/flutter.md
[ ] docs/qa-android-e2e.md — semantics table, run commands, TLS note
[ ] Nearest existing scenario (grep by feature — see table below)
[ ] git status + git diff — know staged vs unstaged before blaming « the code »
```

**Maestro MCP** (emulators running): `list_devices` → inspect hierarchy on the **exact** screen you will automate. MCP is for **proof**, not decoration.

---

## Step 1 — Define done (5 min, chat or notes)

Write **one sentence** each:

1. **User path** — who taps what, in what order (which device if multi).
2. **Pass observable** — which `qa-*` id(s) or logcat line proves success.
3. **Reference** — closest existing scenario id to **copy structure from** (not reinvent).

### Blocking questions — ask in chat before writing YAML (do not invent the answer)

If the request names a surface but **not** the pass criterion, **stop and ask**. Do not
guess a “minimal” path that skips the human action under test.

| Topic mentioned | Ask before coding |
|-----------------|-------------------|
| **Notifications** | Shade **visibility only**, or **tap** the notification? If tap: which screen/`qa-*` must appear after the tap? |
| **Accept / respond** | Hub button, dialog, or another control? (Do not invent a dialog the app does not show.) |
| **Owner + borrower** | Pass = borrower only, or **both** sides (owner active state / journal / notif)? |
| **Contacts / handshake** | Must the scenario re-handshake, or are peers **pre-seeded connected**? |

**Demonstrated failure (2026-08-01, `vehicle_sharing_offer_happy_path`):** agents iterated
shade **assert-only** + `launchApp`/`stopApp` around notifications for multiple runs, then
claimed the scenario tested “notifications”, without asking whether the objective required
**tapping** the notification. User correction: testing freshly added notifications without a
tap means the test objective was never confirmed. Fix path: rewrite coordinator around
shade **tap** → destination assert (see Error cases below).

### Orchestrator success line (mandatory)

Every Maestro orchestrator / coordinator success path **must** print an explicit
final status line that contains the substring **`PASSED`** (and the scenario id),
for example:

```bash
echo "Scenario PASSED | ${SCENARIO_ID}. Artifacts: ${ARTIFACT_DIR}"
# multi-device coordinators already use:
# echo "Test PASSED | ${SCENARIO_ID}"
```

Do **not** end a green run with only wording such as `complete` / `Done` without
**`PASSED`**. Agents and the developer treat the log’s last success line as the
verdict; ambiguous “complete” is insufficient when the emulator still shows OS
dialogs (e.g. System UI) after the script exits.

Failure paths should keep a clear non-zero exit; optional explicit `FAILED |`
lines are fine but **`PASSED` on success is required**.

If the request mixes several behaviors, ask which to do **first** (chat text, not Question UI).

---

## Step 2 — Inventory from code (30–45 min, no YAML yet)

**The app already has the buttons.** Find them.

```bash
# Semantics constants
rg 'qa[A-Z]|kQa|Semantics\.identifier' mobile/lib/debug/ mobile/lib/screens/ -g '*.dart'

# Existing flows for this surface
rg 'qa-your-surface' qa/flows/

# Shared entry helpers
ls qa/flows/_*.yaml
```

For **each** tap target you need:

| Read in Dart | Why |
|--------------|-----|
| Widget with `Semantics(identifier: …)` | Confirms id exists |
| `onPressed` / `onTap` / `InkWell` | Maestro needs `button: true` + `onTap` when `excludeSemantics: true` |
| Route after action (`context.push`, `go_router`) | Correct wait target is **next screen’s** id, not a guess |
| Dialog host screen | Dialogs on wrong route = assert on id that is never mounted |

**Working pattern to copy** (do not invent a new semantics shape):

```dart
// FilledButton / similar — mirror onPressed on Semantics.onTap
Semantics(
  identifier: kQaSomeAction,
  button: true,
  onTap: enabled ? _onAction : null,
  excludeSemantics: true,
  child: FilledButton(onPressed: enabled ? _onAction : null, …),
)
```

See `qa-contacts-generate-code`, `qa-housing-wizard-next` in codebase — grep before adding a third variant.

**Add new `qa-*` in Dart only when** grep + MCP hierarchy show the control is untappable or has no id. Minimal diff; widget test optional but one-liner tap-on-semantics is cheap insurance.

---

## Step 3 — Compose YAML from inventory (30–45 min)

**Prefer `runFlow` of existing `_*.yaml`** over new steps.

```yaml
appId: app.incoherences.bojairu.dev
---
- runFlow:
    file: _enter_contacts_hub.yaml   # example — use what grep found
- extendedWaitUntil:
    visible:
      id: "qa-contacts-invite-fab"
    timeout: 15000                    # tune after one run, not 120000 by default
- tapOn:
    id: "qa-contacts-invite-fab"
```

Rules while writing:

- **`id:` only** for in-app taps and asserts — not `text:` (user binding). **Exception:** Android **system notification shade** may use product title/body text (never temporary `#N` QA prefixes) — see Non-negotiable → Selectors.
- **`inputText`**: ASCII only in typed values.
- **Dialogs**: `extendedWaitUntil` dialog id → `tapOn` dialog button id → **then** navigate.
- **Duplicates / repeated rows**: `index: 1` when testing a second occurrence — one `assertVisible` without index is not enough.
- **Permissions**: reuse `_accept_notification_prompt.yaml` (`when: visible`) — never spray `optional: true` on `Autoriser` / `Allow` / `AUTORISER`.
- **No** `waitForAnimationToEnd: 3000` if the next screen id is already waited on.

```bash
python3 tool/verify_qa_semantics.py   # must exit 0 before any run
```

---

## Step 4 — Orchestration (multi-device only, 30–45 min)

Copy the **nearest coordinator** (`tool/coordinators/contact_handshake.sh`, `housing_proposal.sh`) — mode branch, probe helpers, artifact layout.

**Binding:**

- **TOUJOURS coordonner les émulateurs en séquentiel** — parallèle **interdit** car cause des FUCK abominables.
  - Order: device A action → wait export/poll → device B action → device A reaction → asserts.
  - **Never** background `&` handshake on one device while the other runs redeem.
- **TOUJOURS indiquer dans le log sur quel émulateur le test a lieu.**
  - Example: `maestro device=emulator-5556 (Monica-QA) flow=contact_handshake_inviter_generate.yaml`
  - Phase banners: `=== Phase 2 ===` before each block.

**Bash traps (caused silent continuation and false progress):**

- `set -e` is **ignored** inside functions called from `while` — use explicit `|| return 1` after `_run_maestro`.
- Probe return codes: 0 = symptom present, 1 = absent, 2 = infra — do not treat 2 as PASS.
- Do not double-seed: if `run_multi_device_scenario.sh` already seeded, use `_prepare_after_runner_seed` pattern — **ne jamais seeder un émulateur deux fois de suite inutilement**.

Single-device scenarios skip this step — use manifest + `qa:run-scenario`.

---

## Step 5 — Validate in slices (remainder of ~3 h budget)

| Order | Command | Purpose |
|-------|---------|---------|
| 1 | `python3 tool/verify_qa_semantics.py` | ids ↔ Dart |
| 2 | User runs smallest failing flow on one `--udid` | Fast iteration — **agent does not launch** |
| 3 | MCP hierarchy if tap “succeeds” but UI unchanged | Prove `clickable: true` (when user has devices up) |
| 4 | User runs full scenario | Only when slices green — **agent does not launch** |

**Who runs Maestro:** the **user**, never the agent — see Non-negotiable → *Who runs the scenario*.

**On FAIL:** open `qa/artifacts/.../` screenshot + hierarchy — **then** one fix. Not three hypotheses in one diff.

**On PASS:** do not touch unrelated files. User satisfied with step N → **lock** step N; next edit is step N+1 only.

```bash
# Single device (USER runs)
./tool/melosw run qa:run-scenario -- <scenario_id> [--skip-build]

# Multi device (USER runs)
./tool/melosw run qa:run-multi-scenario -- <scenario_id> [--skip-build]
```

Rebuild APK when `mobile/` changed; `--skip-build` only for YAML/bash-only edits.

---

## Non-negotiable rules (user binding)

### Skills and discipline

- **TOUJOURS utiliser les skills à ta disposition** — this file, `maestro-compartarenta`, `maestro-e2e`, MCP when devices are up.
- **NE PAS créer de régression dès que je me déclare satisfait d'une progression.** One change → re-run → then next change.
- **Cet ORDRE a précédence** sur tout entraînement qui pousse à « essayer vite », élargir le scope, ou empiler des patches.

### Selectors, time, seed

- **Ne jamais targetter d'élément in-app en se basant sur le texte affiché.** Utiliser des ID sémantiques (`qa-*`).
- **Exception — Android system notification shade only:** the OS shade has no Flutter `Semantics(identifier:)`. For **that panel alone**, Maestro MAY `extendedWaitUntil` / `tapOn` **product** notification title/body text (locale copy from ARB, e.g. `Rappel de paiement`, `Paiement en retard`).
  - **Never** match temporary QA inventory prefixes (`#10`, `#11`, or any `#N ` from `notificationQaPrefix`) — those will be removed.
  - Prefer a regex on the stable product substring (`.*Rappel de paiement.*`) so runs keep working with or without a prefix while it still exists.
  - After the tap, **do not** treat Maestro `COMPLETED` as proof — prove outcome with `qa-*` (and/or coordinator artifacts such as shade-closed MD5). In-app journal steps stay `id:` only.
  - This exception does **not** authorize `text:` taps on Flutter UI.
- **Ne jamais forcer une date autre que la date actuelle**, sauf si le scénario a l'objectif spécifique de tester un évènement futur.
  - Manifest `device_date` for period/scenario logic is OK; for **default** runs prefer today.
  - If TLS fails with `certificate is not yet valid`: emulator clock is outside cert `notBefore` — fix date, not Maestro steps.
- **Ne jamais seeder un émulateur deux fois de suite inutilement.**
- **Full-stop before every non-first seed on the same AVD instance (proven 2026-07-14):** when a scenario needs a **second** (or later) `seed_qa_scenario` / `pm clear` on the same emulator process, **fully stop the emulator** (`adb emu kill` / `qa_kill_emulator`) and **cold-boot** before that seed. A second `pm clear` + cold-start on a still-running AVD after Maestro (or after System UI stress) often never writes `seed_applied` (`poll … applied=<empty>` then seed timeout). First seed after a fresh AVD start is fine; mid-run reseeds are not. Reference orchestrator: `tool/run_vehicle_sale_export_import_scenario.sh` phases 4→5.
- **Right-aligned control + full-width Semantics hitbox (demonstrated 2026-07-14):** `Align(alignment: centerRight)` wrapping `Semantics(excludeSemantics: true, …)` can report a **full-row** `bounds` in Maestro hierarchy while the visible `TextButton` sits on the right. `tapOn id:` then COMPLETED (center of bounds) without firing `onPressed` — dialog never opens. Hierarchy proof: `qa-vehicle-import-action` bounds `[42,325][1038,451]` with visual « Importer » on the right edge. **Fix (situational):** size the Semantics to the control (`Row` + `MainAxisAlignment.end`, or equivalent intrinsic width), not the full cross-axis of the list. (`Row`+`end` alone did **not** shrink bounds under `ListView` — still `[42,325][1038,451]` as child of `ScrollView` after rebuild; see next bullet.)
  - **Alternative (demonstrated 2026-07-14, `mobile/terminal.log` run `20260714T224815Z`):** same id still full-width under ancestor `android.widget.ScrollView` after `Row`+`end`. Situation difference: list max cross-axis + scrollable parent. **Fix that recovered:** move the Maestro target to `AppBar.actions` (outside the scrollable body). Demonstration: Maestro steps `qa-vehicle-import-action` → `qa-vehicle-import-confirm` → `qa-vehicle-card-qa-civic` all COMPLETED; orchestrator then printed `Scenario vehicle_sale_export_import complete` (that run predates the mandatory `PASSED` log line). Do **not** delete the Align/`Row` lessons.
  - **Alternative (demonstrated 2026-07-31, `vehicle_sharing_offer_happy_path`):** hub pending **Accepter** — `Semantics(excludeSemantics: true)` wrapping a `FilledButton` in a `Row` under `ListView` still reported full-width bounds `[42,850][1038,997]` with `qa-vehicle-sharing-pending-qa-civic` nested under the accept id; `tapOn` COMPLETED without accepting. Situation difference: trailing/Row control inside scrollable hub body (not AppBar). **Fix that recovered:** put the Maestro `identifier` on the **label inside** `FilledButton` (bounds = button face) and `_reload()` immediately after local `acceptSharingLink` (do not wait for relay RTT before UI update). Evidence: hierarchy in `qa/artifacts/multi-vehicle_sharing_offer_happy_path/20260731T225710Z`; green run `20260731T232523Z` printed `Scenario PASSED | vehicle_sharing_offer_happy_path`.
- **UI flash / inbox tick ≠ sync applied (observed 2026-07-31, owner Partages after borrower accept):** listening to `steadyStateInboxTick` and calling `_reload()` can flash the screen while the row still shows the old state (e.g. « Invitation envoyée… »). Causes to check before blaming « navigation »: (1) tick bumped even when `applyRemoteSharingOfferAccept` returns `false` (handler still acks + ticks); (2) concurrent `_reload()` without a generation token — an older read can `setState` after a newer one; (3) owner never got a successful apply — Settings **Journal d'événements** missing « Réponse à une offre… » while borrower has it is stronger evidence than a flash. **Maestro:** do not treat a visual flash or “screen refreshed” as pass for owner accept sync; assert an owner-side outcome id / journal kind / logcat `vehicle_sharing_offer_accept applied=true`.
  - **Product path (demonstrated 2026-08-01, run `20260801T174900Z`):** foreground FCM wake must call `HandshakeOrchestrator.maybeInstance.pollSteadyStateInboxes()` — not `runWakeInboxPollOnce()` (second `AppDatabase` + non-installed orchestrator). Same run: coordinator saw `vehicle_sharing_offer_accept applied=true`; failure screenshot still showed the **green check** on QA Civic. Tick-only-when-applied + reload generation tokens shipped with that path.
  - **Maestro assert trap (same run; selector established `20260801T184651Z`):** `qa-vehicle-sharing-shareable-active-qa-civic` nested under the shareable row’s `Semantics(button: true, excludeSemantics: true)` never appears in hierarchy (only `qa-vehicle-sharing-shareable-qa-civic`). Put the active id on the **row** when `listActiveLinksAsOwner` includes the vehicle. Green run `20260801T184651Z` printed `Scenario PASSED | vehicle_sharing_offer_happy_path` with that row id visible after accept-notification tap.
- **Notification shade path — no force-stop / no `stopApp` around shade (demonstrated 2026-08-01):** `force-stop` / Maestro `launchApp: stopApp: true` **cancels local notifications** (same class as `housing_payment_reminder`). To open the shade: `KEYCODE_HOME` only (background, keep process + notifs) → `qa_open_notification_shade_on_serial` → Maestro tap product title → assert in-app `qa-*`. **Do not** replace a notification tap with a later cold start + manual navigation to the destination — that tests restart, not the notification.
  - **Retired wrong path (same scenario):** `vehicle_sharing_offer_borrower_assert_notification.yaml` (shade assert, no tap) + borrower/owner flows with `stopApp: true` to reach hub/Partages. Replaced by `*_tap_notification.yaml` + `*_accept_from_hub.yaml` / `*_assert_hub_active.yaml`. Leave dead flows unused or delete them so the next agent does not re-wire the assert-only path.
- **Notification navigation — `skipPushWhenAlreadyAt` must be the hub route only (demonstrated 2026-08-01):** `pushFromNotificationTapWhenReady('/vehicle-sharing', skipPushWhenAlreadyAt: location.startsWith('/vehicle-sharing'))` **skips** navigation when the user is already on a **child** route (e.g. Partages `/vehicle-sharing/:id/shares`). Tap then looks like a no-op; Maestro burns the full hub `extendedWaitUntil` timeout while the hierarchy still shows Partages + « Retour ». **Fix:** skip only when `location == '/vehicle-sharing'` (exact hub). Evidence: fail `20260801T183315Z` assert hub duration **89594 ms** on Partages; pass `20260801T184651Z` hub assert **~0.5 s** after product fix. Do not paper over with a Maestro `back` unless the product intentionally leaves the user on the child route.
- **Failed `extendedWaitUntil` costs the full timeout (measured 20260801T183315Z vs `20260801T184651Z`):** penultimate fail spent **~90 s** on `qa-vehicle-sharing-hub` (timeout 90000); last pass spent **~0.8 s** on the same flow. Artifact wall (folder name → `multi-scenario.yaml`): **316 s → 288 s**. Maestro command-duration sums for all five phases: **~155 s → ~76 s** (almost entirely that failed wait). Dropping a duplicate `assertVisible` after `extendedWaitUntil` saved under one second. Shrinking `sleep 1` → `0.4` after HOME/shade is likewise seconds. **Do not** set comfort timeouts of 90 s for a screen that must appear immediately after a tap — a wrong destination then burns ~1.5 minutes per run. Prefer tighter timeouts once the happy path is green; keep long waits only for true async (logcat import/apply).
- **Dual-device seed + APK rebuild dominate wall clock:** each role’s `pm clear` + cold start + `seed_applied` polls (~15–20 × ~1.5 s) runs **before** the coordinator. Micro-edits to shade sleeps/asserts cannot make a multi-scenario feel “1 minute”. Do not add a **second** seed or mid-run `stopApp` cold start to “fix” navigation — that multiplies the expensive part. Compare runs with Maestro `commands-*.json` `metadata.duration` and artifact folder timestamps, not vibes.
- **Ne jamais utiliser des timeout exagérément long** (ex: 120 secondes pour attendre la fin d'une animation de 800ms).
- **QA APK `libsqlite3.so` — one install path only (demonstrated 2026-08-02):**
  - **Symptom A (Linux `.so` in APK):** seed never writes `seed_applied`; Setup/Language; logcat Drift + `libc.so.6` needed by `lib/*/libsqlite3.so`. Cause: host-Linux binary packaged (often after wipe/hooks/`flutter test` pollution). See `no-probability-coding.mdc` founder incident.
  - **Symptom B (build dies before install):** `mergeDevDebugJniLibFolders` → **Duplicate resources** for `arm64-v8a/libsqlite3.so` and `x86_64/libsqlite3.so`, citing both `mobile/android/app/src/main/jniLibs/...` **and** `mobile/build/native_assets/android/jniLibs/lib/...`. Evidence: `mobile/terminal.log` ~18:43 same day (`> … 2>&1`).
  - **Root cause of B (not the last git commit):** uncommitted tooling copied pinned Android `.so` into `src/main/jniLibs` while Flutter Dart hooks still install the same name via `install_code_assets` into `native_assets`. Last commit `889ce62` only changed seed clock `"current"` → wall-clock time — unrelated.
  - **Wrong follow-up (demonstrated useless):** `android.packaging.jniLibs.pickFirsts += "**/libsqlite3.so"` — packaging pickFirst does **not** stop `mergeDevDebugJniLibFolders` from failing. Same Duplicate error after that change.
  - **Required direction:** single source = hooks/`native_assets` only. Cache pinned Android `.so` under `qa/.local/…`, seed missing `hooks_runner/.../download-*` if stale `output.json` points at wiped files, **delete** any `src/main/jniLibs/**/libsqlite3.so`, assert APK `NEEDED` is `libc.so` not `libc.so.6`. Do not reintroduce a second jniLibs copy “to bypass hooks”.
  - **Stdout trap:** `qa:run-multi-scenario > terminal.log` without `2>&1` hides Gradle `ERROR:` lines — always capture stderr when diagnosing APK build fails.
  - **Recovery demonstrated** (`mobile/terminal.log`, artifacts `20260802T225508Z`): after single-source tooling, build succeeded and printed `Scenario PASSED | vehicle_sharing_active_seed` / `Test PASSED | vehicle_sharing_active_seed`.

### QA integrity

- **Ne JAMAIS corriger un mauvais comportement de l'application par des patch dans le scénario.** Il est FOUTREMENT évident qu'un test de QA qui révèle des bug à corriger NE DOIT PAS les supprimer. C'est un comportement IDIOT ET IMBÉCILE — **ne plus jamais faire ça.**
- **TOUJOURS vérifier si un bug identifié peut se répéter à d'autres endroits** et, si c'est le cas, **DEMANDER LA CONFIRMATION** avant de corriger.

### Simulation QA — keep live bot peers across an engine restart

- **Symptom:** persisted simulated contacts remain connected, proposal envelopes
  are posted, but `PeerSimulator react start bots=0` means no simulated
  participant can respond.
- **Action:** reuse the process-local `SandboxRelay` and `PeerSimulator` when a
  new Flutter engine bootstraps in the same Android process; do not replace and
  dispose the populated simulator.
- **Evidence:** Android log on 2026-07-21 showed three delivered proposal
  envelopes followed by `bots=0`; the preservation regression in
  `mobile/test/sandbox_peer_simulator_test.dart` and the full 587-test suite
  passed after the fix.

### Who runs the scenario (user binding — never the agent)

**NEVER** launch Maestro / melos QA scenarios yourself (`qa:run-scenario`,
`qa:run-multi-scenario`, `qa:run-vehicle-sale-export-import`, coordinators,
direct `maestro test`, etc.). Prepare flows/code, give the user the exact
command, and wait for **their** log / artifacts. Reasons:

1. Silent hangs are common (Gradle stuck, `seed_applied` empty, System UI,
   Maestro waits) — the agent burns long wall-clock with no useful signal.
2. The user does **not** see the agent’s emulator instance, so they cannot
   interrupt a stuck run when the agent also fails to detect the hang.

After delivering a change: give the run command; do **not** start it in a
background terminal. Claim PASS only from the user’s green log (with
**`PASSED`**) or explicit user confirmation.

### Agent responsibility

- Close the validation loop **with the user’s run evidence** — never « nobody verified », « previous agent », « instruction half-applied ».
- Do not claim PASS without a green run, artifact evidence, **and** an orchestrator log line containing **`PASSED`**.

---

## Which layer to change (decision table)

| Evidence | Change | Do not change |
|----------|--------|----------------|
| Hierarchy: id present, `clickable: true`, but `tapOn` COMPLETED and UI unchanged; bounds far wider than the visible control | Shrink Semantics to control width (e.g. `Row`+`end` / intrinsic); if still max-width under `ScrollView`, move id outside scrollable (`AppBar.actions`) | Longer timeout / `text:` tap |
| Hierarchy: id missing | Add minimal `qa-*` in Dart | Random `text:` tap in YAML |
| Hierarchy: `clickable: false` on intended button | `button: true` + `onTap` mirror `onPressed` | Longer timeout |
| Wrong screen after tap | YAML order / `runFlow` helper / navigation subflow | Product business logic |
| Dialog open but assert on wrong id | Wait dialog id on **correct** route host | Global edit of shared `_return_*` |
| Sync event not arrived yet | `qa_wait_for_logcat_on_serial` or wait next id | Remove assert |
| App bug (wrong data, duplicate row, crash) | **Fix Dart** (ask if same pattern elsewhere) | Skip step / `optional: true` on assert |
| `HandshakeException` / cert date on screenshot | `device_date` / clock vs `openssl x509 -dates` | Coordinator race theories |
| Maestro infra exit / empty artifact | adb, grpc, tooling — INCONCLUSIVE | « Bug absent » |
| User had PASSED; new task is small | Cherry-pick one fix from stash | Refactor whole wizard |

---

## Shared subflows — never vandalize

Files `qa/flows/_*.yaml` are **shared**. Rules:

1. **Do not** change `_return_to_contacts_list.yaml` (or any `_`) to fix **one** inviter/invitee path — add `_navigate_inviter_to_contacts_list.yaml` or a scenario-local flow.
2. **Do not** delete working steps another scenario relies on — grep all `runFlow` references first.
3. If you broke a shared file: **revert that file** only, not the whole session’s work.

---

## Nearest reference scenarios (copy structure, not prose)

| Feature | Single-device manifest | Multi-device | Coordinator |
|---------|------------------------|--------------|-------------|
| Contacts handshake | `contact_handshake_inviter.yaml` | `qa/multi_scenarios/contact_handshake*.yaml` | `contact_handshake.sh` |
| Housing proposal | `proposal_wizard_expenses.yaml` | `housing_proposal_happy_path.yaml` | `housing_proposal.sh` |
| Settlement | `settlement_open.yaml` | — | (orchestrator only) |
| Vehicle | `vehicle_use_session.yaml` | — | — |

New scenario checklist: manifest fields (`id`, `device_date`, `seed`, `flow`) match an existing yaml in `qa/scenarios/`; flow starts with `appId` + `runFlow` hub helper when applicable.

---

## Anti-patterns checklist (any scenario)

**Maestro**

- [ ] No `text:` for taps/asserts (ids only) — except OS notification shade product title/body (never `#N` QA prefixes)
- [ ] No `optional: true` permission tap spam → WARNED minutes
- [ ] No assert before prerequisite action (dialog Ok before back)
- [ ] No `index` forgotten when testing duplicate rows
- [ ] No hub/final assert before async event (wait logcat or next id)

**Coordinator**

- [ ] No parallel `&` between devices
- [ ] Every `maestro` line logs serial + role
- [ ] Maestro failure stops the attempt (`|| return 1`)
- [ ] No double seed
- [ ] No `force-stop` / `stopApp: true` between shade open and notification tap (cancels local notifs)
- [ ] Notification scenarios: shade **tap** + destination `qa-*` when that is the product under test — not assert-only + cold restart
- [ ] No stdout hidden so user cannot see steps
- [ ] Success ends with a log line containing **`PASSED`** and the scenario id (not only `complete`)

**Process**

- [ ] Skills + code inventory **before** edit
- [ ] Pass criterion confirmed in chat when ambiguous (especially notifications / both roles)
- [ ] One change per failed run
- [ ] No app patch to hide test failure; no test patch to hide app bug
- [ ] Confirm with user before fixing same bug class in multiple modules
- [ ] Agent **never** launches the scenario — user runs it (silent hang + no visible emulator)
- [ ] No claim PASS without **user** run proof **and** a `PASSED` orchestrator line
- [ ] After a coordinator rewrite, unused sibling flows are not left as the “easy” re-wire target

---

## When to stop and report (no code)

After **two** failed runs on the same step with **different** guesses:

Deliver: **Observed** / **Not observed** / **Hypotheses** (falsifiable) / **What would prove each** — per `no-probability-coding.mdc`. No third blind patch.

Ask in chat (plain Markdown) when product scope is ambiguous.

---

## Delivery bar

- [ ] `verify_qa_semantics.py` → 0
- [ ] Scenario green **from the user’s run** (single or multi) with artifacts — agent did not launch it
- [ ] Logs show device serial per Maestro block
- [ ] `flutter analyze` + `flutter test` if `mobile/` touched
- [ ] Diff scope = what was requested — no drive-by refactors

**Definition of done:** the scenario automates **existing** UI by id; failures mean app or flow wiring is wrong — not something to hide.
