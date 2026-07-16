#!/usr/bin/env bash
set -euo pipefail

CHAIN="PURPLELAB_SEGMENTATION"

echo "[remove_lab_firewall_phase1] Removing ${CHAIN} from DOCKER-USER if present..."
sudo iptables -D DOCKER-USER -j "${CHAIN}" 2>/dev/null || true

echo "[remove_lab_firewall_phase1] Flushing and deleting ${CHAIN}..."
sudo iptables -F "${CHAIN}" 2>/dev/null || true
sudo iptables -X "${CHAIN}" 2>/dev/null || true

echo "[remove_lab_firewall_phase1] Done."
