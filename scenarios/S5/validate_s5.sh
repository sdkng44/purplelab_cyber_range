#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S5"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S5] Checking web access log..."
docker exec app-dmz-01 bash -lc "tail -n 80 /var/log/purple-web/access.log" | tee "${LATEST_RUN}/access_validation.log" || true

echo "[S5] Checking app JSON log..."
docker exec app-dmz-01 bash -lc "tail -n 80 /var/log/purple-web/app.json" | tee "${LATEST_RUN}/app_json_validation.log" || true

echo "[S5] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'app-dmz-01|Purple Lab S5|search_request|/search|SQL injection' /var/ossec/logs/alerts/alerts.json | tail -n 120" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S5] Validation completed."
