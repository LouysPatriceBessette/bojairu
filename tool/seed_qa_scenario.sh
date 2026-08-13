#!/usr/bin/env bash
# Seed a QA scenario on the running Android emulator (debug APK).
#
# Clears app data, writes the scenario marker consumed by bootstrap
# ([maybeApplyQaAndroidSeed]), cold-starts the app once, then stops it so Maestro
# can relaunch without clearing Drift state.
#
# Usage: ./tool/seed_qa_scenario.sh settlement_window_open

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"

qa_export_android_sdk_paths
qa_require_command adb

SCENARIO_ID="${1:-}"
if [[ -z "${SCENARIO_ID}" ]]; then
  echo "Usage: $0 <scenario-id>" >&2
  echo "Example: $0 settlement_window_open" >&2
  exit 1
fi

MANIFEST="${ROOT}/qa/scenarios/${SCENARIO_ID}.yaml"
if [[ -f "${MANIFEST}" ]]; then
  SEED_ID="$(python3 "${ROOT}/tool/qa_scenario_manifest.py" "${MANIFEST}" seed)"
else
  # Multi-device role seeds (qa/multi_scenarios) use kQaScenarioIds directly.
  SEED_ID="${SCENARIO_ID}"
  if ! python3 - "${SEED_ID}" "${ROOT}" <<'PY'
import re, sys
from pathlib import Path
seed, root = sys.argv[1], Path(sys.argv[2])
text = (root / "mobile/lib/debug/qa_scenario_seed.dart").read_text(encoding="utf-8")
m = re.search(r"const kQaScenarioIds = <String>\{([^}]*)\}", text, re.DOTALL)
ids = {x.group(1) for x in re.finditer(r"'([^']+)'", m.group(1))} if m else set()
sys.exit(0 if seed in ids else 1)
PY
  then
    echo "Unknown scenario or seed id: ${SCENARIO_ID}" >&2
    exit 1
  fi
fi
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  SERIAL="${ANDROID_SERIAL}"
else
  SERIAL="$(qa_use_emulator_adb_serial)"
fi
ADB=(adb -s "${SERIAL}")

ACTIVITY="${COMPARTARENTA_QA_APP_ID}/app.incoherences.bojairu.MainActivity"

qa_start_seed_activity() {
  local attempt out
  for attempt in 1 2 3 4 5; do
    echo "  cold start attempt ${attempt}/5..."
    if out="$(timeout 45 "${ADB[@]}" shell am start -n "${ACTIVITY}" 2>&1)"; then
      echo "  cold start dispatched."
      return 0
    fi
    echo "WARN: am start attempt ${attempt}/5 failed on ${SERIAL}: ${out}" >&2
    sleep 2
  done
  echo "ERROR: am start failed on ${SERIAL} after 5 attempts (activity=${ACTIVITY})." >&2
  "${ADB[@]}" logcat -d 2>/dev/null \
    | grep -iE 'AndroidRuntime|FATAL EXCEPTION|qa seed|ActivityManager' \
    | tail -30 >&2 || true
  return 1
}

echo "Seeding ${SCENARIO_ID} on ${SERIAL} (marker seed=${SEED_ID})"
echo "  pm clear..."
if ! timeout 60 "${ADB[@]}" shell pm clear "${COMPARTARENTA_QA_APP_ID}" >/dev/null; then
  echo "ERROR: pm clear failed on ${SERIAL} for ${COMPARTARENTA_QA_APP_ID}." >&2
  exit 1
fi

if [[ "${COMPARTARENTA_QA_GRANT_POST_NOTIFICATIONS:-0}" == "1" ]]; then
  qa_grant_post_notifications_on_serial "${SERIAL}"
fi

MARKER_NAME="compartarenta_qa_seed"
MARKER_DIR="app_flutter"
echo "  writing seed marker..."
"${ADB[@]}" shell "run-as ${COMPARTARENTA_QA_APP_ID} mkdir ${MARKER_DIR}" >/dev/null 2>&1 || true
if ! "${ADB[@]}" shell "run-as ${COMPARTARENTA_QA_APP_ID} sh -c 'echo ${SEED_ID} > ${MARKER_DIR}/${MARKER_NAME}'"; then
  echo "run-as seed marker failed (debug APK required)." >&2
  exit 1
fi

"${ADB[@]}" logcat -c >/dev/null 2>&1 || true
qa_start_seed_activity
qa_wait_for_boot_completed "${SERIAL}"

echo "  waiting for seed_applied marker (up to ~90s)..."
for attempt in $(seq 1 60); do
  applied="$(qa_pull_qa_seed_applied_id "${SERIAL}")"
  if [[ -z "${applied}" ]] && "${ADB[@]}" logcat -d 2>/dev/null \
    | grep -Fq "qa seed: applied scenario ${SEED_ID}"; then
    applied="${SEED_ID}"
  fi
  # String compare in [[ ]]; -eq is for integers only.
  if [[ "${applied}" == "${SEED_ID}" ]]; then
    if ! qa_verify_onboarding_complete_pref_on_serial "${SERIAL}"; then
      echo "ERROR: seed marker file matches but onboarding.complete is not true on ${SERIAL}." >&2
      exit 1
    fi
    if [[ "${SEED_ID}" == "fcm_wake_push_recipient" ]]; then
      echo "Waiting for routing push registration (app stays up until relay token is stored)..."
      push_ok=0
      for _ in $(seq 1 45); do
        if qa_verify_routing_push_refresh_on_serial "${SERIAL}"; then
          push_ok=1
          break
        fi
        sleep 2
      done
      if [[ "${push_ok}" -eq 0 ]]; then
        echo "ERROR: routing_push.last_refresh_ms never appeared on ${SERIAL}." >&2
        echo "Check relay routing_push_register (expect 200, not no_active_routing):" >&2
        echo "  compstack logs --since 5m relay | grep routing_push_register" >&2
        "${ADB[@]}" logcat -d 2>/dev/null \
          | grep -iE 'ClosedAppPushRegistrationService|routing_push|qa seed' \
          | tail -30 >&2 || true
        exit 1
      fi
      echo "Routing push token registered (local prefs confirm relay refresh)."
    fi
    echo "Seed applied (${SEED_ID})."
    if [[ "${SEED_ID}" == "fcm_wake_push_recipient" ]]; then
      # am kill: process dead but app not force-stopped — FCM wake can still run.
      "${ADB[@]}" shell am kill "${COMPARTARENTA_QA_APP_ID}" >/dev/null 2>&1 || true
    else
      "${ADB[@]}" shell am force-stop "${COMPARTARENTA_QA_APP_ID}" >/dev/null || true
    fi
    exit 0
  fi
  if "${ADB[@]}" logcat -d 2>/dev/null | grep -Fq "qa seed: unknown scenario id \"${SEED_ID}\""; then
    echo "ERROR: APK on ${SERIAL} does not know seed id '${SEED_ID}'." >&2
    echo "Rebuild: ./tool/melosw run qa:build-apk and re-run without --skip-build." >&2
    exit 1
  fi
  echo "  poll ${attempt}/60 applied=${applied:-<empty>}"
  sleep 1
done

echo "Timed out waiting for QA seed log line on ${SERIAL}." >&2
echo "Recent logcat:" >&2
"${ADB[@]}" logcat -d 2>/dev/null \
  | grep -iE 'qa seed|AndroidRuntime|FATAL EXCEPTION' \
  | tail -40 >&2 || true
if "${ADB[@]}" logcat -d 2>/dev/null | grep -Fq "qa seed: unknown scenario id \"${SEED_ID}\""; then
  echo "HINT: ${SERIAL} is running an APK that does not know seed id '${SEED_ID}'." >&2
  echo "Rebuild ./tool/melosw run qa:build-apk and install on this device before re-running." >&2
fi
echo "Check: adb -s ${SERIAL} logcat -d | grep 'qa seed'" >&2
exit 1
