#!/usr/bin/env bash
# Build a debug APK (dev flavor) for manual QA on the emulator.
#
# Usage: ./tool/build_qa_apk.sh [--simulation]
#
#   --simulation  Compile with SIMULATION=true: start already in sandbox,
#                 Simulation ribbon visible but exit disabled (closed-test builds).
#
# Output: mobile/build/app/outputs/flutter-apk/app-dev-debug.apk

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="${ROOT}/mobile"

simulation_locked=false
for arg in "$@"; do
  case "${arg}" in
    --simulation) simulation_locked=true ;;
    -h|--help)
      echo "Usage: $0 [--simulation]" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      echo "Usage: $0 [--simulation]" >&2
      exit 2
      ;;
  esac
done

# shellcheck source=qa_env.sh
source "${ROOT}/tool/qa_env.sh"
# shellcheck source=ensure_pub_get.sh
source "${ROOT}/tool/ensure_pub_get.sh"

ensure_workspace_pub_get "${ROOT}"

API_BASE_URL_VALUE="${API_BASE_URL:-${COMPARTARENTA_QA_API_BASE_URL}}"
# shellcheck source=../mobile/tool/entitlement_base_url_default.sh
source "${MOBILE}/tool/entitlement_base_url_default.sh"
ENTITLEMENT_BASE_URL_VALUE="$(entitlement_base_url_default "${API_BASE_URL_VALUE}")"

cd "${MOBILE}"
VERSION_FLAGS="$("./tool/compute_version.sh")"

echo "Building dev debug APK (API_BASE_URL=${API_BASE_URL_VALUE})"
if [[ "${simulation_locked}" == "true" ]]; then
  echo "Simulation locked-in: SIMULATION=true (enter on install, exit disabled)."
fi
echo "Target: android-arm64 + android-x64 (physical phones + x86_64 QA emulators)."

# Keep sqlite3 native-asset path Android-only (single source; no src/main/jniLibs).
qa_ensure_android_jni_sqlite3 "${MOBILE}"

build_args=(
  build apk --debug --flavor dev
  --dart-define=ENV=dev
  --dart-define="API_BASE_URL=${API_BASE_URL_VALUE}"
  --dart-define="ENTITLEMENT_BASE_URL=${ENTITLEMENT_BASE_URL_VALUE}"
  --target-platform android-arm64,android-x64
)
if [[ "${simulation_locked}" == "true" ]]; then
  build_args+=(--dart-define=SIMULATION=true)
fi
# shellcheck disable=SC2086
./tool/flutterw "${build_args[@]}" ${VERSION_FLAGS}

APK="${MOBILE}/build/app/outputs/flutter-apk/app-dev-debug.apk"
if [[ ! -f "${APK}" ]]; then
  echo "Expected APK missing: ${APK}" >&2
  exit 1
fi

if ! qa_apk_contains_libflutter_for_abi "${APK}" x86_64; then
  echo "ERROR: ${APK} is missing lib/x86_64/libflutter.so after build." >&2
  exit 1
fi
if ! qa_apk_contains_libflutter_for_abi "${APK}" arm64-v8a; then
  echo "ERROR: ${APK} is missing lib/arm64-v8a/libflutter.so after build." >&2
  exit 1
fi
if ! qa_apk_assert_android_libsqlite3 "${APK}"; then
  exit 1
fi

ls -lah "${APK}"
echo "QA APK ready: ${APK}"
