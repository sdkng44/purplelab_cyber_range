#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
WAZUH_DIR="${BASE_DIR}/thirdparty/wazuh-docker/single-node"
GENERATED_ENV="${BASE_DIR}/generated/caldera.env"
LOCAL_RULES="${BASE_DIR}/configs/wazuh/local_rules.xml"

FAILURES=0

pass() {
  echo "[PASS] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

check_path() {
  local path="$1"
  local label="$2"
  if [ -e "$path" ]; then
    pass "$label"
  else
    fail "$label (missing: $path)"
  fi
}

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label (command not found: $cmd)"
  fi
}

check_service_active() {
  local svc="$1"
  local label="$2"
  if systemctl is-active --quiet "$svc"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_docker_container_running() {
  local name="$1"
  local label="$2"
  if docker ps --format '{{.Names}}' | grep -qx "$name"; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_http() {
  local url="$1"
  local label="$2"
  if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

check_no_legacy_lab_control_process() {
  local paw="$1"
  local label="$2"
  if ps -ef | grep "/opt/caldera/sandcat " | grep -v grep | grep -q -- "-paw ${paw}"; then
    fail "$label"
  else
    pass "$label"
  fi
}

echo "=== Lab Control Validation ==="

check_cmd docker "Docker command available"
check_cmd curl "curl available"
check_cmd nmap "nmap available"

check_service_active docker "Docker service is active"
check_service_active caldera "Caldera service is active"
check_service_active caldera-sandcat-lab-control-emu.service "lab-control emu Sandcat service running"
check_service_active caldera-sandcat-lab-control-s13.service "lab-control s13 Sandcat service running"

check_path "$WAZUH_DIR" "Wazuh single-node directory present"
check_path "$GENERATED_ENV" "caldera.env present"
check_path "$LOCAL_RULES" "local Wazuh rules present"

check_http "http://192.168.56.10:8888" "Caldera HTTP endpoint reachable"

check_docker_container_running "single-node-wazuh.manager-1" "Wazuh manager container running"
check_docker_container_running "single-node-wazuh.indexer-1" "Wazuh indexer container running"
check_docker_container_running "single-node-wazuh.dashboard-1" "Wazuh dashboard container running"

check_no_legacy_lab_control_process "lab-control-emu" "no legacy lab-control emu Sandcat process"
check_no_legacy_lab_control_process "lab-control-s13" "no legacy lab-control s13 Sandcat process"

echo "=== Validation Summary ==="
if [ "$FAILURES" -eq 0 ]; then
  if [ -x "${BASE_DIR}/scripts/host/print_dashboard_access.sh" ]; then
  bash "${BASE_DIR}/scripts/host/print_dashboard_access.sh"
  fi
  echo "Validation successful. No failures found."
  exit 0
fi

echo "Validation completed with ${FAILURES} failure(s)."
exit 1
