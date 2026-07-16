#!/usr/bin/env bash
set -e

mkdir -p /var/run/sshd
mkdir -p /run/cups
mkdir -p /var/log/cups
mkdir -p /var/spool/cups-pdf

touch /var/log/cups/access_log
touch /var/log/cups/error_log
touch /var/log/cups/page_log

ssh-keygen -A

exec "$@"
