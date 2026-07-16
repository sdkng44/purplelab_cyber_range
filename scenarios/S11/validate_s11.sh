#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S11"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${SCENARIO_DIR}/output/${RUN_ID}"
mkdir -p "${RUN_DIR}"

docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'win-endpoint-01|PurpleLab-S11-BasicPersistence|100701|Task Scheduler|powershell.exe|67027' /var/ossec/logs/alerts/alerts.json | tail -n 200" | tee "${RUN_DIR}/wazuh_alerts_validation.log" || true

echo "${RUN_DIR}" > "${SCENARIO_DIR}/output/latest_run_path.txt"
echo "[S11] Validation completed."
