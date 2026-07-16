#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_dns_int] $1"
}

log "Checking Docker container status..."
docker ps | grep dns-int-01 || true

log "Checking runtime processes inside dns-int-01..."
docker exec dns-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|dnsmasq|wazuh" | grep -v grep || true'

log "Checking DNS resolution..."
dig +short @192.168.56.10 app.corp.lab || true
dig +short @192.168.56.10 files.corp.lab || true
dig +short @192.168.56.10 db.corp.lab || true

log "Checking dnsmasq log..."
docker exec dns-int-01 bash -lc 'tail -n 30 /var/log/dnsmasq/dnsmasq.log || true'

log "Checking Wazuh agent log..."
docker exec dns-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
