#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"

cd "${DIR}"

# shellcheck source=../../tool/ensure_pub_get.sh
source "${ROOT}/tool/ensure_pub_get.sh"
ensure_workspace_pub_get "${ROOT}"

# Extra args (e.g. -d linux) come from the command line, or from FLUTTER_DEVICE when unset.
# Example: dart run melos run run:dev -- -d chrome
# Example: FLUTTER_DEVICE=linux dart run melos run run:dev
# Android screenshots without the Simulation ribbon:
#   ./tool/melosw run run:dev -- -d <deviceId> --screenshot
# Reuse an existing QA APK (e.g. after qa:build-apk -- --simulation):
#   ./tool/melosw run run:dev -- --skip-build
# Wipe app data while reusing that APK:
#   ./tool/melosw run run:dev -- --skip-build --fresh
# Vehicle-sharing local seed (flush DB + Simulation catalog contacts + QA Civic):
#   ./tool/melosw run run:dev -- --cardev
screenshot_mode=false
skip_build=false
fresh_install=false
cardev_seed=false
extra=()
for arg in "$@"; do
  if [[ "${arg}" == "--screenshot" ]]; then
    screenshot_mode=true
  elif [[ "${arg}" == "--skip-build" ]]; then
    skip_build=true
  elif [[ "${arg}" == "--fresh" ]]; then
    fresh_install=true
  elif [[ "${arg}" == "--cardev" ]]; then
    cardev_seed=true
  else
    extra+=("${arg}")
  fi
done
if [[ ${#extra[@]} -eq 0 && -n "${FLUTTER_DEVICE:-}" ]]; then
  extra=(-d "${FLUTTER_DEVICE}")
fi

# Default relay base URL for the dev flavor points at the real relay so
# the handshake plumbing is enabled out of the box. Override via env
# (preferred) or by appending --dart-define=API_BASE_URL=... yourself.
API_BASE_URL_VALUE="${API_BASE_URL:-https://sync.incoherences.org}"
# shellcheck source=entitlement_base_url_default.sh
source "${DIR}/tool/entitlement_base_url_default.sh"
ENTITLEMENT_BASE_URL_VALUE="$(entitlement_base_url_default "${API_BASE_URL_VALUE}")"

should_filter_android_logs=true
install_mobile_target=true
for ((i = 0; i < ${#extra[@]}; i++)); do
  if [[ "${extra[i]}" == "-d" && $((i + 1)) -lt ${#extra[@]} ]]; then
    case "${extra[i + 1]}" in
      chrome|web-server|linux|windows|macos)
        should_filter_android_logs=false
        install_mobile_target=false
        ;;
    esac
  fi
done
if [[ "${screenshot_mode}" == "true" && "${install_mobile_target}" != "true" ]]; then
  echo "--screenshot is available only for the Android dev APK." >&2
  exit 2
fi
if [[ "${skip_build}" == "true" && "${install_mobile_target}" != "true" ]]; then
  echo "--skip-build is available only for the Android dev APK." >&2
  exit 2
fi
if [[ "${fresh_install}" == "true" && "${skip_build}" != "true" ]]; then
  echo "--fresh requires --skip-build (normal run:dev already uninstalls first)." >&2
  exit 2
fi
if [[ "${cardev_seed}" == "true" && "${skip_build}" == "true" ]]; then
  echo "--cardev needs a rebuild (CARDEV dart-define). Do not combine with --skip-build." >&2
  exit 2
fi

QA_APK="${DIR}/build/app/outputs/flutter-apk/app-dev-debug.apk"

if [[ "${skip_build}" == "true" ]]; then
  if [[ ! -f "${QA_APK}" ]]; then
    echo "APK not found: ${QA_APK}" >&2
    echo "Build first: ./tool/melosw run qa:build-apk" >&2
    echo "  (or ./tool/melosw run qa:build-apk -- --simulation)" >&2
    exit 1
  fi
  echo "Skipping build; using existing APK: ${QA_APK}"
  # Prebuilt binary already embeds dart-defines (ENV, API_BASE_URL, SIMULATION, …).
  # Default: preserve app data (like adb install -r). --fresh → --uninstall-first.
  run_args=(
    run
    --no-pub
    --flavor dev
    --use-application-binary="${QA_APK}"
  )
  if [[ "${fresh_install}" == "true" ]]; then
    echo "Fresh install: uninstalling existing app data first."
    run_args+=(--uninstall-first)
  fi
else
  run_args=(
    run
    --no-pub
    --flavor dev
    --dart-define=ENV=dev
    --dart-define="API_BASE_URL=${API_BASE_URL_VALUE}"
  )
  if [[ "${screenshot_mode}" == "true" ]]; then
    run_args+=(--dart-define=SCREENSHOT=true)
  fi
  if [[ "${cardev_seed}" == "true" ]]; then
    echo "Cardev seed: flush DB + Simulation contacts + QA Civic on startup."
    run_args+=(--dart-define=CARDEV=true)
  fi
  if [[ -n "${ENTITLEMENT_BASE_URL_VALUE}" ]]; then
    run_args+=(--dart-define="ENTITLEMENT_BASE_URL=${ENTITLEMENT_BASE_URL_VALUE}")
  fi
  # Reinstall native plugins (shared_preferences, path_provider) after plugin or Gradle changes.
  if [[ "${install_mobile_target}" == "true" ]]; then
    run_args+=(--uninstall-first)
  fi
fi
run_args+=("${extra[@]}")

if [[ "${COMPARTARENTA_RUN_RAW_LOGS:-0}" == "1" || "${should_filter_android_logs}" != "true" ]]; then
  ./tool/flutterw "${run_args[@]}"
else
  printf -v quoted_run_cmd '%q ' ./tool/flutterw "${run_args[@]}"
  raw_output_file="$(mktemp)"
  cleanup() {
    rm -f "${raw_output_file}"
  }
  trap cleanup EXIT

  script -qefc "${quoted_run_cmd}" /dev/null >"${raw_output_file}" 2>&1 &
  runner_pid=$!

  tail -n +1 -F --pid="${runner_pid}" "${raw_output_file}" \
    | bash ./tool/filter_flutter_run_output.sh
  wait "${runner_pid}"
fi
