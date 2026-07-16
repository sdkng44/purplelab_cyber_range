#!/usr/bin/env bash
set -euo pipefail

CALDERA_SERVER="${1:-${CALDERA_SERVER:-http://192.168.56.10:8888}}"
CALDERA_RED_KEY="${2:-${CALDERA_RED_KEY:?CALDERA_RED_KEY is not defined}}"
SANDCAT_PAW="${3:-${SANDCAT_PAW:-$(hostname -s)}}"

echo "[reset_caldera_agent_registration] server=${CALDERA_SERVER}"
echo "[reset_caldera_agent_registration] paw=${SANDCAT_PAW}"

HTTP_CODE="$(
  curl -s -o /tmp/caldera-delete.out -w "%{http_code}" \
    -X DELETE \
    -H "KEY:${CALDERA_RED_KEY}" \
    "${CALDERA_SERVER}/api/v2/agents/${SANDCAT_PAW}" || true
)"

echo "[reset_caldera_agent_registration] delete_http_code=${HTTP_CODE}"

exit 0
