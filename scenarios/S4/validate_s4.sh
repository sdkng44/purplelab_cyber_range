#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S4"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S4] Checking web access log..."
docker exec app-dmz-01 bash -lc "tail -n 80 /var/log/purple-web/access.log" | tee "${LATEST_RUN}/access_validation.log" || true

echo "[S4] Checking web auth log..."
docker exec app-dmz-01 bash -lc "tail -n 80 /var/log/purple-web/auth.log" | tee "${LATEST_RUN}/auth_validation.log" || true

echo "[S4] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'app-dmz-01|/login|401|Purple Lab S4|Web server 400 error code' /var/ossec/logs/alerts/alerts.json | tail -n 120" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S4] Validation completed."
