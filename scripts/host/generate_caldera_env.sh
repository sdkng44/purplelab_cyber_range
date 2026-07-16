#!/usr/bin/env bash
set -euo pipefail

CALDERA_LOCAL_YML="${1:-/home/labuser/purple-lab/thirdparty/caldera/conf/local.yml}"
OUT_ENV="${2:-/home/labuser/purple-lab/generated/caldera.env}"

mkdir -p "$(dirname "$OUT_ENV")"

python3 - <<'PY' "$CALDERA_LOCAL_YML" "$OUT_ENV"
import sys
from pathlib import Path

local_yml = Path(sys.argv[1])
out_env = Path(sys.argv[2])

data = {}
for line in local_yml.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    if ':' not in line:
        continue
    k, v = line.split(':', 1)
    data[k.strip()] = v.strip()

contact_http = data.get("app.contact.http", "http://192.168.56.10:8888")

env_map = {
    "CALDERA_SERVER": contact_http,
    "CALDERA_CONTACT_HTTP": contact_http,
}

mapping = {
    "api_key_red": "CALDERA_RED_KEY",
    "api_key_blue": "CALDERA_BLUE_KEY",
}

for src, dst in mapping.items():
    if src in data:
        env_map[dst] = data[src]

out_env.write_text(
    "\n".join(f"{k}={v}" for k, v in env_map.items()) + "\n"
)
print(f"Wrote {out_env}")
PY
