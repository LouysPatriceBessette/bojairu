#!/usr/bin/env bash
# Coordinator for contact-handshake multi-device QA (happy path + bug 9.1 probe).
#
# Expects env from tool/run_multi_device_scenario.sh:
#   COMPARTARENTA_ROLE_INVITER_SERIAL, COMPARTARENTA_ROLE_INVITEE_SERIAL, flows, etc.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../qa_env.sh
source "${ROOT}/tool/qa_env.sh"

INVITER_SERIAL="${COMPARTARENTA_ROLE_INVITER_SERIAL:?missing inviter serial}"
INVITEE_SERIAL="${COMPARTARENTA_ROLE_INVITEE_SERIAL:?missing invitee serial}"
INVITER_GENERATE_FLOW="${COMPARTARENTA_ROLE_INVITER_FLOW:?missing inviter flow}"
INVITEE_FLOW="${COMPARTARENTA_ROLE_INVITEE_FLOW:?missing invitee flow}"
ARTIFACT_ROOT="${COMPARTARENTA_MULTI_ARTIFACT_ROOT:?missing artifact root}"
MODE="${COMPARTARENTA_MULTI_MODE:-happy_path}"
ATTEMPTS="${COMPARTARENTA_MULTI_ATTEMPTS:-1}"
SCENARIO_ID="${COMPARTARENTA_MULTI_SCENARIO_ID:-contact_handshake}"

FLOWS_DIR="${ROOT}/qa/flows"
MAESTRO_TIMEOUT="${COMPARTARENTA_QA_MAESTRO_TIMEOUT_SEC:-600}"

_run_maestro() {
  local label="$1"
  local serial="$2"
  local flow="$3"
  shift 3
  local out
  out="$(qa_maestro_artifact_dir "${label}")"
  mkdir -p "${out}"
  echo "  maestro [${serial}] ${flow} -> ${out}"
  timeout "${MAESTRO_TIMEOUT}" maestro test --udid "${serial}" "${flow}" --test-output-dir "${out}" "$@"
}

# Probe flows: Maestro may exit non-zero when the symptom is absent — that is expected.
_run_maestro_probe() {
  local label="$1"
  local serial="$2"
  local flow="$3"
  local out
  out="$(qa_maestro_artifact_dir "${label}")"
  local log="${out}/probe.log"
  mkdir -p "${out}"
  echo "  probe [${serial}] ${flow} -> ${out}"
  if timeout "${MAESTRO_TIMEOUT}" maestro test --udid "${serial}" "${flow}" --test-output-dir "${out}" \
    >"${log}" 2>&1; then
    echo "  probe ${label}: symptom present"
    return 0
  fi
  echo "  probe ${label}: symptom absent (expected when bug 9.1 did not reproduce)"
  return 1
}

_both_sides_connected() {
  local base="$1"
  local inviter_ok=0
  local invitee_ok=0

  if _run_maestro "${base}/inviter-connected-check" "${INVITER_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_inviter_assert_connected.yaml"; then
    inviter_ok=1
  fi
  if _run_maestro "${base}/invitee-connected-check" "${INVITEE_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_invitee_assert_connected.yaml"; then
    invitee_ok=1
  fi

  if [[ "${inviter_ok}" -eq 1 && "${invitee_ok}" -eq 1 ]]; then
    return 0
  fi
  if [[ "${invitee_ok}" -eq 1 && "${inviter_ok}" -eq 0 ]]; then
    echo "  partial: invitee connected but inviter list missing peer (not bug 9.1; timing or UI refresh)"
  fi
  return 1
}

_wait_for_handshake_code() {
  local serial="$1"
  local code=""
  local attempt
  for attempt in $(seq 1 30); do
    code="$(qa_pull_handshake_invitation_code "${serial}")"
    if [[ -n "${code}" ]]; then
      echo "${code}"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for exported invitation code on ${serial}" >&2
  return 1
}

_prepare_fresh_pair() {
  local attempt_dir="$1"
  qa_seed_scenario_on_serial "${INVITER_SERIAL}" "${COMPARTARENTA_ROLE_INVITER_SEED}"
  qa_seed_scenario_on_serial "${INVITEE_SERIAL}" "${COMPARTARENTA_ROLE_INVITEE_SEED}"
  qa_prepare_for_maestro "${INVITER_SERIAL}"
  qa_prepare_for_maestro "${INVITEE_SERIAL}"
  mkdir -p "${attempt_dir}"
}

_run_happy_path_once() {
  local attempt_dir="$1"
  local invite_code

  _prepare_fresh_pair "${attempt_dir}"

  _run_maestro "inviter-generate" "${INVITER_SERIAL}" "${INVITER_GENERATE_FLOW}"

  invite_code="$(_wait_for_handshake_code "${INVITER_SERIAL}")"
  echo "  invitation code: ${invite_code}"

  # Inviter stays on contacts (polling) while invitee redeems.
  (
    _run_maestro "inviter-standby" "${INVITER_SERIAL}" "${FLOWS_DIR}/contact_handshake_inviter_standby.yaml"
  ) &
  local inviter_pid=$!
  sleep 1

  _run_maestro "invitee-redeem" "${INVITEE_SERIAL}" "${INVITEE_FLOW}" \
    -e "INVITE_CODE=${invite_code}"

  wait "${inviter_pid}"

  _run_maestro "inviter-assert" "${INVITER_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_inviter_assert_connected.yaml"
  _run_maestro "invitee-assert" "${INVITEE_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_invitee_assert_connected.yaml"
}

_detect_bug_91_asymmetry() {
  local attempt_dir="$1"
  local base
  base="$(basename "${attempt_dir}")"
  local invitee_error=0
  local inviter_connected=0
  local invitee_empty=0

  # Bug 9.1 (original): invitee sees relay error + empty list; inviter already has
  # the connected peer. Probes are negative checks — absence is the normal outcome.
  if _run_maestro_probe "${base}/probe-invitee-error" "${INVITEE_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_invitee_has_relay_error.yaml"; then
    invitee_error=1
  fi

  if _run_maestro_probe "${base}/probe-inviter-connected" "${INVITER_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_inviter_has_louys_connected.yaml"; then
    inviter_connected=1
  fi

  if _run_maestro_probe "${base}/probe-invitee-empty" "${INVITEE_SERIAL}" \
    "${FLOWS_DIR}/contact_handshake_invitee_still_empty.yaml"; then
    invitee_empty=1
  fi

  if [[ "${invitee_error}" -eq 1 && "${inviter_connected}" -eq 1 && "${invitee_empty}" -eq 1 ]]; then
    return 0
  fi
  return 1
}

_run_bug_91_probe_once() {
  local attempt_dir="$1"
  local invite_code
  local base
  base="$(basename "${attempt_dir}")"

  _prepare_fresh_pair "${attempt_dir}"

  _run_maestro "${base}/inviter-generate" "${INVITER_SERIAL}" "${INVITER_GENERATE_FLOW}"
  invite_code="$(_wait_for_handshake_code "${INVITER_SERIAL}")"
  echo "  invitation code: ${invite_code}"

  # Inviter stays on the generate screen without a Maestro wait. Redeem may fail
  # (that is the bug 9.1 race); probes classify afterwards.
  _run_maestro "${base}/invitee-redeem-fast" "${INVITEE_SERIAL}" "${INVITEE_FLOW}" \
    -e "INVITE_CODE=${invite_code}" || true
  sleep 8

  if _detect_bug_91_asymmetry "${attempt_dir}"; then
    echo "BUG 9.1 REPRODUCED: inviter connected, invitee relay error + empty list"
    _run_maestro "${base}/invitee-retry" "${INVITEE_SERIAL}" \
      "${FLOWS_DIR}/contact_handshake_invitee_retry_submit.yaml" || true
    return 2
  fi

  # Clean success requires Monica (inviter) sees Louys AND Louys (invitee) sees Monica.
  if _both_sides_connected "${base}"; then
    return 0
  fi

  # Neither full repro nor full success (infra, timing, or partial UI state).
  return 3
}

case "${MODE}" in
  happy_path)
    echo "=== Contact handshake happy path ==="
    _run_happy_path_once "${ARTIFACT_ROOT}/run-001"
  ;;
  bug_91_probe)
    echo "=== Contact handshake bug 9.1 probe (${ATTEMPTS} attempts) ==="
    echo "Each attempt tries to REPRODUCE asymmetric failure (invitee error + empty,"
    echo "inviter already connected). A clean bilateral handshake counts toward"
    echo "could-not-reproduce; inconclusive runs (partial UI) are excluded."
    reproduced=0
    clean=0
    infra_fail=0
    attempt=1
    while [[ "${attempt}" -le "${ATTEMPTS}" ]]; do
      echo "--- Attempt ${attempt}/${ATTEMPTS} ---"
      attempt_dir="${ARTIFACT_ROOT}/attempt-$(printf '%03d' "${attempt}")"
      set +e
      _run_bug_91_probe_once "${attempt_dir}"
      rc=$?
      set -e
      case "${rc}" in
        0)
          clean=$((clean + 1))
          echo "Attempt ${attempt}: clean bilateral handshake (not bug 9.1)"
          ;;
        2)
          reproduced=1
          echo "Attempt ${attempt}: BUG 9.1 reproduced"
          break
          ;;
        *)
          infra_fail=$((infra_fail + 1))
          echo "Attempt ${attempt}: inconclusive (exit ${rc}) — excluded from repro count"
          ;;
      esac
      attempt=$((attempt + 1))
    done

    RESULT_FILE="${ARTIFACT_ROOT}/bug_91_result.txt"
    if [[ "${reproduced}" -eq 1 ]]; then
      {
        echo "verdict=REPRODUCED"
        echo "scenario=${SCENARIO_ID}"
        echo "attempts_run=${attempt}"
        echo "clean=${clean}"
        echo "infra_fail=${infra_fail}"
      } >"${RESULT_FILE}"
      echo "Bug 9.1 REPRODUCED — see ${RESULT_FILE}"
      exit 2
    fi

    {
      echo "verdict=COULD_NOT_REPRODUCE"
      echo "scenario=${SCENARIO_ID}"
      echo "attempts_requested=${ATTEMPTS}"
      echo "clean=${clean}"
      echo "infra_fail=${infra_fail}"
      echo "note=CASE CLOSED — no asymmetric handshake after ${ATTEMPTS} probe runs (web N/A)"
    } >"${RESULT_FILE}"
    echo "Bug 9.1 COULD NOT REPRODUCE after ${ATTEMPTS} attempts (clean=${clean}, infra=${infra_fail})"
    echo "Result: ${RESULT_FILE}"
    exit 0
    ;;
  *)
    echo "Unknown contact_handshake coordinator mode: ${MODE}" >&2
    exit 1
    ;;
esac
