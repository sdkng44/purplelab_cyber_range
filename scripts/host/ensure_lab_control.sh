#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"
VALIDATE_SCRIPT="${BASE_DIR}/scripts/host/validate_lab_control.sh"
PROVISION_SCRIPT="${BASE_DIR}/scripts/host/provision_lab_control.sh"
BOOTSTRAP_SCRIPT="${BASE_DIR}/scripts/host/bootstrap_lab_control.sh"

log() {
  echo "[ensure_lab_control] $1"
}

if [ ! -x "$VALIDATE_SCRIPT" ]; then
  echo "[ensure_lab_control] Validate script not found or not executable: $VALIDATE_SCRIPT"
  exit 1
fi

if [ ! -x "$PROVISION_SCRIPT" ]; then
  echo "[ensure_lab_control] Provision script not found or not executable: $PROVISION_SCRIPT"
  exit 1
fi

if [ ! -x "$BOOTSTRAP_SCRIPT" ]; then
  echo "[ensure_lab_control] Bootstrap script not found or not executable: $BOOTSTRAP_SCRIPT"
  exit 1
fi

log "Running initial validation..."
if "$VALIDATE_SCRIPT"; then
  log "Validation already passed. No provision/bootstrap actions needed."
  exit 0
fi

log "Validation reported missing or failed components. Running provision..."
"$PROVISION_SCRIPT"

log "Running bootstrap..."
"$BOOTSTRAP_SCRIPT"

log "Running final validation..."
if "$VALIDATE_SCRIPT"; then
  log "Ensure completed successfully."
  exit 0
fi

log "Ensure completed, but final validation still reports issues."
exit 1
