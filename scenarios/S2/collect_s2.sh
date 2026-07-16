#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S2"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

docker exec int-endpoint-01 bash -lc "tail -n 120 /var/log/auth.log" > "${LATEST_RUN}/auth_tail.log" || true
docker exec single-node-wazuh.manager-1 bash -lc "tail -n 200 /var/ossec/logs/alerts/alerts.json" > "${LATEST_RUN}/alerts_tail.json" || true

echo "[S2] Evidence collected into ${LATEST_RUN}"
