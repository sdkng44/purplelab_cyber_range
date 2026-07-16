#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S2"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

echo "[S2] Checking auth.log for successful SSH login..."
docker exec int-endpoint-01 bash -lc "grep -Ei 'Accepted password|session opened|session closed|sshd' /var/log/auth.log | tail -n 80" | tee "${LATEST_RUN}/auth_validation.log" || true

echo "[S2] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 'int-endpoint-01|sshd|Accepted password|session opened|pam_unix' /var/ossec/logs/alerts/alerts.json | tail -n 100" | tee "${LATEST_RUN}/wazuh_alerts_validation.log" || true

echo "[S2] Validation completed."
