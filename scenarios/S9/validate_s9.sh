#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S9"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S9] Checking Wazuh alerts for Windows logon activity..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'win-endpoint-01|60122|60137|92657|Logon Failure|Remote Logon|User Logoff|labuser' /var/ossec/logs/alerts/alerts.json | tail -n 150" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S9] Validation completed."
