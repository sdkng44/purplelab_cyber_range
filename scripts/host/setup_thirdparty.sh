#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/home/labuser/purple-lab}"
THIRDPARTY_DIR="${BASE_DIR}/thirdparty"
OVERLAYS_DIR="${BASE_DIR}/overlays"

CALDERA_DIR="${THIRDPARTY_DIR}/caldera"
WAZUH_DIR="${THIRDPARTY_DIR}/wazuh-docker"

CALDERA_REPO="${CALDERA_REPO:-https://github.com/mitre/caldera.git}"
WAZUH_REPO="${WAZUH_REPO:-https://github.com/wazuh/wazuh-docker.git}"

# Puedes fijarlos luego con commit hashes. Si están vacíos, clona la rama por defecto.
CALDERA_REF="${CALDERA_REF:-b24f6e7a99cab19cbf417009bda9b9c6c81abc31}"
WAZUH_REF="${WAZUH_REF:-4161af024f1b1f6c97c15e8425ec1b7722f6a7a8}"

log() {
  echo "[setup_thirdparty] $1"
}

require_path() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "[setup_thirdparty] Missing required path: $path"
    exit 1
  fi
}

clone_or_update_repo() {
  local repo_url="$1"
  local repo_dir="$2"
  local repo_ref="$3"

  if [ ! -d "${repo_dir}/.git" ]; then
    log "Cloning ${repo_url} into ${repo_dir}"
    git clone "${repo_url}" "${repo_dir}"
  else
    log "Repository already exists: ${repo_dir}"
  fi

  if [ -n "${repo_ref}" ]; then
    log "Fetching updates for ${repo_dir}"
    git -C "${repo_dir}" fetch --all --tags
    log "Checking out ${repo_ref} in ${repo_dir}"
    git -C "${repo_dir}" checkout "${repo_ref}"
  fi
}

apply_caldera_overlays() {
  require_path "${OVERLAYS_DIR}/caldera/plugins/purplelab"
  require_path "${CALDERA_DIR}"

  log "Applying purplelab plugin overlay"
  mkdir -p "${CALDERA_DIR}/plugins"
  rm -rf "${CALDERA_DIR}/plugins/purplelab"
  cp -a "${OVERLAYS_DIR}/caldera/plugins/purplelab" "${CALDERA_DIR}/plugins/"
}

main() {
  mkdir -p "${THIRDPARTY_DIR}"

  clone_or_update_repo "${CALDERA_REPO}" "${CALDERA_DIR}" "${CALDERA_REF}"
  clone_or_update_repo "${WAZUH_REPO}" "${WAZUH_DIR}" "${WAZUH_REF}"

  apply_caldera_overlays

  log "Third-party setup completed."
}

main "$@"
