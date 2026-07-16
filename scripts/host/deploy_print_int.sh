#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
COMPOSE_DIR="${BASE_DIR}/compose"
INSTALL_WAZUH_SCRIPT="${BASE_DIR}/scripts/linux/install_wazuh_agent_container.sh"
CONFIGURE_LOCALFILES_SCRIPT="${BASE_DIR}/scripts/linux/configure_wazuh_localfiles_container.sh"
SSH_KEY_SCRIPT="${BASE_DIR}/scripts/linux/configure_ssh_authorized_key_container.sh"
LAB_ADMIN_PUBKEY="/home/labuser/.ssh/purplelab_admin_ed25519.pub"
TARGET_CONTAINER="print-int-01"
WAZUH_MANAGER="192.168.56.10"

log() {
  echo "[deploy_print_int] $1"
}

wait_for_container_running() {
  log "Waiting for ${TARGET_CONTAINER} to be running..."
  for _ in $(seq 1 30); do
    if [ "$(docker inspect -f '{{.State.Running}}' "${TARGET_CONTAINER}" 2>/dev/null || true)" = "true" ]; then
      return 0
    fi
    sleep 2
  done
  echo "[deploy_print_int] ${TARGET_CONTAINER} did not become ready in time."
  docker logs --tail 100 "${TARGET_CONTAINER}" || true
  exit 1
}

wait_for_cups() {
  log "Waiting for CUPS to become ready..."
  for _ in $(seq 1 30); do
    if docker exec "${TARGET_CONTAINER}" bash -lc 'lpstat -h /run/cups/cups.sock -r >/dev/null 2>&1'; then
      return 0
    fi
    sleep 2
  done
  echo "[deploy_print_int] CUPS did not become ready in time."
  docker logs --tail 100 "${TARGET_CONTAINER}" || true
  exit 1
}

bootstrap_printer_queue() {
  log "Bootstrapping printer queue..."
  docker exec "${TARGET_CONTAINER}" bash -lc '
    set -euo pipefail

    PPD="$(find /usr/share -type f \( -name "*CUPS*PDF*.ppd" -o -name "*cups-pdf*.ppd" \) | head -n1)"
    if [ -z "${PPD:-}" ]; then
      echo "[print-int-01] ERROR: Could not find a CUPS-PDF PPD file"
      exit 1
    fi

    echo "[print-int-01] Using PPD: ${PPD}"

    if ! lpstat -h /run/cups/cups.sock -p Printer-HQ-01 >/dev/null 2>&1; then
      CREATED="no"
      for _ in $(seq 1 15); do
        if lpadmin -h /run/cups/cups.sock -p Printer-HQ-01 -E -v cups-pdf:/ -P "${PPD}" >/dev/null 2>&1; then
          CREATED="yes"
          break
        fi
        sleep 2
      done

      if [ "${CREATED}" != "yes" ]; then
        echo "[print-int-01] ERROR: Could not create Printer-HQ-01 after retries"
        exit 1
      fi

      cupsenable -h /run/cups/cups.sock Printer-HQ-01 || true
      cupsaccept -h /run/cups/cups.sock Printer-HQ-01 || true
    fi

    lpstat -h /run/cups/cups.sock -p Printer-HQ-01 || true

    echo "Purple Lab deployment print test" > /tmp/deploy-print.txt
    lp -h /run/cups/cups.sock -d Printer-HQ-01 /tmp/deploy-print.txt || true
  '
}

log "Deploying print-int-01..."
cd "${COMPOSE_DIR}"
docker compose up -d --build print-int-01

wait_for_container_running
wait_for_cups
bootstrap_printer_queue

log "Installing Wazuh agent..."
"${INSTALL_WAZUH_SCRIPT}" "${TARGET_CONTAINER}" "${WAZUH_MANAGER}" "${TARGET_CONTAINER}" "${WAZUH_MANAGER}"

log "Configuring Wazuh localfiles..."
"${CONFIGURE_LOCALFILES_SCRIPT}" \
  "${TARGET_CONTAINER}" \
  syslog:/var/log/syslog \
  syslog:/var/log/auth.log \
  syslog:/var/log/cups/access_log \
  syslog:/var/log/cups/error_log \
  syslog:/var/log/cups/page_log

log "Configuring SSH authorized key for analyst..."
"${SSH_KEY_SCRIPT}" "${TARGET_CONTAINER}" analyst "${LAB_ADMIN_PUBKEY}"

log "Refreshing known_hosts entry..."
mkdir -p /home/labuser/.ssh
touch /home/labuser/.ssh/known_hosts
chmod 700 /home/labuser/.ssh
chmod 600 /home/labuser/.ssh/known_hosts
ssh-keygen -f /home/labuser/.ssh/known_hosts -R "[192.168.56.10]:2234" >/dev/null 2>&1 || true
ssh-keyscan -p 2234 192.168.56.10 >> /home/labuser/.ssh/known_hosts 2>/dev/null || true

log "Deployment completed."
