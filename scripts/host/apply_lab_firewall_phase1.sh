#!/usr/bin/env bash
set -euo pipefail

CHAIN="PURPLELAB_SEGMENTATION"

WIN_HOST_SUBNET="192.168.56.0/24"
WIN_HOST_IF="enp0s8"
CORE_SUBNET="10.10.50.0/24"
CORE_BRIDGE_IF="br-887b13974266"
APP_INT_IP="10.10.50.20"
APP_INT_PORT="8080"

ensure_rule() {
  local table="$1"
  shift
  if ! sudo iptables -t "$table" -C "$@" >/dev/null 2>&1; then
    sudo iptables -t "$table" -I "$@"
  fi
}

ensure_filter_rule() {
  if ! sudo iptables -C "$@" >/dev/null 2>&1; then
    sudo iptables -I "$@"
  fi
}

log() {
  echo "[apply_lab_firewall_phase1] $1"
}

log "Ensuring bridge netfilter support..."
sudo modprobe br_netfilter || true
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null || true

log "Ensuring IPv4 forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-purplelab-routing.conf >/dev/null

log "Adding Windows -> app-int raw PREROUTING exceptions..."
ensure_rule raw PREROUTING 1 -i "${WIN_HOST_IF}" -s "${WIN_HOST_SUBNET}" -d "${APP_INT_IP}" -p tcp --dport "${APP_INT_PORT}" -j ACCEPT
ensure_rule raw PREROUTING 2 -i "${WIN_HOST_IF}" -s "${WIN_HOST_SUBNET}" -d "${APP_INT_IP}" -p icmp -j ACCEPT

log "Adding Windows -> core forwarding/NAT rules..."
ensure_filter_rule FORWARD 1 -i "${WIN_HOST_IF}" -s "${WIN_HOST_SUBNET}" -d "${CORE_SUBNET}" -j ACCEPT
ensure_filter_rule FORWARD 2 -o "${WIN_HOST_IF}" -s "${CORE_SUBNET}" -d "${WIN_HOST_SUBNET}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ensure_rule nat POSTROUTING 1 -s "${WIN_HOST_SUBNET}" -d "${CORE_SUBNET}" -j MASQUERADE

log "Creating/refreshing chain ${CHAIN}..."
sudo iptables -N "${CHAIN}" 2>/dev/null || true
sudo iptables -F "${CHAIN}"

if ! sudo iptables -C DOCKER-USER -j "${CHAIN}" >/dev/null 2>&1; then
  sudo iptables -I DOCKER-USER 1 -j "${CHAIN}"
fi

log "Adding baseline rules..."
sudo iptables -A "${CHAIN}" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

# Only enforce traffic when BOTH source and destination are lab container subnets.
# This avoids breaking host -> published ports and container -> internet traffic.
sudo iptables -A "${CHAIN}" ! -s 10.10.0.0/16 -j RETURN
sudo iptables -A "${CHAIN}" ! -d 10.10.0.0/16 -j RETURN

# DNS for all lab containers -> dns-int-01
sudo iptables -A "${CHAIN}" -s 10.10.0.0/16 -d 10.10.50.50 -p udp --dport 53 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.0.0/16 -d 10.10.50.50 -p tcp --dport 53 -j RETURN

# app-dmz-01 -> db-int-01
sudo iptables -A "${CHAIN}" -s 10.10.30.20 -d 10.10.30.30 -p tcp --dport 5432 -j RETURN

# app-dmz-01 -> proxy-int-01
sudo iptables -A "${CHAIN}" -s 10.10.50.20 -d 10.10.50.70 -p tcp --dport 3128 -j RETURN

# user workloads -> app-dmz-01 web (public/DMZ endpoint)
sudo iptables -A "${CHAIN}" -s 10.10.40.10 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN

sudo iptables -A "${CHAIN}" -s 10.10.40.40 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN

sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.40.101-10.10.40.199 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.10.20 -p tcp --dport 8080 -j RETURN

# user workloads -> app-dmz-01 internal/core endpoint
sudo iptables -A "${CHAIN}" -s 10.10.40.10 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN

sudo iptables -A "${CHAIN}" -s 10.10.40.40 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN

sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.40.101-10.10.40.199 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.20 -p tcp --dport 8080 -j RETURN

# int-endpoint-01 -> files/proxy/ldap/print
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.50.60 -p tcp -m multiport --dports 22,445 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.50.70 -p tcp --dport 3128 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.50.80 -p tcp --dport 389 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.10 -d 10.10.50.90 -p tcp --dport 631 -j RETURN

# user-linux-01 -> files/proxy/ldap/print
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.50.60 -p tcp -m multiport --dports 22,445 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.50.70 -p tcp --dport 3128 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.50.80 -p tcp --dport 389 -j RETURN
sudo iptables -A "${CHAIN}" -s 10.10.50.40 -d 10.10.50.90 -p tcp --dport 631 -j RETURN

# pool-node-* (10.10.50.101-199) -> files/proxy/ldap/print
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.60 -p tcp -m multiport --dports 22,445 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.70 -p tcp --dport 3128 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.80 -p tcp --dport 389 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.90 -p tcp --dport 631 -j RETURN

# S13 path: app-dmz-01 -> pool-node-* over SSH (support/diagnostics abuse path)
sudo iptables -A "${CHAIN}" -s 10.10.50.20 -m iprange --dst-range 10.10.50.101-10.10.50.199 -p tcp --dport 22 -j RETURN

# S13 path: pool-node-* -> user-linux-01 over SSH
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.40.101-10.10.40.199 -d 10.10.40.40 -p tcp --dport 22 -j RETURN
sudo iptables -A "${CHAIN}" -m iprange --src-range 10.10.50.101-10.10.50.199 -d 10.10.50.40 -p tcp --dport 22 -j RETURN

# Optional: app-dmz-01 -> pool-node-* local service
sudo iptables -A "${CHAIN}" -s 10.10.50.20 -m iprange --dst-range 10.10.50.101-10.10.50.199 -p tcp --dport 8081 -j RETURN

log "Adding logging and default drop for unauthorized inter-zone traffic..."
sudo iptables -A "${CHAIN}" -m limit --limit 10/min --limit-burst 20 -j LOG --log-prefix "PURPLELAB_DROP " --log-level 4
sudo iptables -A "${CHAIN}" -j DROP

log "Raw PREROUTING exceptions:"
sudo iptables -t raw -S PREROUTING | grep -E "${APP_INT_IP}|${WIN_HOST_SUBNET}" || true

log "FORWARD exceptions:"
sudo iptables -S FORWARD | grep -E "${WIN_HOST_SUBNET}|${CORE_SUBNET}" || true

log "NAT exceptions:"
sudo iptables -t nat -S POSTROUTING | grep -E "${WIN_HOST_SUBNET}|${CORE_SUBNET}" || true

log "Current ${CHAIN} rules:"
sudo iptables -S "${CHAIN}"
log "Firewall phase 1 applied successfully."
