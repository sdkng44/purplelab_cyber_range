#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

CALDERA_DIR="${BASE_DIR}/thirdparty/caldera"
WAZUH_DIR="${BASE_DIR}/thirdparty/wazuh-docker/single-node"
CALDERA_VENV="${CALDERA_DIR}/.venv"
CALDERA_SERVICE_FILE="/etc/systemd/system/caldera.service"
SETUP_THIRDPARTY_SCRIPT="${BASE_DIR}/scripts/host/setup_thirdparty.sh"

LAB_USER="${LAB_USER:-labuser}"
LAB_GROUP="${LAB_GROUP:-labuser}"

log() {
  echo "[provision_lab_control] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[provision_lab_control] Missing required path: $path"
    exit 1
  fi
}

install_apt_packages() {
  log "Installing required host packages..."
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq \
    unzip \
    build-essential \
    libffi-dev \
    libssl-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    golang-go \
    hydra \
    sshpass \
    nmap
}

install_docker_stack() {
  log "Ensuring Docker engine and Compose are available..."

  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found. Installing docker.io from Ubuntu packages..."
    sudo apt-get install -y docker.io
  else
    log "Docker command already present. Skipping Docker engine installation."
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin not found. Trying to install it..."
    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      sudo apt-get install -y docker-compose-v2 || true
    fi
    if ! docker compose version >/dev/null 2>&1; then
      if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        sudo apt-get install -y docker-compose-plugin || true
      fi
    fi
  else
    log "Docker Compose already available."
  fi

  sudo systemctl enable docker >/dev/null 2>&1 || true
  sudo systemctl start docker

  if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "${LAB_USER}" || true
  fi
}

prepare_directories() {
  log "Preparing laboratory directories..."
  mkdir -p "${BASE_DIR}/generated" "${BASE_DIR}/results" "${BASE_DIR}/evidence" "${BASE_DIR}/thirdparty"
}

setup_thirdparty() {
  log "Setting up third-party repositories..."
  require_path "${SETUP_THIRDPARTY_SCRIPT}"
  bash "${SETUP_THIRDPARTY_SCRIPT}"
}

ensure_wazuh_indexer_certs() {
  local single_node_dir="${BASE_DIR}/thirdparty/wazuh-docker/single-node"
  local certs_dir="${single_node_dir}/config/wazuh_indexer_ssl_certs"
  local certs_compose="${single_node_dir}/generate-indexer-certs.yml"
  local certs_yml="${single_node_dir}/config/certs.yml"

  log "Ensuring Wazuh indexer certificates exist..."

  require_path "${single_node_dir}"
  require_path "${certs_compose}"
  require_path "${certs_yml}"

  mkdir -p "${certs_dir}"

  find "${certs_dir}" -maxdepth 1 -mindepth 1 -type d \( -name '*.pem' -o -name '*-key.pem' \) -exec rm -rf {} + || true

  if [ -f "${certs_dir}/admin.pem" ] && \
     [ -f "${certs_dir}/admin-key.pem" ] && \
     [ -f "${certs_dir}/root-ca.pem" ] && \
     [ -f "${certs_dir}/wazuh.indexer.pem" ] && \
     [ -f "${certs_dir}/wazuh.indexer-key.pem" ] && \
     [ -f "${certs_dir}/wazuh.manager.pem" ] && \
     [ -f "${certs_dir}/wazuh.manager-key.pem" ] && \
     [ -f "${certs_dir}/wazuh.dashboard.pem" ] && \
     [ -f "${certs_dir}/wazuh.dashboard-key.pem" ]; then
    log "Wazuh certificates already present. Skipping generation."
    return 0
  fi

  log "Generating self-signed Wazuh certificates..."
  (
    cd "${single_node_dir}"
    docker compose -f generate-indexer-certs.yml run --rm generator
  )

  [ -f "${certs_dir}/root-ca.pem" ] || { echo "[provision_lab_control] missing root-ca.pem"; exit 1; }
  [ -f "${certs_dir}/admin.pem" ] || { echo "[provision_lab_control] missing admin.pem"; exit 1; }

  log "Wazuh certificate generation completed."
}

prepare_caldera_venv() {
  log "Preparing Caldera Python virtual environment..."
  require_path "${CALDERA_DIR}"
  require_path "${CALDERA_DIR}/requirements.txt"

  if [ -d "${CALDERA_VENV}" ]; then
    rm -rf "${CALDERA_VENV}"
  fi

  python3 -m venv "${CALDERA_VENV}"

  "${CALDERA_VENV}/bin/pip" install --upgrade pip setuptools wheel
  "${CALDERA_VENV}/bin/pip" install -r "${CALDERA_DIR}/requirements.txt"
  "${CALDERA_VENV}/bin/pip" install docker
}

write_caldera_service() {
  log "Writing Caldera systemd service..."
  sudo tee "${CALDERA_SERVICE_FILE}" >/dev/null <<EOF2
[Unit]
Description=Apache Caldera
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=${LAB_USER}
Group=${LAB_GROUP}
WorkingDirectory=${CALDERA_DIR}
Environment="PATH=${CALDERA_VENV}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=${CALDERA_VENV}/bin/python ${CALDERA_DIR}/server.py --build
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF2

  sudo systemctl daemon-reload
  sudo systemctl enable caldera >/dev/null 2>&1 || true
}

verify_prerequisites() {
  log "Verifying repository structure..."
  require_path "${BASE_DIR}"
  require_path "${SETUP_THIRDPARTY_SCRIPT}"
}

main() {
  verify_prerequisites
  prepare_directories
  install_apt_packages
  install_docker_stack
  setup_thirdparty
  ensure_wazuh_indexer_certs
  prepare_caldera_venv
  write_caldera_service

  log "Provisioning completed successfully."
  log "Next step: run ${BASE_DIR}/scripts/host/ensure_full_lab.sh --pool-count 3"
}

main "$@"
