#!/usr/bin/env bash
set -euo pipefail

AGENT_NAME="${1:?Usage: $0 <agent_name>}"
MANAGER_CONTAINER="${2:-single-node-wazuh.manager-1}"

echo "[remove_wazuh_agent_by_name] Looking for agent name: ${AGENT_NAME}"

AGENT_ID="$(docker exec "${MANAGER_CONTAINER}" bash -lc \
  "/var/ossec/bin/manage_agents -l" \
  | sed -n "s/.*ID: \([0-9]\+\), Name: ${AGENT_NAME},.*/\1/p" \
  | head -n 1 || true)"

if [ -z "${AGENT_ID}" ]; then
  echo "[remove_wazuh_agent_by_name] No existing Wazuh agent found for name: ${AGENT_NAME}"
  exit 0
fi

echo "[remove_wazuh_agent_by_name] Removing Wazuh agent id=${AGENT_ID} name=${AGENT_NAME}"
docker exec "${MANAGER_CONTAINER}" bash -lc "/var/ossec/bin/manage_agents -r ${AGENT_ID}"

echo "[remove_wazuh_agent_by_name] Removal completed"
