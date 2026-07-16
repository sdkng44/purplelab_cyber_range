#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_ldap_int] $1"
}

log "Checking Docker container status..."
docker ps | grep ldap-int-01 || true

log "Checking runtime processes inside ldap-int-01..."
docker exec ldap-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|slapd|wazuh" | grep -v grep || true'

log "Checking LDAP port..."
nc -zv 192.168.56.10 389 || true

log "Checking LDAP query..."
LDAP_OUTPUT="$(docker exec ldap-int-01 bash -lc \
  'ldapsearch -x -H ldap://127.0.0.1:389 -b dc=corp,dc=lab "(uid=analyst)" dn 2>/dev/null' || true)"

echo "${LDAP_OUTPUT}"

if echo "${LDAP_OUTPUT}" | grep -q '^dn: uid=analyst,ou=People,dc=corp,dc=lab'; then
  echo "[validate_ldap_int] LDAP seed entry found."
else
  echo "[validate_ldap_int] LDAP seed entry NOT found."
  exit 1
fi

log "Checking slapd logs..."
docker exec ldap-int-01 bash -lc 'tail -n 30 /var/log/supervisor/slapd.out.log || true'
docker exec ldap-int-01 bash -lc 'tail -n 30 /var/log/supervisor/slapd.err.log || true'

log "Checking Wazuh agent log..."
docker exec ldap-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
