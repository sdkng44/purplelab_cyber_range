#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /var/log/dnsmasq
ssh-keygen -A

exec "$@"
