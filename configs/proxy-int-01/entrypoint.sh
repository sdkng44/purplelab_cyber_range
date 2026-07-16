#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /var/log/squid
ssh-keygen -A

exec "$@"
