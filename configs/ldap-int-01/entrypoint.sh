#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /var/log/slapd
ssh-keygen -A

SEED_MARKER="/var/lib/ldap/.purplelab_seeded"
BOOTSTRAP_URI="ldap://127.0.0.1:1389"
BASE_DN="dc=corp,dc=lab"
ADMIN_DN="cn=admin,dc=corp,dc=lab"
ADMIN_PW="LabLdap123!"

cleanup_temp_slapd() {
  if [ -n "${SLAPD_PID:-}" ]; then
    kill "${SLAPD_PID}" >/dev/null 2>&1 || true
    wait "${SLAPD_PID}" >/dev/null 2>&1 || true
    unset SLAPD_PID
  fi
}

seed_ldap() {
  echo "[ldap-int-01] Starting temporary slapd on 127.0.0.1:1389 for bootstrap..."
  /usr/sbin/slapd -h "${BOOTSTRAP_URI}/ ldapi:///" -u openldap -g openldap -d 0 &
  SLAPD_PID=$!

  echo "[ldap-int-01] Waiting for temporary LDAP to become ready..."
  READY="no"
  for _ in $(seq 1 30); do
    if ldapsearch -x -H "${BOOTSTRAP_URI}" -b "${BASE_DN}" -D "${ADMIN_DN}" -w "${ADMIN_PW}" >/dev/null 2>&1; then
      READY="yes"
      break
    fi
    sleep 1
  done

  if [ "${READY}" != "yes" ]; then
    echo "[ldap-int-01] ERROR: Temporary LDAP did not become ready"
    cleanup_temp_slapd
    exit 1
  fi

  echo "[ldap-int-01] Checking whether seed data already exists..."
  if ldapsearch -x -H "${BOOTSTRAP_URI}" -b "${BASE_DN}" "(uid=analyst)" dn 2>/dev/null | grep -q '^dn: uid=analyst,ou=People,dc=corp,dc=lab'; then
    echo "[ldap-int-01] Seed data already present."
    touch "${SEED_MARKER}"
    cleanup_temp_slapd
    return 0
  fi

  echo "[ldap-int-01] Applying bootstrap LDIF..."
  ldapadd -x -H "${BOOTSTRAP_URI}" \
    -D "${ADMIN_DN}" \
    -w "${ADMIN_PW}" \
    -f /opt/bootstrap.ldif

  echo "[ldap-int-01] Verifying seeded entry..."
  if ldapsearch -x -H "${BOOTSTRAP_URI}" -b "${BASE_DN}" "(uid=analyst)" dn 2>/dev/null | grep -q '^dn: uid=analyst,ou=People,dc=corp,dc=lab'; then
    echo "[ldap-int-01] Seed applied successfully."
    touch "${SEED_MARKER}"
    cleanup_temp_slapd
    return 0
  fi

  echo "[ldap-int-01] ERROR: Seed verification failed"
  cleanup_temp_slapd
  exit 1
}

if [ ! -f "${SEED_MARKER}" ]; then
  seed_ldap
fi

cleanup_temp_slapd
exec "$@"
