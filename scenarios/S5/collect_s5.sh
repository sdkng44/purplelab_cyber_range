#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S5"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

docker exec app-dmz-01 bash -lc "tail -n 150 /var/log/purple-web/access.log" > "${LATEST_RUN}/access_tail.log" || true
docker exec app-dmz-01 bash -lc "tail -n 150 /var/log/purple-web/app.json" > "${LATEST_RUN}/app_json_tail.log" || true
docker exec app-dmz-01 bash -lc "tail -n 150 /var/log/purple-web/error.log" > "${LATEST_RUN}/error_tail.log" || true
docker exec single-node-wazuh.manager-1 bash -lc "tail -n 250 /var/ossec/logs/alerts/alerts.json" > "${LATEST_RUN}/alerts_tail.json" || true

echo "[S5] Evidence collected into ${LATEST_RUN}"
