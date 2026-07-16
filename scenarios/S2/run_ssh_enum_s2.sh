#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S2"
ENV_FILE="${SCENARIO_DIR}/inputs/target.env"
OUTPUT_ROOT="${SCENARIO_DIR}/output"

LAB_OWNER="${LAB_OWNER:-labuser}"
LAB_GROUP="${LAB_GROUP:-labuser}"

source "${ENV_FILE}"

if [ -f "${OUTPUT_ROOT}/latest_run_path.txt" ]; then
  RUN_DIR="$(cat "${OUTPUT_ROOT}/latest_run_path.txt")"
else
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
  RUN_DIR="${OUTPUT_ROOT}/${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"
fi

echo "[S2-ENUM] start=$(date -Iseconds)"
echo "[S2-ENUM] target=${TARGET_HOST}:${TARGET_PORT}"
echo "[S2-ENUM] user=${SSH_USER}"
echo "[S2-ENUM] output_dir=${RUN_DIR}"

sshpass -p "${SSH_PASSWORD}" ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -p "${TARGET_PORT}" \
  "${SSH_USER}@${TARGET_HOST}" \
  '
    echo "=== WHOAMI ==="
    whoami
    echo "=== ID ==="
    id
    echo "=== HOSTNAME ==="
    hostname
    echo "=== UNAME ==="
    uname -a
    echo "=== OS RELEASE ==="
    cat /etc/os-release
    echo "=== IP ADDR ==="
    ip -brief addr
    echo "=== IP ROUTE ==="
    ip route
    echo "=== LISTENING PORTS ==="
    ss -tuln
    echo "=== LAST LOGINS ==="
    last -n 5
  ' \
  2>&1 | tee "${RUN_DIR}/s2_enum.log" || true

echo "[S2-ENUM] end=$(date -Iseconds)"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
