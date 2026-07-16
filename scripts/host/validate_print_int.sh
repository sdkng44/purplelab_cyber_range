#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[validate_print_int] $1"
}

log "Checking Docker container status..."
docker ps | grep print-int-01 || true

log "Checking runtime processes inside print-int-01..."
docker exec print-int-01 bash -lc 'ps aux | egrep "sshd|rsyslog|cupsd|wazuh" | grep -v grep || true'

log "Checking CUPS port..."
nc -zv 192.168.56.10 631 || true

log "Checking printer queues..."
PRINTER_OUTPUT="$(docker exec print-int-01 bash -lc 'lpstat -h /run/cups/cups.sock -p -d 2>/dev/null' || true)"
echo "${PRINTER_OUTPUT}"

if echo "${PRINTER_OUTPUT}" | grep -q 'Printer-HQ-01'; then
  echo "[validate_print_int] Printer queue found."
else
  echo "[validate_print_int] Printer queue NOT found."
  exit 1
fi

log "Generating validation print job..."
docker exec print-int-01 bash -lc 'echo "Purple Lab validation print job" > /tmp/validate-print.txt && lp -h /run/cups/cups.sock -d Printer-HQ-01 /tmp/validate-print.txt || true'

log "Checking generated PDF output..."
docker exec print-int-01 bash -lc 'find /var/spool/cups-pdf -type f 2>/dev/null | tail -n 10 || true'

log "Checking CUPS logs..."
docker exec print-int-01 bash -lc 'tail -n 30 /var/log/cups/access_log || true'
docker exec print-int-01 bash -lc 'tail -n 30 /var/log/cups/error_log || true'
docker exec print-int-01 bash -lc 'tail -n 30 /var/log/cups/page_log || true'

log "Checking Wazuh agent log..."
docker exec print-int-01 bash -lc 'tail -n 30 /var/ossec/logs/ossec.log || true'

log "Validation completed."
