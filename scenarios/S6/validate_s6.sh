#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S6"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S6] Checking PostgreSQL log..."
docker exec db-int-01 bash -lc "tail -n 80 /var/log/postgresql/postgresql.log" | tee "${LATEST_RUN}/postgres_validation.log" || true

echo "[S6] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'db-int-01|Purple Lab S6|100501|100502|password authentication failed for user|postgres' /var/ossec/logs/alerts/alerts.json | tail -n 120" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S6] Validation completed."
