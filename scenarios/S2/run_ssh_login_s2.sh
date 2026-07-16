#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S2"
ENV_FILE="${SCENARIO_DIR}/inputs/target.env"
OUTPUT_ROOT="${SCENARIO_DIR}/output"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${OUTPUT_ROOT}/${RUN_ID}"

LAB_OWNER="${LAB_OWNER:-labuser}"
LAB_GROUP="${LAB_GROUP:-labuser}"

source "${ENV_FILE}"

mkdir -p "${RUN_DIR}"

echo "[S2-LOGIN] start=$(date -Iseconds)"
echo "[S2-LOGIN] target=${TARGET_HOST}:${TARGET_PORT}"
echo "[S2-LOGIN] user=${SSH_USER}"
echo "[S2-LOGIN] output_dir=${RUN_DIR}"

sshpass -p "${SSH_PASSWORD}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -p "${TARGET_PORT}" \
  "${SSH_USER}@${TARGET_HOST}" \
  "echo S2-LOGIN-OK && whoami && hostname" \
  2>&1 | tee "${RUN_DIR}/s2_login.log" || true

echo "[S2-LOGIN] end=$(date -Iseconds)"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
