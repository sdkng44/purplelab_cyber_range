#!/usr/bin/env bash
set -euo pipefail

SCENARIO_DIR="/home/labuser/purple-lab/scenarios/S9"
ENV_FILE="${SCENARIO_DIR}/inputs/target.env"
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

echo "[S9] start=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "[S9] target=//${TARGET_HOST}/${TARGET_SHARE}" | tee -a "${SUMMARY_LOG}"
echo "[S9] output_dir=${RUN_DIR}" | tee -a "${SUMMARY_LOG}"

attempt=0

while IFS= read -r password; do
  [ -z "${password}" ] && continue
  attempt=$((attempt + 1))
  ts="$(date -Iseconds)"

  set +e
  smbclient "//${TARGET_HOST}/${TARGET_SHARE}" \
    -U "${DOMAIN}\\${VALID_USER}%${password}" \
    -c 'dir' \
    > "${RUN_DIR}/failed_response_${attempt}.out" \
    2> "${RUN_DIR}/failed_response_${attempt}.err"
  rc=$?
  set -e

  printf '%s failed_attempt=%s user="%s" password="%s" rc=%s\n' \
    "${ts}" "${attempt}" "${VALID_USER}" "${password}" "${rc}" \
    | tee -a "${ATTEMPT_LOG}"

  sleep "${SLEEP_SECONDS}"
done < "${PASSWORDS_FILE}"

echo "[S9] attempting successful SMB logon..." | tee -a "${SUMMARY_LOG}"

smbclient "//${TARGET_HOST}/${TARGET_SHARE}" \
  -U "${DOMAIN}\\${VALID_USER}%${VALID_PASSWORD}" \
  -c 'dir' \
  > "${RUN_DIR}/success_dir.out" \
  2> "${RUN_DIR}/success_dir.err"

printf '%s successful_smb_access user="%s" share="%s"\n' \
  "$(date -Iseconds)" "${VALID_USER}" "${TARGET_SHARE}" \
  | tee -a "${SUCCESS_LOG}"

echo "[S9] end=$(date -Iseconds)" | tee -a "${SUMMARY_LOG}"
echo "${RUN_DIR}" > "${OUTPUT_ROOT}/latest_run_path.txt"

chmod -R a+rwX "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
if id "${LAB_OWNER}" >/dev/null 2>&1; then
  chown -R "${LAB_OWNER}:${LAB_GROUP}" "${RUN_DIR}" "${OUTPUT_ROOT}/latest_run_path.txt" || true
fi
