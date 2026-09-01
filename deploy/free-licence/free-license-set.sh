#!/usr/bin/env bash
set -euo pipefail

: "${ENTITLEMENT_INTERNAL_TOKEN:?ENTITLEMENT_INTERNAL_TOKEN must be set}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 NAME INSTALLATION_ID" >&2
  exit 2
fi

payload="$(
  python3 - "$1" "$2" <<'PY'
import json
import sys

print(json.dumps({
    "free_user_name": sys.argv[1],
    "participant_installation_id": sys.argv[2],
}))
PY
)"

curl --fail-with-body --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ENTITLEMENT_INTERNAL_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${payload}" \
  "http://127.0.0.1:8081/v1/free-licenses"
