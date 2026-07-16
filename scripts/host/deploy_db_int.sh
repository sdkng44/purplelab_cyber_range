#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"
COMPOSE_DIR="${BASE_DIR}/compose"

REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"

TARGET_CONTAINER="db-int-01"
WAZUH_AGENT_NAME="db-int-01"

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
  echo "[deploy_db_int] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_db_int] Missing required path: $path"
    exit 1
  fi
}

validate_db_int() {
  log "Checking container status..."
  docker ps | grep "${TARGET_CONTAINER}" || true

  log "Checking PostgreSQL log..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 30 /var/log/postgresql/postgresql.log || true'

  log "Checking Wazuh processes..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'ps aux | grep wazuh | grep -v grep || true'

  log "Checking Wazuh agent log..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 40 /var/ossec/logs/ossec.log || true'

  log "Checking configured localfiles..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'grep -n "postgresql.log" /var/ossec/etc/ossec.conf || true'
}

log "Checking required paths..."
require_path "${COMPOSE_DIR}"
require_path "${REMOVE_WAZUH_AGENT_SCRIPT}"
require_path "${INSTALL_WAZUH_SCRIPT}"
require_path "${CONFIGURE_LOCALFILES_SCRIPT}"

log "Stopping and removing previous container if present..."
cd "${COMPOSE_DIR}"
docker compose stop "${TARGET_CONTAINER}" || true
docker rm -f "${TARGET_CONTAINER}" || true

log "Removing previous Wazuh agent entry if present..."
"${REMOVE_WAZUH_AGENT_SCRIPT}" "${WAZUH_AGENT_NAME}" || true

log "Building and starting ${TARGET_CONTAINER}..."
docker compose up -d --build "${TARGET_CONTAINER}"

log "Waiting for container runtime initialization..."
sleep 10

log "Installing Wazuh agent on ${TARGET_CONTAINER}..."
"${INSTALL_WAZUH_SCRIPT}" "${TARGET_CONTAINER}" "192.168.56.10" "${WAZUH_AGENT_NAME}" "192.168.56.10"

log "Configuring Wazuh localfiles for PostgreSQL logs..."
"${CONFIGURE_LOCALFILES_SCRIPT}" \
  "${TARGET_CONTAINER}" \
  syslog:/var/log/postgresql/postgresql.log

log "Waiting for Wazuh to stabilize..."
sleep 10

if [ "${RUN_VALIDATION}" = "yes" ]; then
  log "Running validation..."
  validate_db_int
fi

log "Deployment completed."
