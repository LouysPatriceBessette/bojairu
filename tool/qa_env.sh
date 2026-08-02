#!/usr/bin/env bash
# Shared constants and helpers for manual Android QA / E2E tooling.
# Source from repo-root scripts: source "$(dirname "$0")/qa_env.sh"

if [[ -z "${COMPARTARENTA_ROOT:-}" ]]; then
  _qa_env_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  COMPARTARENTA_ROOT="$(cd "${_qa_env_script_dir}/.." && pwd)"
fi

export COMPARTARENTA_ROOT

# --- Defaults (override via env before calling scripts) -----------------------

export COMPARTARENTA_QA_AVD_NAME="${COMPARTARENTA_QA_AVD_NAME:-Bojairu-QA}"
export COMPARTARENTA_QA_APP_ID="${COMPARTARENTA_QA_APP_ID:-app.incoherences.bojairu.dev}"
export COMPARTARENTA_QA_SYSTEM_IMAGE="${COMPARTARENTA_QA_SYSTEM_IMAGE:-system-images;android-34;google_apis;x86_64}"
export COMPARTARENTA_QA_DEVICE_PROFILE="${COMPARTARENTA_QA_DEVICE_PROFILE:-pixel_7}"
export COMPARTARENTA_QA_API_BASE_URL="${COMPARTARENTA_QA_API_BASE_URL:-https://sync.incoherences.org}"
export COMPARTARENTA_QA_DEFAULT_TIMEZONE="${COMPARTARENTA_QA_DEFAULT_TIMEZONE:-America/Toronto}"

export COMPARTARENTA_QA_LOCAL_DIR="${COMPARTARENTA_ROOT}/qa/.local"
export COMPARTARENTA_QA_CLOCK_STATE="${COMPARTARENTA_QA_LOCAL_DIR}/clock-restore.env"
export COMPARTARENTA_QA_AVD_SERIALS_MAP="${COMPARTARENTA_QA_LOCAL_DIR}/avd-serials.map"
export COMPARTARENTA_QA_APK_PATH="${COMPARTARENTA_QA_APK_PATH:-${COMPARTARENTA_ROOT}/mobile/build/app/outputs/flutter-apk/app-dev-debug.apk}"
export COMPARTARENTA_QA_DB_SEEDS_DIR="${COMPARTARENTA_QA_DB_SEEDS_DIR:-${COMPARTARENTA_ROOT}/qa/db_seeds}"

# Persona AVD order must match qa/run-emulators.sh fixed ports (5554, 5556, …).
COMPARTARENTA_QA_PERSONA_AVD_NAMES=(
  "Louys-QA"
  "Monica-QA"
  "Roberr-QA"
  "Liuva-QA"
  "Leo-QA"
)

# --- Android SDK resolution -------------------------------------------------

qa_resolve_android_sdk_root() {
  if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}" ]]; then
    echo "${ANDROID_SDK_ROOT}"
    return 0
  fi
  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}" ]]; then
    echo "${ANDROID_HOME}"
    return 0
  fi
  if [[ -d "${HOME}/Android/Sdk" ]]; then
    echo "${HOME}/Android/Sdk"
    return 0
  fi
  return 1
}

qa_export_android_sdk_paths() {
  local sdk_root
  sdk_root="$(qa_resolve_android_sdk_root)" || {
    echo "Android SDK not found. Set ANDROID_SDK_ROOT or install the SDK." >&2
    return 1
  }
  export ANDROID_SDK_ROOT="${sdk_root}"
  export ANDROID_HOME="${sdk_root}"
  export PATH="${sdk_root}/platform-tools:${sdk_root}/emulator:${sdk_root}/cmdline-tools/latest/bin:${PATH}"
}

qa_require_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Required command not found on PATH: ${name}" >&2
    return 1
  fi
}

qa_ensure_local_dir() {
  mkdir -p "${COMPARTARENTA_QA_LOCAL_DIR}"
}

qa_wait_for_boot_completed() {
  local serial="${1:-}"
  local adb_args=()
  if [[ -n "${serial}" ]]; then
    adb_args=(-s "${serial}")
  fi
  adb "${adb_args[@]}" wait-for-device
  local boot_completed=""
  local attempts=0
  while [[ "${boot_completed}" != "1" && "${attempts}" -lt 120 ]]; do
    boot_completed="$(adb "${adb_args[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "${boot_completed}" == "1" ]]; then
      break
    fi
    sleep 2
    attempts=$((attempts + 1))
  done
  if [[ "${boot_completed}" != "1" ]]; then
    echo "Timed out waiting for emulator boot (sys.boot_completed)." >&2
    return 1
  fi
}

qa_wait_for_emulator_serial() {
  local serial=""
  local attempts=0
  while [[ -z "${serial}" && "${attempts}" -lt 120 ]]; do
    serial="$(adb devices | awk '/^emulator-[0-9]+\tdevice$/{print $1; exit}')"
    if [[ -n "${serial}" ]]; then
      echo "${serial}"
      return 0
    fi
    sleep 2
    attempts=$((attempts + 1))
  done
  echo "Timed out waiting for an emulator in 'device' state (adb devices)." >&2
  adb devices >&2 || true
  return 1
}

qa_use_emulator_adb_serial() {
  local serial
  serial="$(qa_wait_for_emulator_serial)"
  export ANDROID_SERIAL="${serial}"
  echo "${serial}"
}

qa_adb_target_serial() {
  # Prefer an emulator when several devices are connected.
  local serial
  serial="$(adb devices | awk '/^emulator-[0-9]+\tdevice$/{print $1; exit}')"
  if [[ -n "${serial}" ]]; then
    echo "${serial}"
    return 0
  fi
  serial="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
  if [[ -n "${serial}" ]]; then
    echo "${serial}"
    return 0
  fi
  return 1
}

qa_apk_contains_libflutter_for_abi() {
  local apk="$1"
  local lib_abi="$2"
  unzip -Z1 "${apk}" "lib/${lib_abi}/libflutter.so" 2>/dev/null \
    | grep -Fxq "lib/${lib_abi}/libflutter.so"
}

# Grant Android 13+ POST_NOTIFICATIONS after pm clear (until revoked in system settings).
qa_grant_post_notifications_on_serial() {
  local serial="$1"
  local app_id="${2:-${COMPARTARENTA_QA_APP_ID}}"
  local sdk
  sdk="$(adb -s "${serial}" shell getprop ro.build.version.sdk | tr -d '\r')"
  if [[ -z "${sdk}" || "${sdk}" -lt 33 ]]; then
    return 0
  fi
  echo "Granting POST_NOTIFICATIONS on ${serial} (${app_id})..."
  adb -s "${serial}" shell pm grant "${app_id}" android.permission.POST_NOTIFICATIONS
}

# Install the QA debug APK. Uninstalls first so a prior `flutter run` on another
# ABI cannot leave stale native libs in app_lib/.
qa_install_qa_apk_on_serial() {
  local serial="$1"
  local apk="${2:-${COMPARTARENTA_QA_APK_PATH}}"

  if [[ "${serial}" != emulator-* && "${COMPARTARENTA_QA_ALLOW_USB_APK_INSTALL:-0}" != "1" ]]; then
    echo "Refusing to install QA APK on a non-emulator device (${serial})." >&2
    echo "Set COMPARTARENTA_QA_ALLOW_USB_APK_INSTALL=1 for explicit USB installs (FCM wake scenario)." >&2
    return 1
  fi
  if [[ ! -f "${apk}" ]]; then
    echo "APK not found: ${apk}" >&2
    echo "Build first: ./tool/melosw run qa:build-apk" >&2
    return 1
  fi

  qa_wait_for_boot_completed "${serial}"

  local lib_abi
  lib_abi="$(adb -s "${serial}" shell getprop ro.product.cpu.abi | tr -d '\r')"
  if [[ -z "${lib_abi}" ]]; then
    echo "Could not read ro.product.cpu.abi from ${serial}." >&2
    return 1
  fi
  if ! qa_apk_contains_libflutter_for_abi "${apk}" "${lib_abi}"; then
    echo "APK missing lib/${lib_abi}/libflutter.so required by ${serial}." >&2
    if [[ "${lib_abi}" == "x86_64" ]] \
      && qa_apk_contains_libflutter_for_abi "${apk}" arm64-v8a; then
      echo "The APK on disk is arm64-only (typical after FLUTTER_DEVICE=… ./tool/melosw run run:dev)." >&2
      echo "Emulators need the x86_64 QA build — do not use --skip-build until qa:build-apk has run." >&2
    fi
    echo "Rebuild: ./tool/melosw run qa:build-apk" >&2
    echo "(QA APK must include lib/${lib_abi}/libflutter.so — build uses android-arm64 + android-x64.)" >&2
    return 1
  fi

  echo "Uninstalling prior ${COMPARTARENTA_QA_APP_ID} on ${serial}..."
  adb -s "${serial}" uninstall "${COMPARTARENTA_QA_APP_ID}" >/dev/null 2>&1 || true

  echo "Installing ${apk} on ${serial} (ABI ${lib_abi})..."
  adb -s "${serial}" install -r "${apk}"
}

qa_require_emulator_target() {
  local serial
  serial="$(qa_adb_target_serial)" || {
    echo "No adb device in 'device' state. Start the QA emulator first." >&2
    return 1
  }
  if [[ "${serial}" != emulator-* ]]; then
    echo "Refusing to change the system clock on a non-emulator device (${serial})." >&2
    return 1
  fi
  echo "${serial}"
}

# Recover from "System UI keeps stopping" on the QA emulator (manual clock jumps and
# repeated pm clear + cold start can destabilize com.android.systemui).
# Last resort only — do not call routinely before Maestro (can hang launchApp).
qa_recover_system_ui() {
  local serial="${1:-}"
  if [[ -n "${serial}" && "${serial}" != emulator-* ]]; then
    return 0
  fi
  local adb_args=()
  if [[ -n "${serial}" ]]; then
    adb_args=(-s "${serial}")
  fi
  adb "${adb_args[@]}" root >/dev/null 2>&1 || true
  adb "${adb_args[@]}" shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true
  sleep 1
  adb "${adb_args[@]}" shell killall com.android.systemui >/dev/null 2>&1 || true
  qa_wait_for_boot_completed "${serial}"
  sleep 2
}

# Light prep after seed / before Maestro — no System UI restart.
qa_prepare_for_maestro() {
  local serial="${1:-}"
  local adb_args=()
  if [[ -n "${serial}" ]]; then
    adb_args=(-s "${serial}")
  fi
  adb "${adb_args[@]}" shell am force-stop "${COMPARTARENTA_QA_APP_ID}" >/dev/null 2>&1 || true
  adb "${adb_args[@]}" shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true
  sleep 1
}

# Fully stop an emulator process (adb emu kill). Used before a mid-scenario reseed
# when repeated pm clear leaves System UI / bootstrap unable to write seed_applied.
qa_kill_emulator() {
  local serial="${1:-}"
  if [[ -z "${serial}" ]]; then
    serial="$(adb devices | awk '/^emulator-[0-9]+\t/{print $1; exit}')"
  fi
  if [[ -z "${serial}" ]]; then
    echo "qa_kill_emulator: no emulator serial to kill" >&2
    return 0
  fi
  echo "Killing emulator ${serial} (full stop before reseed)..."
  adb -s "${serial}" emu kill >/dev/null 2>&1 || true
  local i
  for i in $(seq 1 90); do
    if ! adb devices 2>/dev/null | awk -v s="${serial}" '$1 == s { found=1 } END { exit !found }'; then
      # Brief settle so the next cold boot does not attach to a dying process.
      sleep 2
      echo "Emulator ${serial} stopped."
      return 0
    fi
    sleep 1
  done
  echo "qa_kill_emulator: timed out waiting for ${serial} to disappear" >&2
  return 1
}

# --- Multi-device QA helpers --------------------------------------------------

qa_write_avd_serials_map() {
  # Usage: qa_write_avd_serials_map "Louys-QA=emulator-5554" "Monica-QA=emulator-5556"
  qa_ensure_local_dir
  : >"${COMPARTARENTA_QA_AVD_SERIALS_MAP}"
  local entry avd serial
  for entry in "$@"; do
    avd="${entry%%=*}"
    serial="${entry#*=}"
    if [[ -z "${avd}" || -z "${serial}" || "${avd}" == "${serial}" ]]; then
      echo "Invalid AVD serial map entry: ${entry}" >&2
      return 1
    fi
    printf '%s=%s\n' "${avd}" "${serial}" >>"${COMPARTARENTA_QA_AVD_SERIALS_MAP}"
  done
}

qa_serial_from_avd_map() {
  local avd_name="$1"
  local line name serial
  if [[ ! -f "${COMPARTARENTA_QA_AVD_SERIALS_MAP}" ]]; then
    return 1
  fi
  while IFS='=' read -r name serial; do
    [[ -z "${name}" ]] && continue
    if [[ "${name}" == "${avd_name}" && -n "${serial}" ]]; then
      if adb devices | awk -v s="${serial}" '$1 == s && $2 == "device" { found=1 } END { exit !found }'; then
        echo "${serial}"
        return 0
      fi
    fi
  done <"${COMPARTARENTA_QA_AVD_SERIALS_MAP}"
  return 1
}

qa_serial_for_avd_by_fixed_port() {
  local avd_name="$1"
  local base_port=5554
  local i=0
  local name expected_serial
  for name in "${COMPARTARENTA_QA_PERSONA_AVD_NAMES[@]}"; do
    if [[ "${name}" == "${avd_name}" ]]; then
      expected_serial="emulator-$((base_port + i * 2))"
      if adb devices | awk -v s="${expected_serial}" '$1 == s && $2 == "device" { found=1 } END { exit !found }'; then
        echo "${expected_serial}"
        return 0
      fi
      return 1
    fi
    i=$((i + 1))
  done
  return 1
}

qa_serial_for_avd() {
  local avd_name="$1"
  local serial avd_on_device

  if serial="$(qa_serial_from_avd_map "${avd_name}")"; then
    echo "${serial}"
    return 0
  fi

  while IFS= read -r serial; do
    [[ -z "${serial}" ]] && continue
    avd_on_device="$(adb -s "${serial}" emu avd name 2>/dev/null | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
    if [[ -n "${avd_on_device}" && "${avd_on_device}" == "${avd_name}" ]]; then
      echo "${serial}"
      return 0
    fi
  done < <(adb devices | awk '/^emulator-[0-9]+\tdevice$/{print $1}')

  if serial="$(qa_serial_for_avd_by_fixed_port "${avd_name}")"; then
    echo "${serial}"
    return 0
  fi

  return 1
}

qa_pull_handshake_invitation_code() {
  local serial="$1"
  # Missing file must not abort callers (set -e + pipefail).
  adb -s "${serial}" shell \
    "run-as ${COMPARTARENTA_QA_APP_ID} cat app_flutter/compartarenta_qa_handshake_code.txt" \
    2>/dev/null | tr -d '\r' || true
}

# Pull sale-export zip written by debug QA after a successful UI export.
# Writes host path given as $2. Returns 0 only when the file is non-empty.
qa_pull_vehicle_sale_export_zip() {
  local serial="$1"
  local host_path="$2"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  mkdir -p "$(dirname "${host_path}")"
  if ! adb -s "${serial}" shell \
    "run-as ${app_id} cat app_flutter/compartarenta_qa_vehicle_sale_export.zip" \
    >"${host_path}" 2>/dev/null; then
    rm -f "${host_path}"
    return 1
  fi
  if [[ ! -s "${host_path}" ]]; then
    rm -f "${host_path}"
    return 1
  fi
  return 0
}

# Pull a file from the app data tree (path relative to run-as cwd, e.g.
# app_flutter/… or shared_prefs/…). Writes host path $3. Returns 0 only when
# the host file is non-empty. Uses base64 on-device for binary-safe transfer.
qa_pull_app_path() {
  local serial="$1"
  local device_rel_path="$2"
  local host_path="$3"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  local err
  err="$(mktemp)"
  mkdir -p "$(dirname "${host_path}")"
  if ! adb -s "${serial}" shell \
    "run-as ${app_id} sh -c 'base64 ${device_rel_path}'" \
    2>"${err}" | base64 -d >"${host_path}"; then
    echo "qa_pull_app_path: adb/base64 failed for ${device_rel_path}" >&2
    sed 's/^/  /' "${err}" >&2 || true
    rm -f "${host_path}" "${err}"
    return 1
  fi
  if [[ ! -s "${host_path}" ]]; then
    echo "qa_pull_app_path: empty after pull: ${device_rel_path}" >&2
    sed 's/^/  /' "${err}" >&2 || true
    rm -f "${host_path}" "${err}"
    return 1
  fi
  rm -f "${err}"
  return 0
}

# List non-empty files in an app-data directory (relative to run-as cwd).
# Prints one relative path per line (dir/file).
qa_list_app_dir_files() {
  local serial="$1"
  local device_rel_dir="$2"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  adb -s "${serial}" shell \
    "run-as ${app_id} sh -c 'cd ${device_rel_dir} 2>/dev/null && for f in *; do if [ -f \"\$f\" ]; then echo ${device_rel_dir}/\$f; fi; done'" \
    2>/dev/null | tr -d '\r' | sed '/^$/d' || true
}

# Resolve the live Drift DB path under app_flutter/compartarenta/.
# driftDatabase(name: 'compartarenta.sqlite') may create compartarenta.sqlite.sqlite.
qa_resolve_drift_sqlite_device_path() {
  local serial="$1"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  local candidate
  local listed
  listed="$(qa_list_app_dir_files "${serial}" "app_flutter/compartarenta")"
  for candidate in \
    "app_flutter/compartarenta/compartarenta.sqlite" \
    "app_flutter/compartarenta/compartarenta.sqlite.sqlite"
  do
    if echo "${listed}" | grep -Fxq "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done
  # Fallback: first *.sqlite that is not -wal/-shm.
  candidate="$(echo "${listed}" | grep -E '\.sqlite$' | grep -vE '\-(wal|shm)$' | head -1 || true)"
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi
  echo "qa_resolve_drift_sqlite_device_path: no sqlite under app_flutter/compartarenta on ${serial}" >&2
  if [[ -n "${listed}" ]]; then
    echo "  present:" >&2
    echo "${listed}" | sed 's/^/    /' >&2
  else
    adb -s "${serial}" shell \
      "run-as ${app_id} sh -c 'ls -la app_flutter/compartarenta 2>&1 || ls -la app_flutter 2>&1'" \
      >&2 || true
  fi
  return 1
}

# Push a host file into the app data tree via base64 (run-as cannot read
# arbitrary host push paths). device_rel_path is relative to run-as cwd.
qa_push_app_path() {
  local serial="$1"
  local host_path="$2"
  local device_rel_path="$3"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  local device_dir
  if [[ ! -s "${host_path}" ]]; then
    echo "qa_push_app_path: missing or empty ${host_path}" >&2
    return 1
  fi
  device_dir="$(dirname "${device_rel_path}")"
  if [[ "${device_dir}" != "." ]]; then
    adb -s "${serial}" shell \
      "run-as ${app_id} mkdir -p ${device_dir}" >/dev/null 2>&1 || true
  fi
  if ! base64 -w0 "${host_path}" | adb -s "${serial}" shell \
    "run-as ${app_id} sh -c 'base64 -d > ${device_rel_path}'"; then
    echo "qa_push_app_path: failed to write ${device_rel_path}" >&2
    return 1
  fi
  local size
  size="$(adb -s "${serial}" shell \
    "run-as ${app_id} sh -c 'wc -c < ${device_rel_path}'" \
    2>/dev/null | tr -d '\r' || true)"
  if [[ -z "${size}" || "${size}" -le 0 ]]; then
    echo "qa_push_app_path: empty on device: ${device_rel_path}" >&2
    return 1
  fi
  return 0
}

# True when a relative app-data path exists and is non-empty.
qa_app_path_exists() {
  local serial="$1"
  local device_rel_path="$2"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  local size
  size="$(adb -s "${serial}" shell \
    "run-as ${app_id} sh -c 'if [ -f ${device_rel_path} ]; then wc -c < ${device_rel_path}; else echo 0; fi'" \
    2>/dev/null | tr -d '\r' || true)"
  [[ -n "${size}" && "${size}" -gt 0 ]]
}

# Push a host zip into app_flutter for debug import (bypasses FilePicker).
qa_push_vehicle_sale_import_zip() {
  local serial="$1"
  local host_path="$2"
  qa_push_app_path "${serial}" "${host_path}" \
    "app_flutter/compartarenta_qa_vehicle_sale_import.zip"
}

qa_pull_qa_seed_applied_id() {
  local serial="$1"
  # Poll loop: seed_applied.txt does not exist until bootstrap finishes.
  adb -s "${serial}" shell \
    "run-as ${COMPARTARENTA_QA_APP_ID} cat app_flutter/compartarenta_qa_seed_applied.txt" \
    2>/dev/null | tr -d '\r' || true
}

qa_verify_routing_push_refresh_on_serial() {
  local serial="$1"
  adb -s "${serial}" shell \
    "run-as ${COMPARTARENTA_QA_APP_ID} cat shared_prefs/FlutterSharedPreferences.xml" \
    2>/dev/null \
    | grep -qE 'name="flutter\.routing_push\.last_refresh_ms"'
}

qa_verify_onboarding_complete_pref_on_serial() {
  local serial="$1"
  adb -s "${serial}" shell \
    "run-as ${COMPARTARENTA_QA_APP_ID} cat shared_prefs/FlutterSharedPreferences.xml" \
    2>/dev/null \
    | grep -qE 'name="flutter\.onboarding\.complete" value="true"'
}

qa_clear_logcat_on_serial() {
  local serial="$1"
  adb -s "${serial}" logcat -c >/dev/null 2>&1 || true
}

qa_logcat_matches_on_serial() {
  local serial="$1"
  local pattern="$2"
  adb -s "${serial}" logcat -d 2>/dev/null | grep -Fq "${pattern}"
}

qa_wait_for_logcat_on_serial() {
  local serial="$1"
  local pattern="$2"
  local timeout_sec="${3:-120}"
  local attempt
  for attempt in $(seq 1 "${timeout_sec}"); do
    if qa_logcat_matches_on_serial "${serial}" "${pattern}"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

qa_open_notification_shade_on_serial() {
  local serial="$1"
  adb -s "${serial}" shell cmd statusbar expand-notifications
}

qa_collapse_notification_shade_on_serial() {
  local serial="$1"
  adb -s "${serial}" shell cmd statusbar collapse >/dev/null 2>&1 || true
}

# Capture PNG via adb screencap; print md5 hex to stdout; write file to out_path.
qa_screencap_md5_on_serial() {
  local serial="$1"
  local out_path="$2"
  if [[ -z "${serial}" || -z "${out_path}" ]]; then
    echo "qa_screencap_md5_on_serial: serial and out_path required" >&2
    return 1
  fi
  mkdir -p "$(dirname "${out_path}")"
  if ! adb -s "${serial}" exec-out screencap -p >"${out_path}"; then
    echo "qa_screencap_md5_on_serial: screencap failed on ${serial}" >&2
    return 1
  fi
  if [[ ! -s "${out_path}" ]]; then
    echo "qa_screencap_md5_on_serial: empty screencap ${out_path}" >&2
    return 1
  fi
  md5sum "${out_path}" | awk '{print $1}'
}

# Write a one-shot post-action marker (no pm clear). Consumed on next cold start.
# Args: serial kind(before_due|overdue) due_ms_utc [plan_id]
qa_schedule_payment_reminder_post_action_on_serial() {
  local serial="$1"
  local kind="$2"
  local due_ms="$3"
  local plan_id="${4:-housing:qa-payment-reminder}"
  local app_id="${COMPARTARENTA_QA_APP_ID}"
  if [[ -z "${kind}" || -z "${due_ms}" ]]; then
    echo "qa_schedule_payment_reminder_post_action_on_serial: kind and due_ms required" >&2
    return 1
  fi
  adb -s "${serial}" shell "run-as ${app_id} mkdir app_flutter" >/dev/null 2>&1 || true
  if ! adb -s "${serial}" shell "run-as ${app_id} sh -c 'printf \"%s\\n%s\\n%s\\n\" \"${kind}\" \"${due_ms}\" \"${plan_id}\" > app_flutter/compartarenta_qa_post_action'"; then
    echo "Failed to write post-action marker on ${serial}" >&2
    return 1
  fi
}

qa_maestro_test_on_serial() {
  local serial="$1"
  local flow_path="$2"
  local artifact_dir="$3"
  shift 3
  local log attempt rc
  local timeout_sec="${COMPARTARENTA_QA_MAESTRO_TIMEOUT_SEC:-600}"
  mkdir -p "${artifact_dir}"
  for attempt in 1 2; do
    log="$(mktemp)"
    set +e
    timeout "${timeout_sec}" maestro test --udid "${serial}" "${flow_path}" \
      --test-output-dir "${artifact_dir}" "$@" >"${log}" 2>&1
    rc=$?
    # Do not `set -e` here — shell options leak to callers; a later `return 1`
    # (e.g. duplicate probe clean path) would abort the coordinator with exit 1.
    cat "${log}"
    if [[ "${rc}" -eq 0 ]]; then
      rm -f "${log}"
      return 0
    fi
    if [[ "${attempt}" -eq 1 ]] && grep -qE 'UNAVAILABLE|Command failed \(tcp|device offline|not connected' "${log}"; then
      echo "  maestro infra flake on ${serial}; adb reconnect + retry once" >&2
      adb -s "${serial}" reconnect >/dev/null 2>&1 || true
      sleep 2
      rm -f "${log}"
      continue
    fi
    rm -f "${log}"
    return "${rc}"
  done
  return 1
}

# Maestro --test-output-dir: avoid doubling COMPARTARENTA_MULTI_ARTIFACT_ROOT when the
# label is already an absolute path under that root (e.g. attempt-002/... passed as
# ${ARTIFACT_ROOT}/attempt-002/...).
qa_maestro_artifact_dir() {
  local label="$1"
  local root="${COMPARTARENTA_MULTI_ARTIFACT_ROOT:-}"
  if [[ -z "${root}" ]]; then
    echo "${label}"
    return 0
  fi
  if [[ "${label}" == "${root}/"* || "${label}" == "${root}" ]]; then
    echo "${label}"
  elif [[ "${label}" == /* ]]; then
    echo "${label}"
  else
    echo "${root}/${label}"
  fi
}

qa_seed_scenario_on_serial() {
  local serial="$1"
  local scenario_id="$2"
  ANDROID_SERIAL="${serial}" "${COMPARTARENTA_ROOT}/tool/seed_qa_scenario.sh" "${scenario_id}"
}

qa_resolve_device_date() {
  # "current" = host wall clock *now* in the scenario timezone (date + time),
  # not "today at 09:00".
  local device_date="$1"
  local timezone="$2"
  if [[ "${device_date}" == "current" ]]; then
    TZ="${timezone}" date '+%Y-%m-%dT%H:%M:%S'
  else
    printf '%s' "${device_date}"
  fi
}

qa_set_android_date_on_serial() {
  local serial="$1"
  local device_date="$2"
  local timezone="$3"
  ANDROID_SERIAL="${serial}" "${COMPARTARENTA_ROOT}/tool/set_android_date.sh" "${device_date}" "${timezone}"
}

qa_avd_port_for_name() {
  local avd_name="$1"
  local base_port=5554
  local i=0
  local name
  for name in "${COMPARTARENTA_QA_PERSONA_AVD_NAMES[@]}"; do
    if [[ "${name}" == "${avd_name}" ]]; then
      echo $((base_port + i * 2))
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

qa_ensure_named_avd_running() {
  local avd_name="$1"
  local serial port
  if serial="$(qa_serial_for_avd "${avd_name}")"; then
    qa_wait_for_boot_completed "${serial}"
    echo "${serial}"
    return 0
  fi
  port="$(qa_avd_port_for_name "${avd_name}")" || {
    echo "Unknown QA persona AVD: ${avd_name}" >&2
    return 1
  }
  if ! avdmanager list avd | grep -Fq "Name: ${avd_name}"; then
    COMPARTARENTA_QA_AVD_NAME="${avd_name}" "${COMPARTARENTA_ROOT}/tool/create_qa_avd.sh"
  fi
  serial="emulator-${port}"
  echo "Starting ${avd_name} -> ${serial}..." >&2
  nohup emulator -avd "${avd_name}" -port "${port}" \
    -netdelay none -netspeed full -prop ro.setupwizard.mode=DISABLED >/dev/null 2>&1 &
  qa_wait_for_boot_completed "${serial}"
  echo "${serial}"
}

qa_require_usb_serial() {
  local serial="$1"
  if [[ "${serial}" == emulator-* ]]; then
    echo "Expected a physical adb serial, got emulator: ${serial}" >&2
    return 1
  fi
  if ! adb devices | awk -v s="${serial}" '$1 == s && $2 == "device" { found=1 } END { exit !found }'; then
    echo "Physical device ${serial} not in 'device' state. Run: adb devices" >&2
    return 1
  fi
}

qa_require_app_installed_on_serial() {
  local serial="$1"
  local app_id="${2:-${COMPARTARENTA_QA_APP_ID}}"
  if ! adb -s "${serial}" shell pm path "${app_id}" 2>/dev/null | grep -q .; then
    echo "App ${app_id} not installed on ${serial}." >&2
    echo "Install dev debug first, e.g. FLUTTER_DEVICE=${serial} ./tool/melosw run run:dev" >&2
    return 1
  fi
}
