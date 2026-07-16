#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"
CONFIG_DIR="${BASE_DIR}/configs/pool-node-base"
REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"
SSH_KEY_SCRIPT="${BASE_DIR}/scripts/linux/configure_ssh_authorized_key_container.sh"
LAB_ADMIN_PUBKEY="/home/labuser/.ssh/purplelab_admin_ed25519.pub"
SUPPORT_PUBKEY="/home/labuser/.ssh/purplelab_support_ed25519.pub"
POOL_SUPPORT_USER="${POOL_SUPPORT_USER:-analyst}"

CLUE_NODE_INDEX="${CLUE_NODE_INDEX:-2}"
CLUE_TARGET_NAME="${CLUE_TARGET_NAME:-user-linux-01}"
CLUE_TARGET_HOST="${CLUE_TARGET_HOST:-10.10.50.40}"
CLUE_TARGET_PORT="${CLUE_TARGET_PORT:-22}"
CLUE_TARGET_USER="${CLUE_TARGET_USER:-analyst}"
CLUE_TARGET_PASSWORD="${CLUE_TARGET_PASSWORD:-Analyst123!}"

IMAGE_NAME="${IMAGE_NAME:-purple-pool-node-base:latest}"
USER_NETWORK_NAME="${USER_NETWORK_NAME:-compose_user_net}"
CORE_NETWORK_NAME="${CORE_NETWORK_NAME:-compose_core_net}"

PREFIX="${PREFIX:-pool-node}"
START_SSH_PORT="${START_SSH_PORT:-2231}"
START_HTTP_PORT="${START_HTTP_PORT:-2301}"
START_IP_OCTET="${START_IP_OCTET:-101}"

WAZUH_MANAGER="${WAZUH_MANAGER:-192.168.56.10}"
RUN_VALIDATION="yes"
COUNT="10"

log() {
  echo "[deploy_pool_nodes] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_pool_nodes] Missing required path: $path"
    exit 1
  fi
}

validate_node() {
  local node_name="$1"

  log "Validating ${node_name}..."
  docker exec "${node_name}" bash -lc 'tail -n 20 /var/log/auth.log || true'
  docker exec "${node_name}" bash -lc 'tail -n 20 /var/log/purple-lab/lab-vuln-service.log || true'
  docker exec "${node_name}" bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-validate)
      RUN_VALIDATION="no"
      shift
      ;;
    *)
      COUNT="$1"
      shift
      ;;
  esac
done

require_path "${CONFIG_DIR}"
require_path "${REMOVE_WAZUH_AGENT_SCRIPT}"
require_path "${INSTALL_WAZUH_SCRIPT}"
require_path "${CONFIGURE_LOCALFILES_SCRIPT}"
require_path "${SSH_KEY_SCRIPT}"
require_path "${LAB_ADMIN_PUBKEY}"
require_path "${SUPPORT_PUBKEY}"

if ! docker network inspect "${USER_NETWORK_NAME}" >/dev/null 2>&1; then
  echo "[deploy_pool_nodes] Docker user network not found: ${USER_NETWORK_NAME}"
  exit 1
fi

if ! docker network inspect "${CORE_NETWORK_NAME}" >/dev/null 2>&1; then
  echo "[deploy_pool_nodes] Docker core network not found: ${CORE_NETWORK_NAME}"
  exit 1
fi

log "Building pool image..."
docker build -t "${IMAGE_NAME}" "${CONFIG_DIR}"

log "Destroying previous pool nodes..."
for i in $(seq 1 "${COUNT}"); do
  node_name="$(printf "%s-%02d" "${PREFIX}" "${i}")"
  docker rm -f "${node_name}" >/dev/null 2>&1 || true
  "${REMOVE_WAZUH_AGENT_SCRIPT}" "${node_name}" >/dev/null 2>&1 || true
done

log "Creating pool nodes..."
for i in $(seq 1 "${COUNT}"); do
  node_name="$(printf "%s-%02d" "${PREFIX}" "${i}")"
  ssh_port=$((START_SSH_PORT + i - 1))
  http_port=$((START_HTTP_PORT + i - 1))
  ip_octet=$((START_IP_OCTET + i - 1))
  node_ip="10.10.40.${ip_octet}"
  core_ip_octet=$((START_IP_OCTET + i - 1))
  node_core_ip="10.10.50.${core_ip_octet}"

  docker run -d \
    --name "${node_name}" \
    --hostname "${node_name}" \
    --restart unless-stopped \
    --network "${USER_NETWORK_NAME}" \
    --ip "${node_ip}" \
    --dns 10.10.50.50 \
    --dns-search corp.lab \
    -e CALDERA_SERVER="http://192.168.56.10:8888" \
    -e S13_GROUP="s13-flow" \
    -p "192.168.56.10:${ssh_port}:22" \
    -p "192.168.56.10:${http_port}:8081" \
    "${IMAGE_NAME}"

  docker network connect --ip "${node_core_ip}" "${CORE_NETWORK_NAME}" "${node_name}"
done

sleep 10

log "Injecting single pivot clue into one pool node..."
clue_node="$(printf "%s-%02d" "${PREFIX}" "${CLUE_NODE_INDEX}")"

docker exec -u 0 "${clue_node}" bash -lc "
mkdir -p /home/analyst/Documents
cat > /home/analyst/Documents/Field_Access_Plan.txt <<EOF
Purple Lab field note
=====================

Temporary maintenance access path observed during prior validation.

target=${CLUE_TARGET_NAME}
method=ssh
host=${CLUE_TARGET_HOST}
port=${CLUE_TARGET_PORT}
user=${CLUE_TARGET_USER}
password=${CLUE_TARGET_PASSWORD}

Note: remove after maintenance window.
EOF

chown analyst:analyst /home/analyst/Documents/Field_Access_Plan.txt
chmod 600 /home/analyst/Documents/Field_Access_Plan.txt
"

log "Installing Wazuh agents and configuring logs..."
for i in $(seq 1 "${COUNT}"); do
  node_name="$(printf "%s-%02d" "${PREFIX}" "${i}")"
  ssh_port=$((START_SSH_PORT + i - 1))

  "${INSTALL_WAZUH_SCRIPT}" "${node_name}" "${WAZUH_MANAGER}" "${node_name}" "${WAZUH_MANAGER}"

  "${CONFIGURE_LOCALFILES_SCRIPT}" \
    "${node_name}" \
    syslog:/var/log/auth.log \
    syslog:/var/log/syslog \
    syslog:/var/log/purple-lab/lab-vuln-service.log

  log "Configuring SSH authorized key on ${node_name}..."
  "${SSH_KEY_SCRIPT}" "${node_name}" analyst "${LAB_ADMIN_PUBKEY}"
  "${SSH_KEY_SCRIPT}" "${node_name}" "${POOL_SUPPORT_USER}" "${SUPPORT_PUBKEY}"

  log "Refreshing known_hosts entry for ${node_name} on port ${ssh_port}..."
  ssh-keygen -f /home/labuser/.ssh/known_hosts -R "[192.168.56.10]:${ssh_port}" >/dev/null 2>&1 || true
  ssh-keyscan -p "${ssh_port}" 192.168.56.10 >> /home/labuser/.ssh/known_hosts 2>/dev/null || true
done

sleep 15

if [ "${RUN_VALIDATION}" = "yes" ]; then
  for i in $(seq 1 "${COUNT}"); do
    node_name="$(printf "%s-%02d" "${PREFIX}" "${i}")"
    validate_node "${node_name}"
  done
fi

log "Pool deployment completed."
