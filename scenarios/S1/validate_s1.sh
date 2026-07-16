#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S1"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S1] Checking auth.log..."
docker exec int-endpoint-01 bash -lc "grep -Ei 'Failed password|authentication failure|Invalid user' /var/log/auth.log | tail -n 50" | tee "${LATEST_RUN}/auth_validation.log" || true

echo "[S1] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'int-endpoint-01|sshd|pam|Failed password|authentication failure' /var/ossec/logs/alerts/alerts.json | tail -n 100" | tee "${LATEST_RUN}/wazuh_validation.log" || true

echo "[S1] Validation completed."
