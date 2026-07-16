#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/home/labuser/purple-lab}"
ENV_FILE="${ENV_FILE:-${BASE_DIR}/generated/caldera.env}"

if [ -f "${ENV_FILE}" ]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

CALDERA_SERVER="${1:-${CALDERA_SERVER:-http://192.168.56.10:8888}}"
SANDCAT_GROUP="${2:?missing sandcat group}"
SANDCAT_PAW="${3:?missing sandcat paw}"

SERVICE_NAME="caldera-sandcat-${SANDCAT_PAW}.service"
BINARY_PATH="/opt/caldera/sandcat-${SANDCAT_PAW}"
TMP_BINARY_PATH="/tmp/sandcat-${SANDCAT_PAW}.tmp"
LOG_PATH="/var/log/sandcat-${SANDCAT_PAW}.log"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}"

echo "[install_sandcat_lab_control_service] server=${CALDERA_SERVER}"
echo "[install_sandcat_lab_control_service] group=${SANDCAT_GROUP}"
echo "[install_sandcat_lab_control_service] paw=${SANDCAT_PAW}"

sudo mkdir -p /opt/caldera
sudo touch "${LOG_PATH}"
sudo chmod 644 "${LOG_PATH}"

if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  echo "[install_sandcat_lab_control_service] stopping existing service ${SERVICE_NAME}..."
  sudo systemctl stop "${SERVICE_NAME}" || true
fi

echo "[install_sandcat_lab_control_service] downloading sandcat to temporary path..."
curl -fsSL -X POST \
  -H 'file:sandcat.go' \
  -H 'platform:linux' \
  "${CALDERA_SERVER}/file/download" \
  -o "${TMP_BINARY_PATH}"

sudo mv "${TMP_BINARY_PATH}" "${BINARY_PATH}"
sudo chmod +x "${BINARY_PATH}"

sudo tee "${UNIT_PATH}" >/dev/null <<UNIT
[Unit]
Description=CALDERA Sandcat (${SANDCAT_PAW})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BINARY_PATH} -server ${CALDERA_SERVER} -group ${SANDCAT_GROUP} -paw ${SANDCAT_PAW} -v
Restart=always
RestartSec=5
StandardOutput=append:${LOG_PATH}
StandardError=append:${LOG_PATH}

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
sudo systemctl status "${SERVICE_NAME}" --no-pager || true
