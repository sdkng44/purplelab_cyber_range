#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
COMPOSE_DIR="${BASE_DIR}/compose"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"
SSH_KEY_SCRIPT="${BASE_DIR}/scripts/linux/configure_ssh_authorized_key_container.sh"
LAB_ADMIN_PUBKEY="/home/labuser/.ssh/purplelab_admin_ed25519.pub"
TARGET_CONTAINER="dns-int-01"
WAZUH_MANAGER="192.168.56.10"

log() {
  echo "[deploy_dns_int] $1"
}

log "Deploying dns-int-01..."
cd "${COMPOSE_DIR}"
docker compose up -d dns-int-01

sleep 10

log "Installing Wazuh agent..."
"${INSTALL_WAZUH_SCRIPT}" "${TARGET_CONTAINER}" "${WAZUH_MANAGER}" "${TARGET_CONTAINER}" "${WAZUH_MANAGER}"

log "Configuring Wazuh localfiles..."
"${CONFIGURE_LOCALFILES_SCRIPT}" \
  "${TARGET_CONTAINER}" \
  syslog:/var/log/syslog \
  syslog:/var/log/auth.log \
  syslog:/var/log/dnsmasq/dnsmasq.log

log "Configuring SSH authorized key for analyst..."
"${SSH_KEY_SCRIPT}" "${TARGET_CONTAINER}" analyst "${LAB_ADMIN_PUBKEY}"

log "Refreshing known_hosts entry..."
mkdir -p /home/labuser/.ssh
touch /home/labuser/.ssh/known_hosts
chmod 700 /home/labuser/.ssh
chmod 600 /home/labuser/.ssh/known_hosts
ssh-keygen -f /home/labuser/.ssh/known_hosts -R "[192.168.56.10]:2227" >/dev/null 2>&1 || true
ssh-keyscan -p 2227 192.168.56.10 >> /home/labuser/.ssh/known_hosts 2>/dev/null || true

log "Deployment completed."
