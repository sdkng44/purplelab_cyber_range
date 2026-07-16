#!/usr/bin/env bash
set -euo pipefail

if [ -x /var/ossec/bin/wazuh-control ]; then
  /var/ossec/bin/wazuh-control start || true
fi
