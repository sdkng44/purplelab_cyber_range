#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/labuser/purple-lab"
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
  log "Installing Docker packages if needed..."

  if ! dpkg -s docker.io >/dev/null 2>&1; then
    sudo apt-get install -y docker.io
  fi

  if ! docker compose version >/dev/null 2>&1; then
    if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
      sudo apt-get install -y docker-compose-v2 || true
    fi
    if ! docker compose version >/dev/null 2>&1; then
      if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        sudo apt-get install -y docker-compose-plugin || true
      fi
    fi
  fi

  sudo systemctl enable docker >/dev/null 2>&1 || true
  sudo systemctl start docker

  if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "${LAB_USER}" || true
  fi
}

prepare_directories() {
  log "Preparing laboratory directories..."
  mkdir -p "${BASE_DIR}/generated" "${BASE_DIR}/results" "${BASE_DIR}/evidence"
  mkdir -p "${BASE_DIR}/scripts/host" "${BASE_DIR}/scripts/linux"
  mkdir -p "${BASE_DIR}/configs" "${BASE_DIR}/thirdparty"
}

setup_thirdparty() {
  log "Setting up third-party repositories..."
  require_path "${SETUP_THIRDPARTY_SCRIPT}"
  bash "${SETUP_THIRDPARTY_SCRIPT}"
}

prepare_caldera_venv() {
  log "Preparing Caldera Python virtual environment..."
  require_path "${CALDERA_DIR}"
  require_path "${CALDERA_DIR}/requirements.txt"

  if [ ! -d "${CALDERA_VENV}" ]; then
    python3 -m venv "${CALDERA_VENV}"
  fi

  "${CALDERA_VENV}/bin/pip" install --upgrade pip setuptools wheel
  "${CALDERA_VENV}/bin/pip" install -r "${CALDERA_DIR}/requirements.txt"
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
  prepare_caldera_venv
  write_caldera_service

  log "Provisioning completed successfully."
  log "Next step: run ${BASE_DIR}/scripts/host/ensure_full_lab.sh --pool-count 3"
}

main "$@"
