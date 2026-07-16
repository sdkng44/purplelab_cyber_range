#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
RULES_FILE="${BASE_DIR}/configs/wazuh/local_rules.xml"
MANAGER_CONTAINER="single-node-wazuh.manager-1"

docker cp "${RULES_FILE}" "${MANAGER_CONTAINER}:/var/ossec/etc/rules/local_rules.xml"
docker exec "${MANAGER_CONTAINER}" bash -lc "/var/ossec/bin/wazuh-control restart || supervisorctl restart wazuh-manager"
