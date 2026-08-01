#!/usr/bin/env bash
# Coordinator: vehicle sharing offer happy path (Louys owner → Monica borrower).
# Seeds already include a connected Louys↔Monica pair (no handshake phase).
#
# Path under test (notification taps — do NOT force-stop around shade taps):
#   Louys sends offer → Monica shade tap → hub Accept → accessible card
#   → Louys accept notification shade tap → hub green check
#
# Expects env from tool/run_multi_device_scenario.sh:
#   COMPARTARENTA_ROLE_OWNER_SERIAL, COMPARTARENTA_ROLE_BORROWER_SERIAL, …
#
# run_multi_device_scenario already seeds both roles + force-stops them.
# Do NOT pm clear / seed again here (skill: no useless double seed).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../qa_env.sh
source "${ROOT}/tool/qa_env.sh"

OWNER_SERIAL="${COMPARTARENTA_ROLE_OWNER_SERIAL:?missing owner serial}"
BORROWER_SERIAL="${COMPARTARENTA_ROLE_BORROWER_SERIAL:?missing borrower serial}"
ARTIFACT_ROOT="${COMPARTARENTA_MULTI_ARTIFACT_ROOT:?missing artifact root}"
SCENARIO_ID="${COMPARTARENTA_MULTI_SCENARIO_ID:-vehicle_sharing_offer_happy_path}"

FLOWS_DIR="${ROOT}/qa/flows"
OWNER_SEND_FLOW="${FLOWS_DIR}/vehicle_sharing_offer_owner_send.yaml"
BORROWER_TAP_NOTIF_FLOW="${FLOWS_DIR}/vehicle_sharing_offer_borrower_tap_notification.yaml"
BORROWER_ACCEPT_FLOW="${FLOWS_DIR}/vehicle_sharing_offer_borrower_accept_from_hub.yaml"
OWNER_TAP_ACCEPT_NOTIF_FLOW="${FLOWS_DIR}/vehicle_sharing_offer_owner_tap_accept_notification.yaml"
OWNER_ASSERT_HUB_FLOW="${FLOWS_DIR}/vehicle_sharing_offer_owner_assert_hub_active.yaml"

_qa_avd_for_serial() {
  local serial="$1"
  case "${serial}" in
    "${OWNER_SERIAL}") echo "Louys-QA" ;;
    "${BORROWER_SERIAL}") echo "Monica-QA" ;;
    *) echo "${serial}" ;;
  esac
}

_log_phase() {
  echo "==="
  echo "=== $1"
  echo "==="
}

_run_maestro() {
  local label="$1"
  local serial="$2"
  local flow="$3"
  shift 3
  local out avd
  out="$(qa_maestro_artifact_dir "${label}")"
  avd="$(_qa_avd_for_serial "${serial}")"
  mkdir -p "${out}"
  echo "  maestro device=${avd} serial=${serial}"
  echo "  maestro flow=$(basename "${flow}") -> ${out}"
  if ! qa_maestro_test_on_serial "${serial}" "${flow}" "${out}" "$@"; then
    echo "  maestro FAILED on ${avd}: ${label} ($(basename "${flow}"))" >&2
    return 1
  fi
}

_warm_start_borrower() {
  echo "  Warm-start Monica so steady inbox polling runs during Louys send..."
  adb -s "${BORROWER_SERIAL}" shell am start -n \
    "${COMPARTARENTA_QA_APP_ID}/com.compartarenta.compartarenta.MainActivity" \
    >/dev/null 2>&1 || true
  if ! qa_wait_for_logcat_on_serial "${BORROWER_SERIAL}" "steady inbox poll:" 90; then
    echo "  Monica warm-start: timed out waiting for steady inbox poll" >&2
    adb -s "${BORROWER_SERIAL}" logcat -d 2>/dev/null \
      | grep -E 'steady inbox|vehicle_sharing' | tail -30 >&2 || true
    return 1
  fi
  echo "  Monica warm-start: steady inbox poll seen"
}

echo "================================================================================"
echo "Vehicle sharing offer happy path — Louys (owner) → Monica (borrower)"
echo "  Louys-QA=${OWNER_SERIAL}  Monica-QA=${BORROWER_SERIAL}"
echo "  Seed: from run_multi (no second pm clear); notification TAP path (no force-stop around shade)"
echo "================================================================================"

ATTEMPT_DIR="${ARTIFACT_ROOT}/run-001"
mkdir -p "${ATTEMPT_DIR}"

_log_phase "Grant POST_NOTIFICATIONS (no re-seed)"
qa_grant_post_notifications_on_serial "${OWNER_SERIAL}"
qa_grant_post_notifications_on_serial "${BORROWER_SERIAL}"
# Louys only: stop so Maestro launchApp starts clean. Monica must stay startable
# without another force-stop before warm-start (polling during Louys send).
qa_prepare_for_maestro "${OWNER_SERIAL}"

_log_phase "Warm-start Monica (keep polling alive)"
qa_clear_logcat_on_serial "${BORROWER_SERIAL}"
_warm_start_borrower || exit 1

_log_phase "Louys sends vehicle sharing offer (QA Civic → Monica)"
qa_clear_logcat_on_serial "${OWNER_SERIAL}"
qa_clear_logcat_on_serial "${BORROWER_SERIAL}"
_run_maestro "${ATTEMPT_DIR}/owner-send" "${OWNER_SERIAL}" \
  "${OWNER_SEND_FLOW}" || exit 1

_log_phase "Wait for Monica to import offer (logcat)"
if ! qa_wait_for_logcat_on_serial "${BORROWER_SERIAL}" "vehicle_sharing_offer imported" 90; then
  echo "  timed out waiting for vehicle_sharing_offer imported on Monica" >&2
  adb -s "${BORROWER_SERIAL}" logcat -d 2>/dev/null \
    | grep -E 'vehicle_sharing|steady inbox' | tail -40 >&2 || true
  exit 1
fi
echo "  Monica: offer imported (logcat)"

_log_phase "Monica taps offer notification (shade) → hub accept"
# Do NOT force-stop: that cancels local notifications (housing_payment_reminder lesson).
echo "  KEYCODE_HOME on Monica (background only — keeps notification)..."
adb -s "${BORROWER_SERIAL}" shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
sleep 0.4
echo "  Opening notification shade on Monica..."
qa_open_notification_shade_on_serial "${BORROWER_SERIAL}"
sleep 0.4
_run_maestro "${ATTEMPT_DIR}/borrower-tap-notification" "${BORROWER_SERIAL}" \
  "${BORROWER_TAP_NOTIF_FLOW}" || exit 1
qa_clear_logcat_on_serial "${OWNER_SERIAL}"
_run_maestro "${ATTEMPT_DIR}/borrower-accept" "${BORROWER_SERIAL}" \
  "${BORROWER_ACCEPT_FLOW}" || exit 1

_log_phase "Wait for Louys to apply accept + show notification (logcat)"
if ! qa_wait_for_logcat_on_serial "${OWNER_SERIAL}" \
  "vehicle_sharing_offer_accept applied=true" 90; then
  echo "  timed out waiting for vehicle_sharing_offer_accept applied=true on Louys" >&2
  adb -s "${OWNER_SERIAL}" logcat -d 2>/dev/null \
    | grep -E 'vehicle_sharing_offer_accept|steady inbox' | tail -40 >&2 || true
  exit 1
fi
echo "  Louys: accept applied (logcat)"
if ! qa_wait_for_logcat_on_serial "${OWNER_SERIAL}" \
  "vehicle_sharing_offer_accept notification shown" 30; then
  echo "  timed out waiting for accept notification shown on Louys" >&2
  adb -s "${OWNER_SERIAL}" logcat -d 2>/dev/null \
    | grep -E 'vehicle_sharing_offer_accept|notification' | tail -40 >&2 || true
  exit 1
fi
echo "  Louys: accept notification shown (logcat)"

_log_phase "Louys taps accept notification (shade) → hub active check"
# Louys may still be on Partages from send — HOME keeps the accept notification.
echo "  KEYCODE_HOME on Louys (background only — keeps notification)..."
adb -s "${OWNER_SERIAL}" shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
sleep 0.4
echo "  Opening notification shade on Louys..."
qa_open_notification_shade_on_serial "${OWNER_SERIAL}"
sleep 0.4
_run_maestro "${ATTEMPT_DIR}/owner-tap-accept-notification" "${OWNER_SERIAL}" \
  "${OWNER_TAP_ACCEPT_NOTIF_FLOW}" || exit 1
_run_maestro "${ATTEMPT_DIR}/owner-assert-hub" "${OWNER_SERIAL}" \
  "${OWNER_ASSERT_HUB_FLOW}" || exit 1

echo "Scenario PASSED | ${SCENARIO_ID}. Artifacts: ${ARTIFACT_ROOT}"
exit 0
