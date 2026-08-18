#!/usr/bin/env bash
# Run one manual QA scenario end-to-end on the Android emulator.
#
# Usage: ./tool/run_scenario.sh settlement_open
# Options:
#   --skip-build       reuse existing debug APK
#   --skip-install     do not adb install
#   --skip-restore     keep emulator clock after the run
#   --artifact-dir DIR write Maestro output to DIR (created if missing)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"

qa_export_android_sdk_paths
export PATH="${HOME}/.maestro/bin:${PATH}"

SCENARIO_ID="${1:-}"
shift || true

SKIP_BUILD=0
SKIP_INSTALL=0
SKIP_RESTORE=0
ARTIFACT_DIR_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    --skip-restore) SKIP_RESTORE=1 ;;
    --artifact-dir)
      ARTIFACT_DIR_OVERRIDE="${2:-}"
      if [[ -z "${ARTIFACT_DIR_OVERRIDE}" ]]; then
        echo "--artifact-dir requires a path" >&2
        exit 1
      fi
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${SCENARIO_ID}" ]]; then
  echo "Usage: $0 <scenario-id> [--skip-build] [--skip-install] [--skip-restore] [--artifact-dir DIR]" >&2
  exit 1
fi

MANIFEST="${ROOT}/qa/scenarios/${SCENARIO_ID}.yaml"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "Unknown scenario: ${MANIFEST}" >&2
  exit 1
fi

DEVICE_DATE_RAW="$(python3 "${ROOT}/tool/qa_scenario_manifest.py" "${MANIFEST}" device_date)"
TIMEZONE="$(python3 "${ROOT}/tool/qa_scenario_manifest.py" "${MANIFEST}" timezone)"
DEVICE_DATE="$(qa_resolve_device_date "${DEVICE_DATE_RAW}" "${TIMEZONE}")"
if [[ "${DEVICE_DATE_RAW}" == "current" ]]; then
  echo "device_date=current resolved to ${DEVICE_DATE} (${TIMEZONE})"
fi
FLOW_REL="$(python3 "${ROOT}/tool/qa_scenario_manifest.py" "${MANIFEST}" flow)"
FLOW_PATH="${ROOT}/${FLOW_REL}"
if [[ ! -f "${FLOW_PATH}" ]]; then
  echo "Flow file missing: ${FLOW_PATH}" >&2
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

"${ROOT}/tool/start_qa_emulator.sh"

EMULATOR_SERIAL="$(qa_use_emulator_adb_serial)"
echo "Using emulator ${EMULATOR_SERIAL} (ANDROID_SERIAL)"

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  "${ROOT}/tool/build_qa_apk.sh"
fi
if [[ "${SKIP_INSTALL}" -eq 0 ]]; then
  "${ROOT}/tool/install_qa_apk.sh"
fi

"${ROOT}/tool/set_android_date.sh" "${DEVICE_DATE}" "${TIMEZONE}"
"${ROOT}/tool/seed_qa_scenario.sh" "${SCENARIO_ID}"
qa_prepare_for_maestro "${EMULATOR_SERIAL}"

if [[ -n "${ARTIFACT_DIR_OVERRIDE}" ]]; then
  ARTIFACT_DIR="${ARTIFACT_DIR_OVERRIDE}"
  mkdir -p "${ARTIFACT_DIR}"
else
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  ARTIFACT_DIR="${ROOT}/qa/artifacts/${SCENARIO_ID}/${STAMP}"
  mkdir -p "${ARTIFACT_DIR}"
fi

echo "Running Maestro flow ${FLOW_REL} on ${EMULATOR_SERIAL}"
maestro test --udid "${EMULATOR_SERIAL}" "${FLOW_PATH}" --test-output-dir "${ARTIFACT_DIR}"

if [[ "${SKIP_RESTORE}" -eq 0 ]]; then
  "${ROOT}/tool/restore_android_date.sh"
fi

cp "${MANIFEST}" "${ARTIFACT_DIR}/scenario.yaml"
echo "Scenario PASSED | ${SCENARIO_ID}. Artifacts: ${ARTIFACT_DIR}"
