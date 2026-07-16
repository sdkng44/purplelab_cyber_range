#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
COMPOSE_DIR="${BASE_DIR}/compose"
GENERATED_ENV="${BASE_DIR}/generated/caldera.env"

VALIDATE_SCRIPT="${BASE_DIR}/scripts/host/validate_int_endpoint.sh"
REMOVE_WAZUH_AGENT_SCRIPT="${BASE_DIR}/scripts/host/remove_wazuh_agent_by_name.sh"

INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
INSTALL_SANDCAT_SCRIPT="${BASE_DIR}/scripts/linux/install_sandcat_int_endpoint.sh"

TARGET_CONTAINER="int-endpoint-01"
WAZUH_AGENT_NAME="int-endpoint-01"
SANDCAT_GROUP="red"
SANDCAT_PAW="int-endpoint-01"

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
  echo "[deploy_int_endpoint] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[deploy_int_endpoint] Missing required path: $path"
    exit 1
  fi
}

log "Checking required paths..."
require_path "${COMPOSE_DIR}"
require_path "${GENERATED_ENV}"
require_path "${REMOVE_WAZUH_AGENT_SCRIPT}"
require_path "${INSTALL_WAZUH_SCRIPT}"
require_path "${INSTALL_SANDCAT_SCRIPT}"

log "Loading generated environment variables..."
set -a
source "${GENERATED_ENV}"
set +a

if [ -z "${CALDERA_SERVER:-}" ]; then
  echo "[deploy_int_endpoint] CALDERA_SERVER is not defined in ${GENERATED_ENV}"
  exit 1
fi

log "Stopping and removing previous container if present..."
cd "${COMPOSE_DIR}"
docker compose stop "${TARGET_CONTAINER}" || true
docker rm -f "${TARGET_CONTAINER}" || true

log "Removing previous Wazuh agent entry if present..."
"${REMOVE_WAZUH_AGENT_SCRIPT}" "${WAZUH_AGENT_NAME}" || true

log "Building and starting ${TARGET_CONTAINER}..."
docker compose up -d --build "${TARGET_CONTAINER}"

log "Waiting for container runtime initialization..."
sleep 6

log "Installing Wazuh agent on ${TARGET_CONTAINER}..."
"${INSTALL_WAZUH_SCRIPT}" "${TARGET_CONTAINER}" "192.168.56.10" "${WAZUH_AGENT_NAME}" "192.168.56.10"

log "Installing Sandcat agent on ${TARGET_CONTAINER}..."
"${INSTALL_SANDCAT_SCRIPT}" "${TARGET_CONTAINER}" "${CALDERA_SERVER}" "${SANDCAT_GROUP}" "${SANDCAT_PAW}"

log "Waiting for agents to stabilize..."
sleep 10

if [ "${RUN_VALIDATION}" = "yes" ]; then
  require_path "${VALIDATE_SCRIPT}"
  log "Running validation..."
  "${VALIDATE_SCRIPT}" || true
fi

log "Deployment completed."
