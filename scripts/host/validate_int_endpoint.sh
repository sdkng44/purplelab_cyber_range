#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_int_endpoint] $1"
}

log "Checking Docker container status..."
docker ps | grep int-endpoint-01 || true

log "Checking runtime processes inside int-endpoint-01..."
docker exec int-endpoint-01 bash -lc 'ps aux | egrep "sshd|rsyslog|wazuh|sandcat" | grep -v grep || true'

log "Checking SSH authentication log..."
docker exec int-endpoint-01 bash -lc 'tail -n 30 /var/log/auth.log || true'

log "Checking Wazuh agent log..."
docker exec int-endpoint-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Checking Sandcat log..."
docker exec int-endpoint-01 bash -lc 'tail -n 30 /var/log/sandcat.log || true'

log "Validation completed."
