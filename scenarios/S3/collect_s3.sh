#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S3"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

docker exec int-endpoint-01 bash -lc "tail -n 100 /var/log/syslog" > "${LATEST_RUN}/syslog_tail.log" || true
docker exec int-endpoint-01 bash -lc "tail -n 100 /var/tmp/purple-lab/s3_profile_trigger.log" > "${LATEST_RUN}/trigger_tail.log" || true
docker exec single-node-wazuh.manager-1 bash -lc "tail -n 200 /var/ossec/logs/alerts/alerts.json" > "${LATEST_RUN}/alerts_tail.json" || true

echo "[S3] Evidence collected into ${LATEST_RUN}"
