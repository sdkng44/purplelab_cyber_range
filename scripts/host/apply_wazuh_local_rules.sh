#!/usr/bin/env bash
set -euo pipefail

RULES_FILE="/home/labuser/purple-lab/configs/wazuh/local_rules.xml"
MANAGER_CONTAINER="single-node-wazuh.manager-1"

docker cp "${RULES_FILE}" "${MANAGER_CONTAINER}:/var/ossec/etc/rules/local_rules.xml"
docker exec "${MANAGER_CONTAINER}" bash -lc "/var/ossec/bin/wazuh-control restart || supervisorctl restart wazuh-manager"
