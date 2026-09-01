#!/usr/bin/env bash
set -euo pipefail

: "${ENTITLEMENT_INTERNAL_TOKEN:?ENTITLEMENT_INTERNAL_TOKEN must be set}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 INSTALLATION_ID" >&2
  exit 2
fi

encoded_id="$(
  python3 - "$1" <<'PY'
import sys
import urllib.parse

print(urllib.parse.quote(sys.argv[1], safe=""))
PY
)"

curl --fail-with-body --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ENTITLEMENT_INTERNAL_TOKEN}" \
  "http://127.0.0.1:8081/v1/free-licenses?participant_installation_id=${encoded_id}"
