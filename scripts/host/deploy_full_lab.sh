#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"

ENSURE_LAB_CONTROL_SCRIPT="${BASE_DIR}/scripts/host/ensure_lab_control.sh"
DEPLOY_INT_ENDPOINT_SCRIPT="${BASE_DIR}/scripts/host/deploy_int_endpoint.sh"
DEPLOY_APP_DMZ_SCRIPT="${BASE_DIR}/scripts/host/deploy_app_dmz.sh"
DEPLOY_DB_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_db_int.sh"
DEPLOY_USER_LINUX_SCRIPT="${BASE_DIR}/scripts/host/deploy_user_linux.sh"
DEPLOY_DNS_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_dns_int.sh"
DEPLOY_FILES_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_files_int.sh"
DEPLOY_POOL_NODES_SCRIPT="${BASE_DIR}/scripts/host/deploy_pool_nodes.sh"
DEPLOY_PROXY_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_proxy_int.sh"
DEPLOY_LDAP_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_ldap_int.sh"
DEPLOY_PRINT_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_print_int.sh"
VALIDATE_FULL_LAB_SCRIPT="${BASE_DIR}/scripts/host/validate_full_lab.sh"

RUN_VALIDATION="yes"
POOL_COUNT=3

for arg in "$@"; do
  case "$arg" in
    --no-validate)
      RUN_VALIDATION="no"
      shift
      ;;
    --pool-count=*)
      POOL_COUNT="${arg#*=}"
      shift
      ;;
    *)
      ;;
  esac
done

log() {
  echo "[deploy_full_lab] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_full_lab] Missing required path: $path"
    exit 1
  fi
}

log "Checking required paths..."
require_path "${ENSURE_LAB_CONTROL_SCRIPT}"
require_path "${DEPLOY_INT_ENDPOINT_SCRIPT}"
require_path "${DEPLOY_APP_DMZ_SCRIPT}"
require_path "${DEPLOY_DB_INT_SCRIPT}"
require_path "${DEPLOY_USER_LINUX_SCRIPT}"
require_path "${DEPLOY_DNS_INT_SCRIPT}"
require_path "${DEPLOY_FILES_INT_SCRIPT}"
require_path "${DEPLOY_POOL_NODES_SCRIPT}"
require_path "${DEPLOY_PROXY_INT_SCRIPT}"
require_path "${DEPLOY_PRINT_INT_SCRIPT}"
require_path "${DEPLOY_LDAP_INT_SCRIPT}"
require_path "${VALIDATE_FULL_LAB_SCRIPT}"

log "Ensuring lab control..."
bash "${ENSURE_LAB_CONTROL_SCRIPT}"

log "Deploying internal endpoint..."
if [ "${RUN_VALIDATION}" = "yes" ]; then
  bash "${DEPLOY_INT_ENDPOINT_SCRIPT}"
else
  bash "${DEPLOY_INT_ENDPOINT_SCRIPT}" --no-validate
fi

log "Deploying DMZ application node..."
if [ "${RUN_VALIDATION}" = "yes" ]; then
  bash "${DEPLOY_APP_DMZ_SCRIPT}"
else
  bash "${DEPLOY_APP_DMZ_SCRIPT}" --no-validate
fi

log "Deploying internal database node..."
if [ "${RUN_VALIDATION}" = "yes" ]; then
  bash "${DEPLOY_DB_INT_SCRIPT}"
else
  bash "${DEPLOY_DB_INT_SCRIPT}" --no-validate
fi

log "Deploying internal DNS node..."
bash "${DEPLOY_DNS_INT_SCRIPT}"

log "Deploying internal file service node..."
bash "${DEPLOY_FILES_INT_SCRIPT}"

log "Deploying internal proxy node..."
bash "${DEPLOY_PROXY_INT_SCRIPT}"

log "Deploying internal LDAP node..."
bash "${DEPLOY_LDAP_INT_SCRIPT}"

log "Deploying internal print node..."
bash "${DEPLOY_PRINT_INT_SCRIPT}"

log "Deploying user Linux node..."
if [ "${RUN_VALIDATION}" = "yes" ]; then
  bash "${DEPLOY_USER_LINUX_SCRIPT}"
else
  bash "${DEPLOY_USER_LINUX_SCRIPT}" --no-validate
fi

log "Deploying pool nodes (count=${POOL_COUNT})..."
if [ "${RUN_VALIDATION}" = "yes" ]; then
  bash "${DEPLOY_POOL_NODES_SCRIPT}" "${POOL_COUNT}"
else
  bash "${DEPLOY_POOL_NODES_SCRIPT}" --no-validate "${POOL_COUNT}"
fi

if [ "${RUN_VALIDATION}" = "yes" ]; then
  log "Running full laboratory validation..."
  bash "${VALIDATE_FULL_LAB_SCRIPT}"
fi

log "Full laboratory deployment completed."
