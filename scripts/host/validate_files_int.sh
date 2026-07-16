#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_files_int] $1"
}

log "Checking Docker container status..."
docker ps | grep files-int-01 || true

log "Checking runtime processes inside files-int-01..."
docker exec files-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|smbd|wazuh" | grep -v grep || true'

log "Checking SMB port..."
nc -zv 192.168.56.10 445 || true

log "Checking share contents..."
docker exec files-int-01 bash -lc 'ls -l /srv/shares/corp || true'

log "Checking Samba log..."
docker exec files-int-01 bash -lc 'tail -n 30 /var/log/samba/log.smbd || true'

log "Checking Wazuh agent log..."
docker exec files-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
