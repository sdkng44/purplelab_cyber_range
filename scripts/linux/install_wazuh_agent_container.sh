#!/usr/bin/env bash
set -euo pipefail

TARGET_CONTAINER="${1:?Usage: $0 <target_container> [manager_ip] [agent_name] [registration_server]}"
WAZUH_MANAGER="${2:-192.168.56.10}"
WAZUH_AGENT_NAME="${3:-${TARGET_CONTAINER}}"
WAZUH_REGISTRATION_SERVER="${4:-${WAZUH_MANAGER}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"

echo "[install_wazuh_agent_container] target=${TARGET_CONTAINER}"
echo "[install_wazuh_agent_container] manager=${WAZUH_MANAGER}"
echo "[install_wazuh_agent_container] agent_name=${WAZUH_AGENT_NAME}"
echo "[install_wazuh_agent_container] registration_server=${WAZUH_REGISTRATION_SERVER}"

if [ -x "${REMOVE_WAZUH_AGENT_SCRIPT}" ]; then
  echo "[install_wazuh_agent_container] removing stale manager-side agent registration if present..."
  "${REMOVE_WAZUH_AGENT_SCRIPT}" "${WAZUH_AGENT_NAME}" || true
else
  echo "[install_wazuh_agent_container] remove_wazuh_agent_by_name.sh not found, skipping stale registration cleanup"
fi

docker exec -u 0 "${TARGET_CONTAINER}" bash -lc "
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

install_or_reinstall_agent() {
  apt-get update
  apt-get install -y gnupg apt-transport-https curl

  if [ ! -f /usr/share/keyrings/wazuh.gpg ]; then
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
      gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
    chmod 644 /usr/share/keyrings/wazuh.gpg
  fi

  echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' \
    > /etc/apt/sources.list.d/wazuh.list

  apt-get update
  WAZUH_MANAGER='${WAZUH_MANAGER}' \
  WAZUH_AGENT_NAME='${WAZUH_AGENT_NAME}' \
  WAZUH_REGISTRATION_SERVER='${WAZUH_REGISTRATION_SERVER}' \
  apt-get install -y wazuh-agent
}

ensure_manager_config() {
  local cfg='/var/ossec/etc/ossec.conf'

  if [ -f \"\${cfg}\" ]; then
    if grep -q '<address>' \"\${cfg}\"; then
      sed -i \"s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|\" \"\${cfg}\"
    fi
  fi
}

if ! dpkg -s wazuh-agent >/dev/null 2>&1; then
  install_or_reinstall_agent
else
  ensure_manager_config
fi

if [ -x /var/ossec/bin/wazuh-control ]; then
  /var/ossec/bin/wazuh-control stop || true

  # remove local key so a fresh registration can happen if the manager-side
  # record was deleted during container recreation
  rm -f /var/ossec/etc/client.keys || true

  /var/ossec/bin/wazuh-control start || true
  sleep 5
  /var/ossec/bin/wazuh-control status || true
  tail -n 30 /var/ossec/logs/ossec.log || true
fi
"
