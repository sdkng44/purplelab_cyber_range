#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
ENV_FILE="${ENV_FILE:-${BASE_DIR}/generated/caldera.env}"
RESET_SCRIPT="${BASE_DIR}/scripts/linux/reset_caldera_agent_registration.sh"

if [ -f "${ENV_FILE}" ]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

CALDERA_SERVER="${1:-${CALDERA_SERVER:-http://192.168.56.10:8888}}"
SANDCAT_GROUP="${2:-emu}"
SANDCAT_PAW="${3:-lab-control-emu}"
SANDCAT_LOG="/var/log/sandcat-${SANDCAT_PAW}.log"

echo "[install_sandcat_lab_control] server=${CALDERA_SERVER}"
echo "[install_sandcat_lab_control] group=${SANDCAT_GROUP}"
echo "[install_sandcat_lab_control] paw=${SANDCAT_PAW}"

sudo bash -lc "
set -euo pipefail

mkdir -p /opt/caldera
rm -f /opt/caldera/sandcat

while read -r pid cmdline; do
  if [ -n \"\${pid:-}\" ]; then
    kill \"\$pid\" || true
  fi
done < <(
  ps -eo pid=,args= | awk -v paw='${SANDCAT_PAW}' '
    \$2 == \"/opt/caldera/sandcat\" && \$0 ~ (\"-paw \" paw \"($| )\") { print \$1, \$0 }
  '
)
"

if [ -x "${RESET_SCRIPT}" ]; then
  "${RESET_SCRIPT}" "${CALDERA_SERVER}" "${CALDERA_RED_KEY}" "${SANDCAT_PAW}" || true
fi

sudo bash -lc "
set -euo pipefail

curl -fsSL -X POST \
  -H 'file:sandcat.go' \
  -H 'platform:linux' \
  '${CALDERA_SERVER}/file/download' \
  -o /opt/caldera/sandcat

chmod +x /opt/caldera/sandcat

nohup /opt/caldera/sandcat \
  -server '${CALDERA_SERVER}' \
  -group '${SANDCAT_GROUP}' \
  -paw '${SANDCAT_PAW}' \
  -v > '${SANDCAT_LOG}' 2>&1 &

sleep 5

echo '=== sandcat binary ==='
ls -l /opt/caldera/sandcat || true
echo '=== host-side sandcat process ==='
ps -eo pid=,args= | awk -v paw='${SANDCAT_PAW}' '
  \$2 == \"/opt/caldera/sandcat\" && \$0 ~ (\"-paw \" paw \"($| )\") { print }
' || true
echo '=== sandcat log ==='
tail -n 30 '${SANDCAT_LOG}' || true
"
