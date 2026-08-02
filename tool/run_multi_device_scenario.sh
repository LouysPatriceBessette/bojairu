#!/usr/bin/env bash
# Run a multi-device QA scenario (two or more emulators coordinated by a shell script).
#
# Usage:
#   ./tool/run_multi_device_scenario.sh contact_handshake_happy_path
#   ./tool/run_multi_device_scenario.sh contact_handshake_bug_91 [--attempts 10]
#
# Options:
#   --skip-build       reuse existing debug APK
#   --skip-install     do not adb install
#   --skip-restore     keep emulator clocks after the run
#   --attempts N       override manifest attempts (bug probes)
#   --artifact-dir DIR write outputs under DIR

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"

qa_export_android_sdk_paths
export PATH="${HOME}/.maestro/bin:${PATH}"

SCENARIO_ID=""
SKIP_BUILD=0
SKIP_INSTALL=0
SKIP_RESTORE=0
ATTEMPTS_OVERRIDE=""
ARTIFACT_DIR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    --skip-restore) SKIP_RESTORE=1 ;;
    --attempts)
      if [[ $# -lt 2 ]]; then
        echo "--attempts requires a value" >&2
        exit 1
      fi
      ATTEMPTS_OVERRIDE="$2"
      shift
      ;;
    --artifact-dir)
      if [[ $# -lt 2 ]]; then
        echo "--artifact-dir requires a path" >&2
        exit 1
      fi
      ARTIFACT_DIR_OVERRIDE="$2"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 <multi-scenario-id> [--skip-build] [--skip-install] [--skip-restore] [--attempts N] [--artifact-dir DIR]" >&2
      echo "Example: $0 contact_handshake_happy_path --skip-build" >&2
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -n "${SCENARIO_ID}" ]]; then
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      SCENARIO_ID="$1"
      ;;
  esac
  shift
done

if [[ -z "${SCENARIO_ID}" ]]; then
  echo "Usage: $0 <multi-scenario-id> [--skip-build] [--skip-install] [--skip-restore] [--attempts N] [--artifact-dir DIR]" >&2
  exit 1
fi

MANIFEST="${ROOT}/qa/multi_scenarios/${SCENARIO_ID}.yaml"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "Unknown multi-scenario: ${MANIFEST}" >&2
  exit 1
fi

if ! command -v maestro >/dev/null 2>&1; then
  if [[ -x "${HOME}/.maestro/bin/maestro" ]]; then
    export PATH="${HOME}/.maestro/bin:${PATH}"
  else
    echo "Maestro not found. Run ./tool/install_maestro.sh" >&2
    exit 1
  fi
fi

COORDINATOR="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" coordinator)"
MODE="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" mode 2>/dev/null || true)"
DEVICE_DATE_RAW="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" device_date)"
TIMEZONE="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" timezone)"
DEVICE_DATE="$(qa_resolve_device_date "${DEVICE_DATE_RAW}" "${TIMEZONE}")"
if [[ "${DEVICE_DATE_RAW}" == "current" ]]; then
  echo "device_date=current resolved to ${DEVICE_DATE} (${TIMEZONE})"
fi
MANIFEST_SKIP_RESTORE="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" skip_restore 2>/dev/null || true)"
if [[ "${MANIFEST_SKIP_RESTORE}" == "true" || "${MANIFEST_SKIP_RESTORE}" == "1" ]]; then
  SKIP_RESTORE=1
  echo "skip_restore=true from manifest (keeping emulator clocks after run)"
fi
MANIFEST_ATTEMPTS="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" attempts 2>/dev/null || true)"
ROLES="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" roles)"

ATTEMPTS="${ATTEMPTS_OVERRIDE:-${MANIFEST_ATTEMPTS:-1}}"
if ! [[ "${ATTEMPTS}" =~ ^[0-9]+$ ]] || [[ "${ATTEMPTS}" -lt 1 ]]; then
  echo "Invalid attempts value: ${ATTEMPTS}" >&2
  exit 1
fi

COORDINATOR_SCRIPT="${ROOT}/tool/coordinators/${COORDINATOR}.sh"
if [[ ! -x "${COORDINATOR_SCRIPT}" ]]; then
  if [[ -f "${COORDINATOR_SCRIPT}" ]]; then
    chmod +x "${COORDINATOR_SCRIPT}"
  else
    echo "Coordinator script missing: ${COORDINATOR_SCRIPT}" >&2
    exit 1
  fi
fi

# Count distinct AVDs across roles.
declare -a ROLE_NAMES=()
declare -A ROLE_AVD=()
declare -A ROLE_SEED=()
declare -A ROLE_FLOW=()
NUM_AVDS=0
declare -A SEEN_AVD=()

for role in ${ROLES}; do
  ROLE_NAMES+=("${role}")
  avd="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" "role.${role}.avd")"
  seed="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" "role.${role}.seed")"
  flow="$(python3 "${ROOT}/tool/qa_multi_scenario_manifest.py" "${MANIFEST}" "role.${role}.flow")"
  ROLE_AVD["${role}"]="${avd}"
  ROLE_SEED["${role}"]="${seed}"
  ROLE_FLOW["${role}"]="${flow}"
  if [[ -z "${SEEN_AVD[${avd}]:-}" ]]; then
    SEEN_AVD["${avd}"]=1
    NUM_AVDS=$((NUM_AVDS + 1))
  fi
done

if [[ "${NUM_AVDS}" -lt 2 ]]; then
  echo "Multi-scenario ${SCENARIO_ID} needs at least two distinct AVDs." >&2
  exit 1
fi

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  "${ROOT}/tool/build_qa_apk.sh"
fi

EMULATOR_ARGS=(-n "${NUM_AVDS}")
if [[ "${SKIP_INSTALL}" -eq 0 ]]; then
  EMULATOR_ARGS+=(--install-apk)
fi
"${ROOT}/qa/run-emulators.sh" "${EMULATOR_ARGS[@]}"

declare -A AVD_SERIAL=()
for role in "${ROLE_NAMES[@]}"; do
  avd="${ROLE_AVD[${role}]}"
  if [[ -n "${AVD_SERIAL[${avd}]:-}" ]]; then
    continue
  fi
  serial="$(qa_serial_for_avd "${avd}")" || {
    echo "ERROR: Could not resolve adb serial for AVD ${avd}" >&2
    echo "Hint: adb devices; check ${COMPARTARENTA_QA_AVD_SERIALS_MAP}" >&2
    exit 1
  }
  AVD_SERIAL["${avd}"]="${serial}"
  echo "Role AVD ${avd} -> ${serial}"
done

if [[ -n "${ARTIFACT_DIR_OVERRIDE}" ]]; then
  ARTIFACT_ROOT="${ARTIFACT_DIR_OVERRIDE}"
else
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  ARTIFACT_ROOT="${ROOT}/qa/artifacts/multi-${SCENARIO_ID}/${STAMP}"
fi
mkdir -p "${ARTIFACT_ROOT}"

for role in "${ROLE_NAMES[@]}"; do
  avd="${ROLE_AVD[${role}]}"
  serial="${AVD_SERIAL[${avd}]}"
  qa_set_android_date_on_serial "${serial}" "${DEVICE_DATE}" "${TIMEZONE}"
  qa_seed_scenario_on_serial "${serial}" "${ROLE_SEED[${role}]}"
  qa_prepare_for_maestro "${serial}"
done

export COMPARTARENTA_MULTI_SCENARIO_ID="${SCENARIO_ID}"
export COMPARTARENTA_MULTI_MANIFEST="${MANIFEST}"
export COMPARTARENTA_MULTI_MODE="${MODE}"
export COMPARTARENTA_MULTI_ATTEMPTS="${ATTEMPTS}"
export COMPARTARENTA_MULTI_ARTIFACT_ROOT="${ARTIFACT_ROOT}"
export COMPARTARENTA_MULTI_DEVICE_DATE="${DEVICE_DATE}"
export COMPARTARENTA_MULTI_TIMEZONE="${TIMEZONE}"

for role in "${ROLE_NAMES[@]}"; do
  avd="${ROLE_AVD[${role}]}"
  serial="${AVD_SERIAL[${avd}]}"
  export "COMPARTARENTA_ROLE_${role^^}_AVD=${avd}"
  export "COMPARTARENTA_ROLE_${role^^}_SERIAL=${serial}"
  export "COMPARTARENTA_ROLE_${role^^}_SEED=${ROLE_SEED[${role}]}"
  export "COMPARTARENTA_ROLE_${role^^}_FLOW=${ROOT}/${ROLE_FLOW[${role}]}"
done

echo "Running multi-device coordinator ${COORDINATOR} (mode=${MODE:-default}, attempts=${ATTEMPTS})"
set +e
"${COORDINATOR_SCRIPT}"
COORD_EXIT=$?
set -e

if [[ "${SKIP_RESTORE}" -eq 0 ]]; then
  "${ROOT}/tool/restore_android_date.sh" || true
fi

cp "${MANIFEST}" "${ARTIFACT_ROOT}/multi-scenario.yaml"

echo ""
echo "================================================================================"
if [[ "${MODE}" == "bug_91_probe" && -f "${ARTIFACT_ROOT}/bug_91_result.txt" ]]; then
  VERDICT="$(grep -E '^verdict=' "${ARTIFACT_ROOT}/bug_91_result.txt" | head -1 | cut -d= -f2-)"
  case "${VERDICT}" in
    COULD_NOT_REPRODUCE)
      echo "Test PASSED | ${SCENARIO_ID} (verdict: COULD_NOT_REPRODUCE — CASE CLOSED)"
      ;;
    REPRODUCED)
      echo "Test FAILED | ${SCENARIO_ID} (verdict: REPRODUCED — bug 9.1 asymmetric handshake)"
      ;;
    *)
      if [[ "${COORD_EXIT}" -eq 0 ]]; then
        echo "Test PASSED | ${SCENARIO_ID}"
      else
        echo "Test FAILED | ${SCENARIO_ID} (exit ${COORD_EXIT})"
      fi
      ;;
  esac
elif [[ "${MODE}" == "bug_122_probe" || "${MODE}" == "bug_122_regression" ]] && [[ -f "${ARTIFACT_ROOT}/bug_122_result.txt" ]]; then
  VERDICT="$(grep -E '^verdict=' "${ARTIFACT_ROOT}/bug_122_result.txt" | head -1 | cut -d= -f2-)"
  case "${VERDICT}" in
    COMPLETED|COULD_NOT_REPRODUCE)
      echo "Test PASSED | ${SCENARIO_ID} (verdict: ${VERDICT})"
      ;;
    REPRODUCED)
      echo "Test FAILED | ${SCENARIO_ID} (verdict: REPRODUCED — bug 1.22 duplicate Monica or regression failure)"
      ;;
    *)
      if [[ "${COORD_EXIT}" -eq 0 ]]; then
        echo "Test PASSED | ${SCENARIO_ID}"
      else
        echo "Test FAILED | ${SCENARIO_ID} (exit ${COORD_EXIT})"
      fi
      ;;
  esac
elif [[ "${COORD_EXIT}" -eq 0 ]]; then
  echo "Test PASSED | ${SCENARIO_ID}"
else
  echo "Test FAILED | ${SCENARIO_ID} (exit ${COORD_EXIT})"
fi
echo "Artifacts: ${ARTIFACT_ROOT}"
echo "================================================================================"
echo ""

exit "${COORD_EXIT}"
