#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /var/log/supervisor
mkdir -p /var/log/purple-web
mkdir -p /opt/purple-web

ssh-keygen -A

if [ -x /usr/local/bin/start-wazuh-agent.sh ]; then
  /usr/local/bin/start-wazuh-agent.sh || true
fi

exec "$@"
