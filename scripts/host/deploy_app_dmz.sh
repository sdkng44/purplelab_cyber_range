#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
COMPOSE_DIR="${BASE_DIR}/compose"
GENERATED_ENV="${BASE_DIR}/generated/caldera.env"
SUPPORT_PRIVKEY="/home/labuser/.ssh/purplelab_support_ed25519"

REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"

TARGET_CONTAINER="app-dmz-01"
WAZUH_AGENT_NAME="app-dmz-01"

RUN_VALIDATION="yes"

for arg in "$@"; do
  case "$arg" in
    --no-validate)
      RUN_VALIDATION="no"
      shift
      ;;
    *)
      ;;
  esac
done

log() {
  echo "[deploy_app_dmz] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_app_dmz] Missing required path: $path"
    exit 1
  fi
}

validate_app_dmz() {
  log "Checking container status..."
  docker ps | grep "${TARGET_CONTAINER}" || true

  log "Checking Wazuh processes..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'ps aux | grep wazuh | grep -v grep || true'

  log "Checking app logs..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 20 /var/log/purple-web/access.log || true'
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 20 /var/log/purple-web/auth.log || true'
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 20 /var/log/purple-web/error.log || true'

  log "Checking Wazuh agent log..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

  log "Checking configured localfiles..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'grep -nE "purple-web|access.log|auth.log|error.log" /var/ossec/etc/ossec.conf || true'
}

log "Checking required paths..."
require_path "${COMPOSE_DIR}"
require_path "${GENERATED_ENV}"
require_path "${REMOVE_WAZUH_AGENT_SCRIPT}"
require_path "${INSTALL_WAZUH_SCRIPT}"
require_path "${CONFIGURE_LOCALFILES_SCRIPT}"
require_path "${SUPPORT_PRIVKEY}"

log "Loading generated environment variables..."
set -a
source "${GENERATED_ENV}"
set +a
export CALDERA_URL="${CALDERA_SERVER:-http://192.168.56.10:8888}"
export PURPLE_SUPPORT_PATH="${PURPLE_SUPPORT_PATH:-/support/diagnostics}"
export SUPPORT_SSH_USER="${SUPPORT_SSH_USER:-analyst}"
export SUPPORT_SSH_KEY="${SUPPORT_SSH_KEY:-/opt/purple-web/.ssh/purplelab_support_ed25519}"
export PURPLE_POOL_GROUP="${PURPLE_POOL_GROUP:-s13-flow}"

log "Using app-dmz support settings..."
log "CALDERA_URL=${CALDERA_URL}"
log "PURPLE_SUPPORT_PATH=${PURPLE_SUPPORT_PATH}"
log "SUPPORT_SSH_USER=${SUPPORT_SSH_USER}"
log "SUPPORT_SSH_KEY=${SUPPORT_SSH_KEY}"

log "Stopping and removing previous container if present..."
cd "${COMPOSE_DIR}"
docker compose stop "${TARGET_CONTAINER}" || true
docker rm -f "${TARGET_CONTAINER}" || true

log "Removing previous Wazuh agent entry if present..."
"${REMOVE_WAZUH_AGENT_SCRIPT}" "${WAZUH_AGENT_NAME}" || true

log "Building and starting ${TARGET_CONTAINER}..."
docker compose up -d --build "${TARGET_CONTAINER}"

log "Waiting for container runtime initialization..."
sleep 8

log "Installing Wazuh agent on ${TARGET_CONTAINER}..."
"${INSTALL_WAZUH_SCRIPT}" "${TARGET_CONTAINER}" "192.168.56.10" "${WAZUH_AGENT_NAME}" "192.168.56.10"

log "Configuring Wazuh localfiles for web logs..."
"${CONFIGURE_LOCALFILES_SCRIPT}" \
  "${TARGET_CONTAINER}" \
  syslog:/var/log/purple-web/access.log \
  syslog:/var/log/purple-web/auth.log \
  syslog:/var/log/purple-web/error.log \
  json:/var/log/purple-web/app.json

log "Waiting for Wazuh to stabilize..."
sleep 10

if [ "${RUN_VALIDATION}" = "yes" ]; then
  log "Running validation..."
  validate_app_dmz
fi

log "Deployment completed."
