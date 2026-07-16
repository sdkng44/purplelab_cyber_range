#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
ssh-keygen -A

if [ -x /usr/local/bin/start-wazuh-agent.sh ]; then
  /usr/local/bin/start-wazuh-agent.sh || true
fi

if [ -x /usr/local/bin/reset-caldera-agent-registration.sh ]; then
  /usr/local/bin/reset-caldera-agent-registration.sh || true
fi

if [ -x /usr/local/bin/start-sandcat-agent.sh ]; then
  /usr/local/bin/start-sandcat-agent.sh || true
fi

exec "$@"
