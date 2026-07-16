#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S7"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S7] Checking PostgreSQL log..."
docker exec db-int-01 bash -lc "tail -n 120 /var/log/postgresql/postgresql.log" | tee "${LATEST_RUN}/postgres_validation.log" || true

echo "[S7] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'db-int-01|Purple Lab S7|100511|100512|100513|connection authorized|statement:' /var/ossec/logs/alerts/alerts.json | tail -n 120" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S7] Validation completed."
