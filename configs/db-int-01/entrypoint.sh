#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /var/log/supervisor
mkdir -p /var/log/postgresql
mkdir -p /var/run/postgresql

ssh-keygen -A

PG_VER="16"
PG_CONF="/etc/postgresql/${PG_VER}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VER}/main/pg_hba.conf"
PG_LOG_FILE="/var/log/postgresql/postgresql.log"
RSYSLOG_CONF="/etc/rsyslog.d/30-postgres.conf"

touch "${PG_LOG_FILE}"
chown syslog:adm "${PG_LOG_FILE}" 2>/dev/null || chown root:adm "${PG_LOG_FILE}" || true
chmod 640 "${PG_LOG_FILE}" || true

chown -R postgres:postgres /var/run/postgresql || true
chown -R postgres:postgres /var/lib/postgresql || true

if [ -f "${PG_CONF}" ]; then
  sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "${PG_CONF}" || true
  sed -i "s/^#\?password_encryption.*/password_encryption = 'scram-sha-256'/" "${PG_CONF}" || true
  sed -i "s/^#\?logging_collector.*/logging_collector = off/" "${PG_CONF}" || true
  sed -i "s/^#\?log_destination.*/log_destination = 'syslog'/" "${PG_CONF}" || true

  grep -q "^log_connections = on" "${PG_CONF}" || echo "log_connections = on" >> "${PG_CONF}"
  grep -q "^log_disconnections = on" "${PG_CONF}" || echo "log_disconnections = on" >> "${PG_CONF}"
  grep -q "^log_hostname = on" "${PG_CONF}" || echo "log_hostname = on" >> "${PG_CONF}"
  grep -q "^log_statement = 'all'" "${PG_CONF}" || echo "log_statement = 'all'" >> "${PG_CONF}"
  grep -q "^syslog_ident = 'postgres'" "${PG_CONF}" || echo "syslog_ident = 'postgres'" >> "${PG_CONF}"
  grep -q "^syslog_facility = 'LOCAL0'" "${PG_CONF}" || echo "syslog_facility = 'LOCAL0'" >> "${PG_CONF}"
  grep -q "^log_line_prefix = '%m \[%p\] user=%u db=%d app=%a client=%r '" "${PG_CONF}" || \
    echo "log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%r '" >> "${PG_CONF}"
fi

if [ -f "${PG_HBA}" ]; then
  grep -q "host    all             all             0.0.0.0/0               scram-sha-256" "${PG_HBA}" || \
    echo "host    all             all             0.0.0.0/0               scram-sha-256" >> "${PG_HBA}"
fi

cat > "${RSYSLOG_CONF}" <<'EOF'
local0.*    /var/log/postgresql/postgresql.log
& stop
EOF

pg_ctlcluster ${PG_VER} main start || true
sleep 5

su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='dbanalyst'\"" | grep -q 1 || \
  su - postgres -c "psql -c \"CREATE ROLE dbanalyst WITH LOGIN PASSWORD 'DBAnalyst123!';\""

su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='purpledb'\"" | grep -q 1 || \
  su - postgres -c "createdb -O dbanalyst purpledb"

pg_ctlcluster ${PG_VER} main stop || true

if [ -x /usr/local/bin/start-wazuh-agent.sh ]; then
  /usr/local/bin/start-wazuh-agent.sh || true
fi

exec "$@"
