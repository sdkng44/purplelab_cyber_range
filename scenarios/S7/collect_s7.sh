#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S7"
LATEST_RUN="$(cat "${SCENARIO_DIR}/output/latest_run_path.txt")"

docker exec db-int-01 bash -lc "tail -n 200 /var/log/postgresql/postgresql.log" > "${LATEST_RUN}/postgres_tail.log" || true
docker exec db-int-01 bash -lc "tail -n 80 /var/ossec/logs/ossec.log" > "${LATEST_RUN}/agent_ossec_tail.log" || true
docker exec single-node-wazuh.manager-1 bash -lc "tail -n 250 /var/ossec/logs/alerts/alerts.json" > "${LATEST_RUN}/alerts_tail.json" || true

echo "[S7] Evidence collected into ${LATEST_RUN}"
