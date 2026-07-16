#!/usr/bin/env bash
set -euo pipefail

CALDERA_SERVER="${CALDERA_SERVER:-http://192.168.56.10:8888}"
SANDCAT_GROUP="${SANDCAT_GROUP:-red}"
SANDCAT_PAW="${SANDCAT_PAW:-$(hostname -s)}"
SANDCAT_BIN="${SANDCAT_BIN:-/opt/caldera/sandcat}"
SANDCAT_LOG="${SANDCAT_LOG:-/var/log/sandcat.log}"

if [ -x "${SANDCAT_BIN}" ]; then
  pgrep -f "${SANDCAT_BIN}.*-paw ${SANDCAT_PAW}" >/dev/null || \
  nohup "${SANDCAT_BIN}" \
    -server "${CALDERA_SERVER}" \
    -group "${SANDCAT_GROUP}" \
    -paw "${SANDCAT_PAW}" \
    -v > "${SANDCAT_LOG}" 2>&1 &
fi

exit 0
