#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"

APPLY_LAB_FIREWALL_PHASE1_SCRIPT="${BASE_DIR}/scripts/host/apply_lab_firewall_phase1.sh"
VALIDATE_SEGMENTATION_PHASE1_SCRIPT="${BASE_DIR}/scripts/host/validate_segmentation_phase1.sh"

ENSURE_LAB_CONTROL_SCRIPT="${BASE_DIR}/scripts/host/ensure_lab_control.sh"
VALIDATE_FULL_LAB_SCRIPT="${BASE_DIR}/scripts/host/validate_full_lab.sh"

DEPLOY_INT_ENDPOINT_SCRIPT="${BASE_DIR}/scripts/host/deploy_int_endpoint.sh"
DEPLOY_APP_DMZ_SCRIPT="${BASE_DIR}/scripts/host/deploy_app_dmz.sh"
DEPLOY_DB_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_db_int.sh"
DEPLOY_DNS_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_dns_int.sh"
DEPLOY_FILES_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_files_int.sh"
DEPLOY_USER_LINUX_SCRIPT="${BASE_DIR}/scripts/host/deploy_user_linux.sh"
DEPLOY_PROXY_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_proxy_int.sh"
DEPLOY_PRINT_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_print_int.sh"
DEPLOY_LDAP_INT_SCRIPT="${BASE_DIR}/scripts/host/deploy_ldap_int.sh"
DEPLOY_POOL_NODES_SCRIPT="${BASE_DIR}/scripts/host/deploy_pool_nodes.sh"

POOL_COUNT=3
FORCE_REDEPLOY="no"
EXECUTED_STEPS=()
FAILED_STEPS=()

log() {
  echo "[ensure_full_lab] $1"
}

usage() {
  cat <<EOF
Usage: $0 [--force] [--pool-count N]

Options:
  --force          Force redeployment even if validate_full_lab.sh passes
  --pool-count N   Number of pool nodes to deploy (default: 3)
EOF
}

require_exec() {
  local path="$1"
  if [ ! -x "$path" ]; then
    echo "[ensure_full_lab] Missing or non-executable script: $path"
    exit 1
  fi
}

run_step() {
  local label="$1"
  shift
  log "Running: ${label}"
  EXECUTED_STEPS+=("${label}")

  if "$@"; then
    log "${label} passed."
  else
    log "${label} failed."
    FAILED_STEPS+=("${label}")
    return 1
  fi
}

print_summary() {
  log "Execution summary..."
  for step in "${EXECUTED_STEPS[@]}"; do
    log "EXECUTED: ${step}"
  done

  if [ "${#FAILED_STEPS[@]}" -eq 0 ]; then
    log "No failed steps."
  else
    for step in "${FAILED_STEPS[@]}"; do
      log "FAILED: ${step}"
    done
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE_REDEPLOY="yes"
      shift
      ;;
    --pool-count)
      POOL_COUNT="${2:?missing value for --pool-count}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ensure_full_lab] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

require_exec "${APPLY_LAB_FIREWALL_PHASE1_SCRIPT}"
require_exec "${VALIDATE_SEGMENTATION_PHASE1_SCRIPT}"
require_exec "${ENSURE_LAB_CONTROL_SCRIPT}"
require_exec "${VALIDATE_FULL_LAB_SCRIPT}"
require_exec "${DEPLOY_INT_ENDPOINT_SCRIPT}"
require_exec "${DEPLOY_APP_DMZ_SCRIPT}"
require_exec "${DEPLOY_DB_INT_SCRIPT}"
require_exec "${DEPLOY_DNS_INT_SCRIPT}"
require_exec "${DEPLOY_FILES_INT_SCRIPT}"
require_exec "${DEPLOY_USER_LINUX_SCRIPT}"
require_exec "${DEPLOY_PROXY_INT_SCRIPT}"
require_exec "${DEPLOY_PRINT_INT_SCRIPT}"
require_exec "${DEPLOY_LDAP_INT_SCRIPT}"
require_exec "${DEPLOY_POOL_NODES_SCRIPT}"

if [ "${FORCE_REDEPLOY}" != "yes" ]; then
  log "Running initial full lab validation..."
  if "${VALIDATE_FULL_LAB_SCRIPT}"; then
    log "Full lab validation already passed. No redeployment needed."
    exit 0
  fi
  log "Validation reported missing or failed components. Proceeding with ensure/redeploy flow..."
else
  log "Force mode enabled. Skipping initial validation and redeploying full lab."
fi

run_step "lab-control ensure" "${ENSURE_LAB_CONTROL_SCRIPT}" || { print_summary; exit 1; }
run_step "dns-int deploy" "${DEPLOY_DNS_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "int-endpoint deploy" "${DEPLOY_INT_ENDPOINT_SCRIPT}" || { print_summary; exit 1; }
run_step "app-dmz deploy" "${DEPLOY_APP_DMZ_SCRIPT}" || { print_summary; exit 1; }
run_step "db-int deploy" "${DEPLOY_DB_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "files-int deploy" "${DEPLOY_FILES_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "proxy-int deploy" "${DEPLOY_PROXY_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "user-linux deploy" "${DEPLOY_USER_LINUX_SCRIPT}" || { print_summary; exit 1; }
run_step "ldap-int deploy" "${DEPLOY_LDAP_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "print-int deploy" "${DEPLOY_PRINT_INT_SCRIPT}" || { print_summary; exit 1; }
run_step "pool deploy" "${DEPLOY_POOL_NODES_SCRIPT}" "${POOL_COUNT}" || { print_summary; exit 1; }
run_step "firewall phase1 apply" "${APPLY_LAB_FIREWALL_PHASE1_SCRIPT}" || { print_summary; exit 1; }
run_step "segmentation phase1 validate" "${VALIDATE_SEGMENTATION_PHASE1_SCRIPT}" || { print_summary; exit 1; }

log "Running final full lab validation..."
if "${VALIDATE_FULL_LAB_SCRIPT}"; then
  print_summary
  log "ensure_full_lab completed successfully."
  exit 0
fi

FAILED_STEPS+=("final full lab validation")
print_summary
log "ensure_full_lab completed, but final validation still reports issues."
exit 1
