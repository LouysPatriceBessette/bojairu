#!/usr/bin/env bash
# Coordinator: seed-only usage history through 2nd full tank (preliminary conso).
# Louys: active share + 7 sessions + 2 full tanks; Monica: 4 sessions + 2 full tanks.
# No offer/accept UI — asserts hubs then leaves apps for manual follow-up.
#
# Manifest forces device_date=current + America/Toronto on both AVDs at seed and
# skip_restore=true so clocks stay aligned for manual follow-up.
#
# Expects env from tool/run_multi_device_scenario.sh:
#   COMPARTARENTA_ROLE_OWNER_SERIAL, COMPARTARENTA_ROLE_BORROWER_SERIAL, …
#
# run_multi_device_scenario already seeds both roles + force-stops them.
# Do NOT pm clear / seed again here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../qa_env.sh
source "${ROOT}/tool/qa_env.sh"

OWNER_SERIAL="${COMPARTARENTA_ROLE_OWNER_SERIAL:?missing owner serial}"
BORROWER_SERIAL="${COMPARTARENTA_ROLE_BORROWER_SERIAL:?missing borrower serial}"
ARTIFACT_ROOT="${COMPARTARENTA_MULTI_ARTIFACT_ROOT:?missing artifact root}"
SCENARIO_ID="${COMPARTARENTA_MULTI_SCENARIO_ID:-vehicle_sharing_usage_history_seed_2nd_fill}"

FLOWS_DIR="${ROOT}/qa/flows"
OWNER_ASSERT_FLOW="${FLOWS_DIR}/vehicle_sharing_active_owner_assert_hub.yaml"
BORROWER_ASSERT_FLOW="${FLOWS_DIR}/vehicle_sharing_active_borrower_assert_hub.yaml"

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

echo "================================================================================"
echo "Vehicle sharing USAGE HISTORY 2nd-fill seed"
echo "  Louys-QA=${OWNER_SERIAL}  Monica-QA=${BORROWER_SERIAL}"
echo "  Seed: from run_multi (no second pm clear); assert hubs only"
echo "================================================================================"

ATTEMPT_DIR="${ARTIFACT_ROOT}/run-001"
mkdir -p "${ATTEMPT_DIR}"

_log_phase "Grant POST_NOTIFICATIONS (no re-seed)"
qa_grant_post_notifications_on_serial "${OWNER_SERIAL}"
qa_grant_post_notifications_on_serial "${BORROWER_SERIAL}"
qa_prepare_for_maestro "${OWNER_SERIAL}"
qa_prepare_for_maestro "${BORROWER_SERIAL}"

_log_phase "Louys asserts active share on hub"
_run_maestro "${ATTEMPT_DIR}/owner-assert-hub" "${OWNER_SERIAL}" \
  "${OWNER_ASSERT_FLOW}" || exit 1

_log_phase "Monica asserts accessible vehicle on hub"
_run_maestro "${ATTEMPT_DIR}/borrower-assert-hub" "${BORROWER_SERIAL}" \
  "${BORROWER_ASSERT_FLOW}" || exit 1

_log_phase "Leave both apps on home for manual exploration"
adb -s "${OWNER_SERIAL}" shell am start -n \
  "${COMPARTARENTA_QA_APP_ID}/com.compartarenta.compartarenta.MainActivity" \
  >/dev/null 2>&1 || true
adb -s "${BORROWER_SERIAL}" shell am start -n \
  "${COMPARTARENTA_QA_APP_ID}/com.compartarenta.compartarenta.MainActivity" \
  >/dev/null 2>&1 || true

echo "Scenario PASSED | ${SCENARIO_ID}. Artifacts: ${ARTIFACT_ROOT}"
echo "Manual: both AVDs seeded with usage-history journal (sessions + 2 pleins)."
exit 0
