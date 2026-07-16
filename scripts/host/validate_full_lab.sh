#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

VALIDATE_LAB_CONTROL="${BASE_DIR}/scripts/host/validate_lab_control.sh"
VALIDATE_INT_ENDPOINT="${BASE_DIR}/scripts/host/validate_int_endpoint.sh"
VALIDATE_APP_DMZ="${BASE_DIR}/scripts/host/validate_app_dmz.sh"
VALIDATE_DB_INT="${BASE_DIR}/scripts/host/validate_db_int.sh"
VALIDATE_USER_LINUX="${BASE_DIR}/scripts/host/validate_user_linux.sh"
VALIDATE_DNS_INT="${BASE_DIR}/scripts/host/validate_dns_int.sh"
VALIDATE_FILES_INT="${BASE_DIR}/scripts/host/validate_files_int.sh"
VALIDATE_PROXY_INT="${BASE_DIR}/scripts/host/validate_proxy_int.sh"
VALIDATE_PRINT_INT="${BASE_DIR}/scripts/host/validate_print_int.sh"
VALIDATE_LDAP_INT="${BASE_DIR}/scripts/host/validate_ldap_int.sh"

FAILURES=0
FAILED_COMPONENTS=()

log() {
  echo "[validate_full_lab] $1"
}

run_check() {
  local script_path="$1"
  local label="$2"

  if [ ! -x "$script_path" ]; then
    echo "[validate_full_lab] Missing or non-executable: $script_path"
    FAILURES=$((FAILURES + 1))
    FAILED_COMPONENTS+=("$label")
    return
  fi

  log "Running ${label}..."
  if "$script_path"; then
    log "${label} passed."
  else
    log "${label} failed."
    FAILURES=$((FAILURES + 1))
    FAILED_COMPONENTS+=("$label")
  fi
}

log "Starting full laboratory validation..."

run_check "$VALIDATE_LAB_CONTROL" "lab-control validation"
run_check "$VALIDATE_INT_ENDPOINT" "int-endpoint validation"
run_check "$VALIDATE_APP_DMZ" "app-dmz validation"
run_check "$VALIDATE_DB_INT" "db-int validation"
run_check "$VALIDATE_DNS_INT" "dns-int validation"
run_check "$VALIDATE_FILES_INT" "files-int validation"
run_check "$VALIDATE_USER_LINUX" "user-linux validation"
run_check "$VALIDATE_PROXY_INT" "proxy-int validation"
run_check "$VALIDATE_PRINT_INT" "print-int validation"
run_check "$VALIDATE_LDAP_INT" "ldap-int validation"

log "Validation summary..."
if [ "$FAILURES" -eq 0 ]; then
  log "All validation checks passed."
  exit 0
fi

log "Validation completed with ${FAILURES} failing component(s)."
for component in "${FAILED_COMPONENTS[@]}"; do
  log "FAILED: ${component}"
done

exit 1
