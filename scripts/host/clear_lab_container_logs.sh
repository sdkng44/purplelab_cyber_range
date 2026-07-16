#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

log() {
  echo "[clear_lab_container_logs] $1"
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$1"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

truncate_docker_json_log() {
  local name="$1"
  local cid
  cid="$(docker inspect -f '{{.Id}}' "$name" 2>/dev/null || true)"
  if [ -n "${cid}" ] && [ -f "/var/lib/docker/containers/${cid}/${cid}-json.log" ]; then
    sudo truncate -s 0 "/var/lib/docker/containers/${cid}/${cid}-json.log" || true
  fi
}

clear_logs_in_container() {
  local name="$1"

  log "Clearing logs inside ${name}..."

  docker exec -u 0 "${name}" bash -lc '
set +e

# Logs comunes
for f in \
  /var/log/auth.log \
  /var/log/syslog \
  /var/log/messages \
  /var/log/daemon.log \
  /var/log/dpkg.log \
  /var/log/lastlog \
  /var/log/wtmp \
  /var/log/btmp \
  /var/log/faillog \
  /var/log/sandcat.log
do
  [ -e "$f" ] && truncate -s 0 "$f" || true
done

# App DMZ
for f in \
  /var/log/purple-web/access.log \
  /var/log/purple-web/auth.log \
  /var/log/purple-web/error.log \
  /var/log/purple-web/app.json \
  /var/log/sandcat-app-dmz-01-s13.log
do
  [ -e "$f" ] && truncate -s 0 "$f" || true
done

# Pool / lab services
for f in \
  /var/log/purple-lab/lab-vuln-service.log
do
  [ -e "$f" ] && truncate -s 0 "$f" || true
done

# Wazuh agent logs
if [ -d /var/ossec/logs ]; then
  find /var/ossec/logs -type f -exec truncate -s 0 {} \; 2>/dev/null || true
fi

# DNS / LDAP / Proxy / Print / Samba
for f in \
  /var/log/slapd.log \
  /var/log/dnsmasq.log \
  /var/log/squid/access.log \
  /var/log/cups/access_log \
  /var/log/cups/error_log \
  /var/log/samba/log.smbd \
  /var/log/samba/log.nmbd
do
  [ -e "$f" ] && truncate -s 0 "$f" || true
done

# Logs de sandcat en ~/.caldera si existen
find /home -path "*/.caldera/logs/*" -type f -exec truncate -s 0 {} \; 2>/dev/null || true

# Limpieza amplia pero segura dentro de /var/log
find /var/log -type f \
  \( -name "*.log" -o -name "*.json" -o -name "syslog" -o -name "messages" -o -name "auth.log" -o -name "daemon.log" -o -name "error_log" -o -name "access_log" \) \
  -exec truncate -s 0 {} \; 2>/dev/null || true
'
}

main() {
  local containers=(
    int-endpoint-01
    app-dmz-01
    db-int-01
    user-linux-01
    dns-int-01
    files-int-01
    proxy-int-01
    ldap-int-01
    print-int-01
  )

  while read -r name; do
    [ -n "${name}" ] && containers+=("${name}")
  done < <(docker ps -a --format '{{.Names}}' | grep -E '^pool-node-[0-9]+$' || true)

  for name in "${containers[@]}"; do
    if ! container_exists "${name}"; then
      log "Skipping ${name}: container does not exist."
      continue
    fi

    if container_running "${name}"; then
      clear_logs_in_container "${name}"
    else
      log "Skipping in-container cleanup for ${name}: container is stopped."
    fi

    truncate_docker_json_log "${name}"
  done

  log "Container log cleanup completed."
  log "Suggested next step: ${BASE_DIR}/scripts/host/bootstrap_lab_control.sh"
}

main "$@"
