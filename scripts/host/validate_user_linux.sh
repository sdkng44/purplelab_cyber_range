#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_user_linux] $1"
}

log "Checking Docker container status..."
docker ps | grep user-linux-01 || true

log "Checking runtime processes inside user-linux-01..."
docker exec user-linux-01 bash -lc 'ps aux | egrep "sshd|rsyslog|wazuh|sandcat" | grep -v grep || true'

log "Checking SSH reachability with administrative key..."
if ssh -i /home/labuser/.ssh/purplelab_admin_ed25519 \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=5 \
  -p 2226 analyst@192.168.56.10 exit 2>/dev/null; then
  echo "[PASS] SSH key-based access works"
else
  echo "[FAIL] SSH key-based access not configured or not working"
  exit 1
fi

log "Checking auth.log..."
docker exec user-linux-01 bash -lc 'tail -n 30 /var/log/auth.log || true'

log "Checking Wazuh agent log..."
docker exec user-linux-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
