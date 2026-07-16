#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_proxy_int] $1"
}

log "Checking Docker container status..."
docker ps | grep proxy-int-01 || true

log "Checking runtime processes inside proxy-int-01..."
docker exec proxy-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|squid|wazuh" | grep -v grep || true'

log "Checking proxy port..."
nc -zv 192.168.56.10 3128 || true

log "Generating validation traffic through proxy..."
curl -x http://192.168.56.10:3128 -sI http://192.168.56.10:8080/ >/dev/null || true

log "Checking Squid access log..."
docker exec proxy-int-01 bash -lc 'tail -n 30 /var/log/squid/access.log || true'

log "Checking Wazuh agent log..."
docker exec proxy-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
