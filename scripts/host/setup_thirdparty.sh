#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

THIRDPARTY_DIR="${BASE_DIR}/thirdparty"
OVERLAYS_DIR="${BASE_DIR}/overlays"

CALDERA_DIR="${THIRDPARTY_DIR}/caldera"
WAZUH_DIR="${THIRDPARTY_DIR}/wazuh-docker"

CALDERA_REPO="${CALDERA_REPO:-https://github.com/mitre/caldera.git}"
WAZUH_REPO="${WAZUH_REPO:-https://github.com/wazuh/wazuh-docker.git}"

CALDERA_REF="${CALDERA_REF:-b24f6e7a99cab19cbf417009bda9b9c6c81abc31}"
WAZUH_REF="${WAZUH_REF:-4161af024f1b1f6c97c15e8425ec1b7722f6a7a8}"

RESET_THIRDPARTY="${RESET_THIRDPARTY:-no}"

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
  local recursive="${4:-no}"

  if [ "${RESET_THIRDPARTY}" = "yes" ] && [ -d "${repo_dir}" ]; then
    log "Removing existing repository for clean rebuild: ${repo_dir}"
    rm -rf "${repo_dir}"
  fi

  if [ ! -d "${repo_dir}/.git" ]; then
    if [ "${recursive}" = "yes" ]; then
      log "Cloning ${repo_url} into ${repo_dir} with submodules"
      git clone --recursive "${repo_url}" "${repo_dir}"
    else
      log "Cloning ${repo_url} into ${repo_dir}"
      git clone "${repo_url}" "${repo_dir}"
    fi
  else
    log "Repository already exists: ${repo_dir}"
  fi

  log "Fetching updates for ${repo_dir}"
  git -C "${repo_dir}" fetch --all --tags

  if [ -n "${repo_ref}" ]; then
    log "Checking out ${repo_ref} in ${repo_dir}"
    git -C "${repo_dir}" checkout "${repo_ref}"
  fi

  if [ "${recursive}" = "yes" ]; then
    log "Updating submodules for ${repo_dir}"
    git -C "${repo_dir}" submodule sync --recursive
    git -C "${repo_dir}" submodule update --init --recursive
  fi
}

apply_caldera_overlays() {
  require_path "${OVERLAYS_DIR}/caldera/plugins/purplelab"
  require_path "${CALDERA_DIR}"

  log "Applying purplelab plugin overlay"
  mkdir -p "${CALDERA_DIR}/plugins"
  rm -rf "${CALDERA_DIR}/plugins/purplelab"
  cp -a "${OVERLAYS_DIR}/caldera/plugins/purplelab" "${CALDERA_DIR}/plugins/"

  log "Rewriting repository-local paths inside copied purplelab plugin"
  grep -RIl '/home/labuser/purple-lab' "${CALDERA_DIR}/plugins/purplelab" | while read -r f; do
    sed -i "s|/home/labuser/purple-lab|${BASE_DIR}|g" "${f}"
  done || true
}

main() {
  mkdir -p "${THIRDPARTY_DIR}"

  clone_or_update_repo "${CALDERA_REPO}" "${CALDERA_DIR}" "${CALDERA_REF}" yes
  clone_or_update_repo "${WAZUH_REPO}" "${WAZUH_DIR}" "${WAZUH_REF}" no

  apply_caldera_overlays

  log "Third-party setup completed."
}

main "$@"
