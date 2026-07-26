#!/usr/bin/env bash
# Wipe app data and restore a named long-lived debug snapshot from
# qa/db_seeds/<name>/ (produced by run_db_snapshot_steal.sh).
#
# Usage:
#   ./tool/run_db_snapshot_restore.sh --name play-screenshots-v1
#   ANDROID_SERIAL=emulator-5554 ./tool/run_db_snapshot_restore.sh --name foo
#
# Requires a debug APK (run-as). Does not rebuild/install the APK.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"

qa_export_android_sdk_paths
qa_require_command adb

SCENARIO_ID="db_snapshot_restore"
SNAPSHOT_NAME=""

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
    --help|-h)
      echo "Usage: $0 --name <slug>" >&2
      echo "  pm clear + restore qa/db_seeds/<slug>/ onto the connected debug device." >&2
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
  echo "Usage: $0 --name <slug>" >&2
  exit 1
fi

IN_DIR="${COMPARTARENTA_QA_DB_SEEDS_DIR}/${SNAPSHOT_NAME}"
if [[ ! -d "${IN_DIR}" ]]; then
  echo "Snapshot not found: ${IN_DIR}" >&2
  exit 1
fi

PREFS_HOST="${IN_DIR}/shared_prefs/FlutterSharedPreferences.xml"
IDENTITY_HOST="${IN_DIR}/app_flutter/compartarenta_qa_identity_private.b64"
SQLITE_HOST=""
SQLITE_DEVICE_REL=""

# Prefer path recorded at steal; else discover any live Drift file in the snapshot.
if [[ -f "${IN_DIR}/meta.json" ]]; then
  SQLITE_DEVICE_REL="$(python3 - "${IN_DIR}/meta.json" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1], encoding="utf-8"))
print(meta.get("sqliteDevicePath") or "")
PY
)"
  if [[ -n "${SQLITE_DEVICE_REL}" && -s "${IN_DIR}/${SQLITE_DEVICE_REL}" ]]; then
    SQLITE_HOST="${IN_DIR}/${SQLITE_DEVICE_REL}"
  fi
fi
if [[ -z "${SQLITE_HOST}" ]]; then
  for candidate in \
    "${IN_DIR}/app_flutter/compartarenta/compartarenta.sqlite" \
    "${IN_DIR}/app_flutter/compartarenta/compartarenta.sqlite.sqlite"
  do
    if [[ -s "${candidate}" ]]; then
      SQLITE_HOST="${candidate}"
      SQLITE_DEVICE_REL="${candidate#"${IN_DIR}/"}"
      break
    fi
  done
fi
if [[ -z "${SQLITE_HOST}" ]]; then
  found="$(find "${IN_DIR}/app_flutter/compartarenta" -type f \( -name '*.sqlite' -o -name '*.sqlite.sqlite' \) 2>/dev/null | head -1 || true)"
  if [[ -n "${found}" && -s "${found}" ]]; then
    SQLITE_HOST="${found}"
    SQLITE_DEVICE_REL="${found#"${IN_DIR}/"}"
  fi
fi

for required in "${SQLITE_HOST}" "${PREFS_HOST}" "${IDENTITY_HOST}"; do
  if [[ -z "${required}" || ! -s "${required}" ]]; then
    echo "Missing or empty required snapshot file (sqlite/prefs/identity)." >&2
    echo "  sqlite=${SQLITE_HOST:-<missing>}" >&2
    echo "  prefs=${PREFS_HOST}" >&2
    echo "  identity=${IDENTITY_HOST}" >&2
    exit 1
  fi
done
if [[ -z "${SQLITE_DEVICE_REL}" ]]; then
  SQLITE_DEVICE_REL="${SQLITE_HOST#"${IN_DIR}/"}"
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

echo "=== ${SCENARIO_ID} | serial=${SERIAL} | name=${SNAPSHOT_NAME} ==="
echo "  pm clear..."
if ! timeout 60 "${ADB[@]}" shell pm clear "${APP_ID}" >/dev/null; then
  echo "ERROR: pm clear failed on ${SERIAL} for ${APP_ID}." >&2
  exit 1
fi

qa_grant_post_notifications_on_serial "${SERIAL}"

echo "  pushing snapshot files..."
"${ADB[@]}" shell "run-as ${APP_ID} mkdir -p app_flutter/compartarenta shared_prefs" \
  >/dev/null 2>&1 || true

qa_push_app_path "${SERIAL}" "${SQLITE_HOST}" "${SQLITE_DEVICE_REL}"

WAL_HOST="${SQLITE_HOST}-wal"
SHM_HOST="${SQLITE_HOST}-shm"
if [[ -s "${WAL_HOST}" ]]; then
  qa_push_app_path "${SERIAL}" "${WAL_HOST}" "${SQLITE_DEVICE_REL}-wal"
fi
if [[ -s "${SHM_HOST}" ]]; then
  qa_push_app_path "${SERIAL}" "${SHM_HOST}" "${SQLITE_DEVICE_REL}-shm"
fi

qa_push_app_path "${SERIAL}" "${PREFS_HOST}" \
  "shared_prefs/FlutterSharedPreferences.xml"
qa_push_app_path "${SERIAL}" "${IDENTITY_HOST}" \
  "app_flutter/compartarenta_qa_identity_private.b64"

echo "  writing restore marker..."
if ! "${ADB[@]}" shell \
  "run-as ${APP_ID} sh -c 'echo 1 > app_flutter/compartarenta_qa_snapshot_restore'"; then
  echo "Failed to write restore marker (debug APK + run-as required)." >&2
  exit 1
fi

# Ensure no QA seed marker overwrites the restored Drift DB.
"${ADB[@]}" shell \
  "run-as ${APP_ID} rm -f app_flutter/compartarenta_qa_seed app_flutter/compartarenta_qa_seed_applied.txt app_flutter/compartarenta_qa_snapshot_restore_done" \
  >/dev/null 2>&1 || true

echo "  cold start..."
if ! timeout 45 "${ADB[@]}" shell am start -n "${ACTIVITY}" >/dev/null; then
  echo "am start failed on ${SERIAL}" >&2
  exit 1
fi

echo "  waiting for restore_done (up to ~90s)..."
restore_ok=0
for _ in $(seq 1 90); do
  if qa_app_path_exists "${SERIAL}" \
    "app_flutter/compartarenta_qa_snapshot_restore_done"; then
    restore_ok=1
    break
  fi
  sleep 1
done
if [[ "${restore_ok}" -ne 1 ]]; then
  echo "Timed out waiting for compartarenta_qa_snapshot_restore_done." >&2
  "${ADB[@]}" logcat -d 2>/dev/null \
    | grep -iE 'qa db snapshot|AndroidRuntime|FATAL EXCEPTION' \
    | tail -40 >&2 || true
  exit 1
fi

if ! qa_verify_onboarding_complete_pref_on_serial "${SERIAL}"; then
  echo "WARN: onboarding.complete is not true after restore (snapshot may be mid-onboarding)." >&2
fi

echo "Scenario PASSED | ${SCENARIO_ID}. Restored: ${IN_DIR}"
