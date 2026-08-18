#!/usr/bin/env bash
# Single-emulator coordinator — housing payment reminders #10/#11 (simulated, no relay).
#
# Seed once → phase per fire (J−4, J−2, due day J, overdue). Journal rows persist.
#
# After OS shade tap: probe qa-housing-monthly-expenses-screen; if missing, compare
# post-tap screencap MD5 to shade-closed baseline (after KEYCODE_HOME). Shade still
# open (MD5 differs) → FAIL. Shade closed → open app and navigate to journal by id.
#
# Probe Maestro wall budget is 90s (not 25s): this run's artifacts showed ~19s
# between probe folder create (22:24:03) and the first YAML command (22:24:22)
# — device attach, not report I/O — then 1s for the visible assert. YAML wait
# stays 8s. 25s wall left almost no margin after attach (and a miss needs
# attach + 8s wait).
#
# Expects env from tool/run_housing_payment_reminder_scenario.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../qa_env.sh
source "${ROOT}/tool/qa_env.sh"

SERIAL="${COMPARTARENTA_PAYMENT_REMINDER_SERIAL:?missing emulator serial}"
ARTIFACT_ROOT="${COMPARTARENTA_MULTI_ARTIFACT_ROOT:?missing artifact root}"
TIMEZONE="${COMPARTARENTA_MULTI_TIMEZONE:-America/Toronto}"
ANCHOR_DATE="${COMPARTARENTA_PAYMENT_REMINDER_ANCHOR_DATE:?missing anchor date}"
DUE_MS="${COMPARTARENTA_PAYMENT_REMINDER_DUE_MS:?missing due ms}"
FIRE_J4="${COMPARTARENTA_PAYMENT_REMINDER_FIRE_J4:?missing J-4 fire}"
FIRE_J2="${COMPARTARENTA_PAYMENT_REMINDER_FIRE_J2:?missing J-2 fire}"
FIRE_DUE_DAY="${COMPARTARENTA_PAYMENT_REMINDER_FIRE_DUE_DAY:?missing due-day fire}"
FIRE_OVERDUE="${COMPARTARENTA_PAYMENT_REMINDER_FIRE_OVERDUE:?missing overdue fire}"
FLOW_LAUNCH="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_LAUNCH:?missing launch flow}"
FLOW_TAP_J4="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_TAP_J4:?missing J-4 tap flow}"
FLOW_TAP_J2="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_TAP_J2:?missing J-2 tap flow}"
FLOW_TAP_DUE_DAY="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_TAP_DUE_DAY:?missing due-day tap flow}"
FLOW_TAP_OVERDUE="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_TAP_OVERDUE:?missing overdue tap flow}"
FLOW_PROBE="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_PROBE:?missing probe flow}"
FLOW_OPEN_JOURNAL="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_OPEN_JOURNAL:?missing open-journal flow}"
FLOW_ASSERT_J4="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_ASSERT_J4:?missing J-4 assert flow}"
FLOW_ASSERT_J2="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_ASSERT_J2:?missing J-2 assert flow}"
FLOW_ASSERT_DUE_DAY="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_ASSERT_DUE_DAY:?missing due-day assert flow}"
FLOW_ASSERT_OVERDUE="${COMPARTARENTA_PAYMENT_REMINDER_FLOW_ASSERT_OVERDUE:?missing overdue assert flow}"

MAESTRO_TIMEOUT="${COMPARTARENTA_QA_MAESTRO_TIMEOUT_SEC:-600}"

_run_maestro() {
  local label="$1"
  local flow="$2"
  local out
  out="$(qa_maestro_artifact_dir "${label}")"
  mkdir -p "${out}"
  echo "  maestro device=${SERIAL} flow=$(basename "${flow}") -> ${out}"
  if ! timeout "${MAESTRO_TIMEOUT}" maestro test --udid "${SERIAL}" "${flow}" --test-output-dir "${out}"; then
    echo "  maestro FAILED: ${label} ($(basename "${flow}"))" >&2
    return 1
  fi
}

# Probe: journal title visible. Wall budget covers Maestro device-attach (~20s
# observed on Maestro 2.6.1 in this catalog run) plus the YAML 8s wait.
_PROBE_MAESTRO_TIMEOUT_SEC="${COMPARTARENTA_QA_PAYMENT_REMINDER_PROBE_TIMEOUT_SEC:-90}"

_probe_monthly_expenses_visible() {
  local label="$1"
  local out rc=0
  out="$(qa_maestro_artifact_dir "${label}")"
  mkdir -p "${out}"
  echo "  probe journal title qa-housing-monthly-expenses-screen -> ${out}"
  timeout "${_PROBE_MAESTRO_TIMEOUT_SEC}" maestro test --udid "${SERIAL}" \
    "${FLOW_PROBE}" --test-output-dir "${out}" || rc=$?
  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi
  echo "  probe maestro/timeout exit=${rc} (124=GNU timeout killed the process)" >&2
  return 1
}

_log_phase() {
  echo "==="
  echo "=== $1"
  echo "==="
}

_run_notification_phase() {
  local phase_label="$1"
  local kind="$2"
  local fire_iso="$3"
  local logcat_needle="$4"
  local tap_flow="$5"
  local assert_flow="$6"

  local phase_dir md5_closed md5_after shot_closed shot_after

  _log_phase "${phase_label}"
  echo "  Emulator date -> ${fire_iso}; schedule ${kind} (due_ms=${DUE_MS}); no pm clear."
  qa_set_android_date_on_serial "${SERIAL}" "${fire_iso}" "${TIMEZONE}"
  qa_schedule_payment_reminder_post_action_on_serial "${SERIAL}" "${kind}" "${DUE_MS}"
  qa_clear_logcat_on_serial "${SERIAL}"
  qa_prepare_for_maestro "${SERIAL}"
  _run_maestro "${phase_label}-launch" "${FLOW_LAUNCH}" || return 1

  if ! qa_wait_for_logcat_on_serial "${SERIAL}" "${logcat_needle}" 30; then
    echo "  FAILED: simulated delivery logcat missing (${logcat_needle})." >&2
    adb -s "${SERIAL}" logcat -d 2>/dev/null | grep -E 'housingPaymentReminder' | tail -20 >&2 || true
    return 1
  fi

  # Do NOT force-stop: that cancels the app's local notifications (shade empty).
  # Background with HOME so the shade tap resumes the app via the notification
  # response path instead of a no-op foreground Maestro tap.
  echo "  KEYCODE_HOME (keep notification; background app)..."
  adb -s "${SERIAL}" shell input keyevent KEYCODE_HOME >/dev/null 2>&1 || true
  sleep 1

  phase_dir="$(qa_maestro_artifact_dir "${phase_label}-post-tap")"
  mkdir -p "${phase_dir}"
  shot_closed="${phase_dir}/shade_closed_baseline.png"
  echo "  Screenshot shade-closed baseline -> ${shot_closed}"
  md5_closed="$(qa_screencap_md5_on_serial "${SERIAL}" "${shot_closed}")"
  echo "  shade-closed md5=${md5_closed}"

  echo "  Opening notification shade (adb expand-notifications)..."
  qa_open_notification_shade_on_serial "${SERIAL}"
  sleep 1
  _run_maestro "${phase_label}-tap" "${tap_flow}" || return 1

  shot_after="${phase_dir}/after_notification_tap.png"
  echo "  Screenshot after notification tap -> ${shot_after}"
  md5_after="$(qa_screencap_md5_on_serial "${SERIAL}" "${shot_after}")"
  echo "  after-tap md5=${md5_after}"

  if _probe_monthly_expenses_visible "${phase_label}-probe-journal"; then
    echo "  Journal title qa-* visible — continue asserts."
  elif [[ "${md5_after}" == "${md5_closed}" ]]; then
    echo "  No journal qa-*; shade closed (md5 match) — open app and navigate to journal."
    qa_collapse_notification_shade_on_serial "${SERIAL}"
    _run_maestro "${phase_label}-open-journal" "${FLOW_OPEN_JOURNAL}" || return 1
  else
    echo "  FAILED: no journal title qa-* and shade not closed (md5=${md5_after} != closed ${md5_closed})." >&2
    qa_collapse_notification_shade_on_serial "${SERIAL}"
    return 1
  fi

  _run_maestro "${phase_label}-assert" "${assert_flow}" || return 1
  qa_collapse_notification_shade_on_serial "${SERIAL}"
}

echo "================================================================================"
echo "Housing payment reminder QA (#10×3 + #11 overdue, simulated) — serial ${SERIAL}"
echo "  Anchor (calendar): ${ANCHOR_DATE}"
echo "  Due ms (UTC):      ${DUE_MS}"
echo "  Fires: J-4=${FIRE_J4} | J-2=${FIRE_J2} | due-day=${FIRE_DUE_DAY} | overdue=${FIRE_OVERDUE}"
echo "  No relay — client display only; journal persists across phases."
echo "================================================================================"

_log_phase "Seed once (active plan)"
qa_set_android_date_on_serial "${SERIAL}" "${FIRE_J4}" "${TIMEZONE}"
COMPARTARENTA_QA_GRANT_POST_NOTIFICATIONS=1 \
  qa_seed_scenario_on_serial "${SERIAL}" "housing_payment_reminder_simulate_before_due"

_run_notification_phase \
  "phase1-j4-before-due" \
  "before_due" \
  "${FIRE_J4}" \
  "housingPaymentReminder: simulated kind=before_due qa=#10" \
  "${FLOW_TAP_J4}" \
  "${FLOW_ASSERT_J4}"

_run_notification_phase \
  "phase2-j2-before-due" \
  "before_due" \
  "${FIRE_J2}" \
  "housingPaymentReminder: simulated kind=before_due qa=#10" \
  "${FLOW_TAP_J2}" \
  "${FLOW_ASSERT_J2}"

_run_notification_phase \
  "phase3-due-day" \
  "before_due" \
  "${FIRE_DUE_DAY}" \
  "housingPaymentReminder: simulated kind=before_due qa=#10" \
  "${FLOW_TAP_DUE_DAY}" \
  "${FLOW_ASSERT_DUE_DAY}"

_run_notification_phase \
  "phase4-overdue" \
  "overdue" \
  "${FIRE_OVERDUE}" \
  "housingPaymentReminder: simulated kind=overdue qa=#11" \
  "${FLOW_TAP_OVERDUE}" \
  "${FLOW_ASSERT_OVERDUE}"

echo "All payment-reminder phases completed."
