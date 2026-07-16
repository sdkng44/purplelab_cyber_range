#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_db_int] $1"
}

log "Checking Docker container status..."
docker ps | grep db-int-01 || true

log "Checking runtime processes inside db-int-01..."
docker exec db-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|wazuh|postgres|sandcat" | grep -v grep || true'

log "Checking PostgreSQL service reachability..."
docker exec db-int-01 bash -lc 'pg_isready -U postgres || true'

log "Checking PostgreSQL log..."
docker exec db-int-01 bash -lc 'tail -n 40 /var/log/postgresql/postgresql.log || true'

log "Checking Wazuh agent log..."
docker exec db-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
