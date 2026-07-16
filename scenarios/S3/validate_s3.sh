#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S3"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${SCENARIO_DIR}/output/${RUN_ID}"
mkdir -p "${RUN_DIR}"
echo "${RUN_DIR}" > "${SCENARIO_DIR}/output/latest_run_path.txt"

echo "[S3] Checking persistence file..."
docker exec int-endpoint-01 bash -lc "ls -l /etc/profile.d/s3_persistence_marker.sh && sed -n '1,120p' /etc/profile.d/s3_persistence_marker.sh" | tee "${RUN_DIR}/persistence_file.log" || true

echo "[S3] Checking local trigger marker..."
docker exec int-endpoint-01 bash -lc "tail -n 30 /var/tmp/purple-lab/s3_profile_trigger.log" | tee "${RUN_DIR}/trigger_marker.log" || true

echo "[S3] Checking syslog for persistence marker..."
docker exec int-endpoint-01 bash -lc "grep -Ei 's3-persistence|S3_PROFILE_TRIGGER' /var/log/syslog | tail -n 50" | tee "${RUN_DIR}/syslog_validation.log" || true

echo "[S3] Checking Wazuh alerts..."
docker exec single-node-wazuh.manager-1 bash -lc "grep -Ei 's3-persistence|profile.d|s3_persistence_marker|int-endpoint-01' /var/ossec/logs/alerts/alerts.json | tail -n 100" | tee "${RUN_DIR}/wazuh_alerts_validation.log" || true

echo "[S3] Validation completed."
