#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:?missing container name}"
TARGET_USER="${2:?missing target user}"
PUBKEY_PATH="${3:?missing public key path}"

if [ ! -f "${PUBKEY_PATH}" ]; then
  echo "[configure_ssh_authorized_key_container] Missing public key: ${PUBKEY_PATH}"
  exit 1
fi

PUBKEY_CONTENT="$(cat "${PUBKEY_PATH}")"

echo "[configure_ssh_authorized_key_container] container=${CONTAINER_NAME}"
echo "[configure_ssh_authorized_key_container] user=${TARGET_USER}"
echo "[configure_ssh_authorized_key_container] pubkey=${PUBKEY_PATH}"

docker exec "${CONTAINER_NAME}" bash -lc "
set -euo pipefail

HOME_DIR=\$(getent passwd '${TARGET_USER}' | cut -d: -f6)
if [ -z \"\${HOME_DIR}\" ]; then
  echo 'Target user not found: ${TARGET_USER}'
  exit 1
fi

mkdir -p \"\${HOME_DIR}/.ssh\"
touch \"\${HOME_DIR}/.ssh/authorized_keys\"

grep -qxF '${PUBKEY_CONTENT}' \"\${HOME_DIR}/.ssh/authorized_keys\" || \
  echo '${PUBKEY_CONTENT}' >> \"\${HOME_DIR}/.ssh/authorized_keys\"

chown -R ${TARGET_USER}:${TARGET_USER} \"\${HOME_DIR}/.ssh\"
chmod 700 \"\${HOME_DIR}/.ssh\"
chmod 600 \"\${HOME_DIR}/.ssh/authorized_keys\"
"
