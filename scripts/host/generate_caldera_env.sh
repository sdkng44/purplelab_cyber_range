#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

CALDERA_LOCAL_YML="${1:-${BASE_DIR}/thirdparty/caldera/conf/local.yml}"
OUT_ENV="${2:-${BASE_DIR}/generated/caldera.env}"
DEFAULT_CALDERA_URL="${DEFAULT_CALDERA_URL:-http://192.168.56.10:8888}"

mkdir -p "$(dirname "$OUT_ENV")"

python3 - <<'PY' "$CALDERA_LOCAL_YML" "$OUT_ENV" "$DEFAULT_CALDERA_URL"
import sys
from pathlib import Path
from urllib.parse import urlparse, urlunparse

local_yml = Path(sys.argv[1])
out_env = Path(sys.argv[2])
default_url = sys.argv[3]

data = {}
for line in local_yml.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    if ':' not in line:
        continue
    k, v = line.split(':', 1)
    data[k.strip()] = v.strip()

def normalize_url(raw: str, fallback: str) -> str:
    raw = (raw or "").strip()
    if not raw:
        return fallback

    parsed = urlparse(raw)
    fb = urlparse(fallback)

    if not parsed.scheme or not parsed.netloc:
        return fallback

    bad_hosts = {"0.0.0.0", "127.0.0.1", "localhost"}
    if parsed.hostname in bad_hosts:
        scheme = parsed.scheme or fb.scheme or "http"
        host = fb.hostname or "192.168.56.10"
        port = parsed.port or fb.port
        netloc = host if port is None else f"{host}:{port}"
        return urlunparse((scheme, netloc, parsed.path or "", "", "", ""))

    return raw

contact_http_raw = data.get("app.contact.http", default_url)
contact_http = normalize_url(contact_http_raw, default_url)

frontend_raw = data.get("app.frontend.api_base_url", contact_http)
frontend_url = normalize_url(frontend_raw, contact_http)

env_map = {
    "CALDERA_SERVER": contact_http,
    "CALDERA_URL": contact_http,
    "CALDERA_CONTACT_HTTP": contact_http,
    "CALDERA_FRONTEND_URL": frontend_url,
}

mapping = {
    "api_key_red": "CALDERA_RED_KEY",
    "api_key_blue": "CALDERA_BLUE_KEY",
}

for src, dst in mapping.items():
    if src in data:
        env_map[dst] = data[src]

out_env.write_text("\n".join(f"{k}={v}" for k, v in env_map.items()) + "\n")
print(f"Wrote {out_env}")
print(f"CALDERA_SERVER={contact_http}")
PY
