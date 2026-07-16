#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
COMPOSE_DIR="${BASE_DIR}/compose"

REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"

SSH_KEY_SCRIPT="${BASE_DIR}/scripts/linux/configure_ssh_authorized_key_container.sh"
LAB_ADMIN_PUBKEY="/home/labuser/.ssh/purplelab_admin_ed25519.pub"

TARGET_CONTAINER="user-linux-01"
WAZUH_AGENT_NAME="user-linux-01"

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
  echo "[deploy_user_linux] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_user_linux] Missing required path: $path"
    exit 1
  fi
}

validate_user_linux() {
  log "Checking container status..."
  docker ps | grep "${TARGET_CONTAINER}" || true

  log "Checking Wazuh processes..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'ps aux | grep wazuh | grep -v grep || true'

  log "Checking auth.log..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 30 /var/log/auth.log || true'

  log "Checking Wazuh agent log..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'tail -n 40 /var/ossec/logs/ossec.log || true'

  log "Checking configured localfiles..."
  docker exec "${TARGET_CONTAINER}" bash -lc 'grep -nE "auth.log|syslog" /var/ossec/etc/ossec.conf || true'
}

log "Checking required paths..."
require_path "${COMPOSE_DIR}"
require_path "${REMOVE_WAZUH_AGENT_SCRIPT}"
require_path "${INSTALL_WAZUH_SCRIPT}"
require_path "${CONFIGURE_LOCALFILES_SCRIPT}"
require_path "${SSH_KEY_SCRIPT}"
require_path "${LAB_ADMIN_PUBKEY}"

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

log "Configuring Wazuh localfiles..."
"${CONFIGURE_LOCALFILES_SCRIPT}" \
  "${TARGET_CONTAINER}" \
  syslog:/var/log/auth.log \
  syslog:/var/log/syslog

log "Waiting for Wazuh to stabilize..."
sleep 10

log "Configuring SSH authorized key for analyst..."
"${SSH_KEY_SCRIPT}" "${TARGET_CONTAINER}" analyst "${LAB_ADMIN_PUBKEY}"

log "Refreshing known_hosts entry for user-linux-01..."
ssh-keygen -f /home/labuser/.ssh/known_hosts -R "[192.168.56.10]:2226" >/dev/null 2>&1 || true
ssh-keyscan -p 2226 192.168.56.10 >> /home/labuser/.ssh/known_hosts 2>/dev/null || true

if [ "${RUN_VALIDATION}" = "yes" ]; then
  log "Running validation..."
  validate_user_linux
fi

log "Deployment completed."
