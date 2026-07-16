#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
ENABLE_PURPLELAB_SCRIPT="${BASE_DIR}/scripts/host/enable_caldera_purplelab.sh"
WAZUH_DIR="${BASE_DIR}/thirdparty/wazuh-docker/single-node"
CALDERA_DIR="${BASE_DIR}/thirdparty/caldera"
CALDERA_LOCAL_YML="${CALDERA_DIR}/conf/local.yml"
GENERATE_ENV_SCRIPT="${BASE_DIR}/scripts/host/generate_caldera_env.sh"
GENERATED_ENV="${BASE_DIR}/generated/caldera.env"
APPLY_WAZUH_RULES_SCRIPT="${BASE_DIR}/scripts/host/apply_wazuh_local_rules.sh"
INSTALL_SANDCAT_LAB_CONTROL_SERVICE_SCRIPT="${BASE_DIR}/scripts/linux/install_sandcat_lab_control_service.sh"

log() {
  echo "[bootstrap_lab_control] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[bootstrap_lab_control] Missing required path: $path"
    exit 1
  fi
}

install_host_dependencies() {
  local missing=()

  command -v curl >/dev/null 2>&1 || missing+=("curl")
  command -v hydra >/dev/null 2>&1 || missing+=("hydra")
  command -v sshpass >/dev/null 2>&1 || missing+=("sshpass")
  command -v nmap >/dev/null 2>&1 || missing+=("nmap")

  if [ "${#missing[@]}" -eq 0 ]; then
    log "All required host dependencies are already installed."
    return 0
  fi

  log "Installing missing host dependencies: ${missing[*]}"
  sudo apt-get update
  sudo apt-get install -y "${missing[@]}"
}

ensure_lab_admin_ssh_key() {
  local ssh_dir="/home/labuser/.ssh"
  local key_path="${ssh_dir}/purplelab_admin_ed25519"

  log "Ensuring lab-control administrative SSH key exists..."

  mkdir -p "${ssh_dir}"
  chmod 700 "${ssh_dir}"

  if [ ! -f "${key_path}" ]; then
    ssh-keygen -t ed25519 -N "" \
      -f "${key_path}" \
      -C "purplelab-admin"
  fi

  chmod 600 "${key_path}"
  chmod 644 "${key_path}.pub"
}

ensure_support_ssh_key() {
  local ssh_dir="/home/labuser/.ssh"
  local key_path="${ssh_dir}/purplelab_support_ed25519"

  log "Ensuring lab-control support SSH key exists..."

  mkdir -p "${ssh_dir}"
  chmod 700 "${ssh_dir}"

  if [ ! -f "${key_path}" ]; then
    ssh-keygen -t ed25519 -N "" \
      -f "${key_path}" \
      -C "purplelab-support"
  fi

  chmod 600 "${key_path}"
  chmod 644 "${key_path}.pub"
}

wait_for_caldera_local_config() {
  log "Waiting for Caldera local.yml to exist..."
  for _ in $(seq 1 30); do
    if [ -f "${CALDERA_LOCAL_YML}" ]; then
      return 0
    fi
    sleep 10
  done

  echo "[bootstrap_lab_control] Caldera local.yml was not created in time: ${CALDERA_LOCAL_YML}"
  exit 1
}

wait_for_caldera_http() {
  local caldera_server="$1"

  log "Waiting for Caldera HTTP service..."
  for _ in $(seq 1 30); do
    local code
    code="$(curl -s -o /dev/null -w "%{http_code}" "${caldera_server}" || true)"
    if [ "${code}" = "200" ] || [ "${code}" = "302" ] || [ "${code}" = "405" ]; then
      return 0
    fi
    sleep 10
  done

  echo "[bootstrap_lab_control] Caldera HTTP service did not become ready: ${caldera_server}"
  exit 1
}

cleanup_legacy_lab_control_sandcats() {
  log "Cleaning up legacy lab-control Sandcat processes if present..."

  sudo pkill -f "/opt/caldera/sandcat -server .* -group emu -paw lab-control-emu" || true
  sudo pkill -f "/opt/caldera/sandcat -server .* -group s13-flow -paw lab-control-s13" || true
}

log "Checking required paths..."
require_path "${BASE_DIR}"
require_path "${ENABLE_PURPLELAB_SCRIPT}"
require_path "${WAZUH_DIR}"
require_path "${CALDERA_DIR}"
require_path "${GENERATE_ENV_SCRIPT}"
require_path "${APPLY_WAZUH_RULES_SCRIPT}"
require_path "${INSTALL_SANDCAT_LAB_CONTROL_SERVICE_SCRIPT}"

mkdir -p "${BASE_DIR}/generated" "${BASE_DIR}/results" "${BASE_DIR}/evidence"

install_host_dependencies
ensure_lab_admin_ssh_key
ensure_support_ssh_key

log "Ensuring Docker service is enabled and running..."
sudo systemctl enable docker >/dev/null 2>&1 || true
sudo systemctl start docker

log "Starting Wazuh single-node stack..."
cd "${WAZUH_DIR}"
docker compose up -d

log "Ensuring Caldera service is enabled and running..."
sudo systemctl enable caldera >/dev/null 2>&1 || true
sudo systemctl start caldera

wait_for_caldera_local_config

log "Ensuring purplelab plugin is enabled in Caldera local.yml..."
bash "${ENABLE_PURPLELAB_SCRIPT}"

log "Restarting Caldera to load purplelab plugin..."
sudo systemctl restart caldera


log "Generating lab environment variables from Caldera local.yml..."
"${GENERATE_ENV_SCRIPT}" "${CALDERA_LOCAL_YML}" "${GENERATED_ENV}"

if [ ! -f "${GENERATED_ENV}" ]; then
  echo "[bootstrap_lab_control] Failed to generate ${GENERATED_ENV}"
  exit 1
fi

set -a
source "${GENERATED_ENV}"
set +a

if [ -z "${CALDERA_SERVER:-}" ]; then
  echo "[bootstrap_lab_control] CALDERA_SERVER is not defined in ${GENERATED_ENV}"
  exit 1
fi

wait_for_caldera_http "${CALDERA_SERVER}"

log "Applying Wazuh local rules..."
bash "${APPLY_WAZUH_RULES_SCRIPT}"

log "Ensuring lab-control emu Sandcat service is installed..."
"${INSTALL_SANDCAT_LAB_CONTROL_SERVICE_SCRIPT}" "${CALDERA_SERVER}" "emu" "lab-control-emu"

log "Ensuring lab-control s13 Sandcat service is installed..."
"${INSTALL_SANDCAT_LAB_CONTROL_SERVICE_SCRIPT}" "${CALDERA_SERVER}" "s13-flow" "lab-control-s13"

cleanup_legacy_lab_control_sandcats

log "Bootstrap completed successfully."
log "Generated environment file: ${GENERATED_ENV}"
