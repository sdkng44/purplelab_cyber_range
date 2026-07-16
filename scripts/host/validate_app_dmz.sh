#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_app_dmz] $1"
}

log "Checking Docker container status..."
docker ps | grep app-dmz-01 || true

log "Checking runtime processes inside app-dmz-01..."
docker exec app-dmz-01 bash -lc 'ps aux | egrep "sshd|rsyslog|wazuh|python|gunicorn|flask|sandcat" | grep -v grep || true'

log "Checking web application reachability..."
curl -fsS http://192.168.56.10:8080/ >/dev/null && echo "[validate_app_dmz] Web app reachable" || true

log "Checking web logs..."
docker exec app-dmz-01 bash -lc 'tail -n 30 /var/log/purple-web/access.log || true'
docker exec app-dmz-01 bash -lc 'tail -n 30 /var/log/purple-web/auth.log || true'
docker exec app-dmz-01 bash -lc 'tail -n 30 /var/log/purple-web/error.log || true'
docker exec app-dmz-01 bash -lc 'tail -n 30 /var/log/purple-web/app.json || true'

log "Checking Wazuh agent log..."
docker exec app-dmz-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
