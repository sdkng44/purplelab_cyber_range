#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S1"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S1] Collecting auth.log tail..."
docker exec int-endpoint-01 bash -lc "tail -n 100 /var/log/auth.log" > "${LATEST_RUN}/auth_tail.log" || true

echo "[S1] Collecting Wazuh alerts tail..."
docker exec single-node-wazuh.manager-1 bash -lc "tail -n 200 /var/ossec/logs/alerts/alerts.json" > "${LATEST_RUN}/alerts_tail.json" || true

echo "[S1] Collecting process snapshots..."
{
  echo "=== host-side sandcat ==="
  ps -eo pid=,args= | grep '/opt/caldera/sandcat' | grep -v grep || true
  echo
  echo "=== int-endpoint-01 processes ==="
  docker exec int-endpoint-01 bash -lc "ps aux" || true
} > "${LATEST_RUN}/process_snapshot.txt"

echo "[S1] Evidence collected into ${LATEST_RUN}"
