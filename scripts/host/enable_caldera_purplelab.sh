#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
CALDERA_DIR="${CALDERA_DIR:-${BASE_DIR}/thirdparty/caldera}"
LOCAL_YML="${CALDERA_DIR}/conf/local.yml"

log() {
  echo "[enable_caldera_purplelab] $1"
}

if [ ! -f "${LOCAL_YML}" ]; then
  echo "[enable_caldera_purplelab] Missing local.yml: ${LOCAL_YML}"
  exit 1
fi

python3 - "${LOCAL_YML}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
data = yaml.safe_load(path.read_text()) or {}

plugins = data.get("plugins") or []
if "purplelab" not in plugins:
    plugins.append("purplelab")
data["plugins"] = plugins

data["objects.planners.default"] = "atomic"

path.write_text(yaml.safe_dump(data, sort_keys=False))
PY

log "purplelab plugin ensured in ${LOCAL_YML}"
