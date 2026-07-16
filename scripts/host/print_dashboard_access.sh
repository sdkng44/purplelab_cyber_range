#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

CALDERA_LOCAL_YML="${BASE_DIR}/thirdparty/caldera/conf/local.yml"
CALDERA_ENV="${BASE_DIR}/generated/caldera.env"
LAB_HOST_IP="${LAB_HOST_IP:-192.168.56.10}"

WAZUH_URL="https://${LAB_HOST_IP}"
CALDERA_URL="http://${LAB_HOST_IP}:8888"

if [ -f "${CALDERA_ENV}" ]; then
  # shellcheck disable=SC1090
  source "${CALDERA_ENV}"
  CALDERA_URL="${CALDERA_SERVER:-${CALDERA_URL}}"
fi

extract_caldera_red_password() {
  [ -f "${CALDERA_LOCAL_YML}" ] || return 0
  awk '
    /^users:/ {in_users=1; next}
    in_users && /^  red:/ {in_red=1; next}
    in_red && /^    red:/ {
      sub(/^    red:[[:space:]]*/, "", $0)
      print
      exit
    }
  ' "${CALDERA_LOCAL_YML}"
}

CALDERA_RED_PASSWORD="$(extract_caldera_red_password || true)"

cat <<EOF2

==================== DASHBOARD ACCESS ====================

Wazuh Dashboard
  URL      : ${WAZUH_URL}
  User     : admin
  Password : SecretPassword

CALDERA
  URL      : ${CALDERA_URL}
  User     : red
  Password : ${CALDERA_RED_PASSWORD:-<ver conf/local.yml>}

==========================================================

EOF2
