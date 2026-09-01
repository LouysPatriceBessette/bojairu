#!/usr/bin/env bash
set -euo pipefail

: "${ENTITLEMENT_INTERNAL_TOKEN:?ENTITLEMENT_INTERNAL_TOKEN must be set}"

curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${ENTITLEMENT_INTERNAL_TOKEN}" \
  "http://127.0.0.1:8081/v1/free-licenses"
