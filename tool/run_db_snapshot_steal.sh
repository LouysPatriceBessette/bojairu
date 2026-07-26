#!/usr/bin/env bash
# Steal (export) long-lived debug app state from a populated Android device.
#
# Captures Drift SQLite (+ WAL/SHM), Flutter SharedPreferences, and the relay
# identity private key (debug export). Writes a named snapshot under
# qa/db_seeds/<name>/ (gitignored) for later restore.
#
# Usage:
#   ./tool/run_db_snapshot_steal.sh --name play-screenshots-v1
#   ANDROID_SERIAL=emulator-5554 ./tool/run_db_snapshot_steal.sh --name foo
#
# Requires a debug APK (run-as). Does not wipe the device.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"

qa_export_android_sdk_paths
qa_require_command adb

SCENARIO_ID="db_snapshot_steal"
SNAPSHOT_NAME=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      if [[ $# -lt 2 ]]; then
        echo "--name requires a slug" >&2
        exit 1
      fi
      SNAPSHOT_NAME="$2"
      shift
      ;;
    --force)
      FORCE=1
      ;;
    --help|-h)
      echo "Usage: $0 --name <slug> [--force]" >&2
      echo "  Writes qa/db_seeds/<slug>/ from the connected debug device." >&2
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${SNAPSHOT_NAME}" ]]; then
  echo "Usage: $0 --name <slug> [--force]" >&2
  exit 1
fi

if [[ ! "${SNAPSHOT_NAME}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Invalid --name '${SNAPSHOT_NAME}' (use letters, digits, . _ -)." >&2
  exit 1
fi

if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  SERIAL="${ANDROID_SERIAL}"
else
  SERIAL="$(qa_adb_target_serial)" || {
    echo "No adb device in 'device' state. Connect one or set ANDROID_SERIAL." >&2
    exit 1
  }
  export ANDROID_SERIAL="${SERIAL}"
fi

APP_ID="${COMPARTARENTA_QA_APP_ID}"
ACTIVITY="${APP_ID}/com.compartarenta.compartarenta.MainActivity"
ADB=(adb -s "${SERIAL}")
OUT_DIR="${COMPARTARENTA_QA_DB_SEEDS_DIR}/${SNAPSHOT_NAME}"

if [[ -d "${OUT_DIR}" && "${FORCE}" -ne 1 ]]; then
  echo "Snapshot already exists: ${OUT_DIR}" >&2
  echo "Pass --force to overwrite, or choose another --name." >&2
  exit 1
fi

echo "=== ${SCENARIO_ID} | serial=${SERIAL} | name=${SNAPSHOT_NAME} ==="
echo "  force-stop..."
"${ADB[@]}" shell am force-stop "${APP_ID}" >/dev/null 2>&1 || true
sleep 1

echo "  clearing prior export markers..."
"${ADB[@]}" shell "run-as ${APP_ID} rm -f app_flutter/compartarenta_qa_snapshot_export app_flutter/compartarenta_qa_snapshot_export_done" \
  >/dev/null 2>&1 || true

echo "  writing identity export marker..."
"${ADB[@]}" shell "run-as ${APP_ID} mkdir -p app_flutter" >/dev/null 2>&1 || true
if ! "${ADB[@]}" shell "run-as ${APP_ID} sh -c 'echo 1 > app_flutter/compartarenta_qa_snapshot_export'"; then
  echo "Failed to write export marker (debug APK + run-as required)." >&2
  exit 1
fi

echo "  cold start for identity export..."
if ! timeout 45 "${ADB[@]}" shell am start -n "${ACTIVITY}" >/dev/null; then
  echo "am start failed on ${SERIAL}" >&2
  exit 1
fi

echo "  waiting for export_done (up to ~60s)..."
export_ok=0
for _ in $(seq 1 60); do
  if qa_app_path_exists "${SERIAL}" \
    "app_flutter/compartarenta_qa_snapshot_export_done"; then
    export_ok=1
    break
  fi
  sleep 1
done
if [[ "${export_ok}" -ne 1 ]]; then
  echo "Timed out waiting for compartarenta_qa_snapshot_export_done." >&2
  echo "Is the debug app installed and did bootstrap run?" >&2
  exit 1
fi

echo "  force-stop before file pull..."
"${ADB[@]}" shell am force-stop "${APP_ID}" >/dev/null 2>&1 || true
sleep 1

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/app_flutter/compartarenta" "${OUT_DIR}/shared_prefs"

FILES_PULLED=()

pull_required() {
  local device_rel="$1"
  local host_rel="$2"
  local host_path="${OUT_DIR}/${host_rel}"
  if ! qa_pull_app_path "${SERIAL}" "${device_rel}" "${host_path}"; then
    echo "Failed to pull required ${device_rel}" >&2
    exit 1
  fi
  FILES_PULLED+=("${host_rel}")
  echo "  pulled ${device_rel} ($(wc -c <"${host_path}" | tr -d ' ') bytes)"
}

pull_optional() {
  local device_rel="$1"
  local host_rel="$2"
  local host_path="${OUT_DIR}/${host_rel}"
  if ! qa_app_path_exists "${SERIAL}" "${device_rel}"; then
    echo "  skip (absent) ${device_rel}"
    return 0
  fi
  if qa_pull_app_path "${SERIAL}" "${device_rel}" "${host_path}"; then
    FILES_PULLED+=("${host_rel}")
    echo "  pulled ${device_rel} ($(wc -c <"${host_path}" | tr -d ' ') bytes)"
  else
    echo "  skip (pull failed) ${device_rel}" >&2
  fi
}

SQLITE_DEVICE="$(qa_resolve_drift_sqlite_device_path "${SERIAL}")" || exit 1
echo "  drift sqlite on device: ${SQLITE_DEVICE}"
pull_required "${SQLITE_DEVICE}" "${SQLITE_DEVICE}"
# WAL/SHM use the same basename as the live file (may be *.sqlite.sqlite-wal).
pull_optional "${SQLITE_DEVICE}-wal" "${SQLITE_DEVICE}-wal"
pull_optional "${SQLITE_DEVICE}-shm" "${SQLITE_DEVICE}-shm"
pull_required \
  "shared_prefs/FlutterSharedPreferences.xml" \
  "shared_prefs/FlutterSharedPreferences.xml"
pull_required \
  "app_flutter/compartarenta_qa_identity_private.b64" \
  "app_flutter/compartarenta_qa_identity_private.b64"

META_PATH="${OUT_DIR}/meta.json"
python3 - "${META_PATH}" "${APP_ID}" "${SERIAL}" "${SNAPSHOT_NAME}" "${SQLITE_DEVICE}" "${FILES_PULLED[@]}" <<'PY'
import json, sys
from datetime import datetime, timezone
path, app_id, serial, name, sqlite_device, *files = sys.argv[1:]
payload = {
    "formatVersion": 1,
    "name": name,
    "appId": app_id,
    "serialAtSteal": serial,
    "stolenAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "sqliteDevicePath": sqlite_device,
    "files": files,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

echo "Snapshot written: ${OUT_DIR}"
echo "Scenario PASSED | ${SCENARIO_ID}. Snapshot: ${OUT_DIR}"
