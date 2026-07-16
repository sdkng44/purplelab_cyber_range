#!/usr/bin/env bash
set -euo pipefail

TARGET_CONTAINER="${1:?Usage: $0 <target_container> <format:path> [format:path ...]}"
shift

if [ "$#" -lt 1 ]; then
  echo "[configure_wazuh_localfiles_container] At least one log source must be provided"
  echo "[configure_wazuh_localfiles_container] Example: $0 db-int-01 syslog:/var/log/postgresql/postgresql.log"
  exit 1
fi

echo "[configure_wazuh_localfiles_container] target=${TARGET_CONTAINER}"
echo "[configure_wazuh_localfiles_container] sources=$*"

LOCALFILE_SPECS="$(printf '%s\n' "$@")"

docker exec -u 0 -e LOCALFILE_SPECS="${LOCALFILE_SPECS}" "${TARGET_CONTAINER}" bash -lc '
set -euo pipefail

python3 - <<'"'"'PY'"'"'
from pathlib import Path
import os
import re

cfg = Path("/var/ossec/etc/ossec.conf")
backup = Path("/var/ossec/etc/ossec.conf.bak")

if not cfg.exists():
    raise SystemExit("ossec.conf not found")

backup.write_text(cfg.read_text())
text = cfg.read_text()

specs = [s.strip() for s in os.environ["LOCALFILE_SPECS"].splitlines() if s.strip()]
changed = False

for spec in specs:
    if ":" not in spec:
        raise SystemExit(f"Invalid spec: {spec}. Expected format:path")

    log_format, location = spec.split(":", 1)
    log_format = log_format.strip()
    location = location.strip()

    if log_format not in ("syslog", "json", "postgresql_log"):
        raise SystemExit(f"Unsupported log_format: {log_format}")

    desired_block = f"""  <localfile>
    <log_format>{log_format}</log_format>
    <location>{location}</location>
  </localfile>"""

    # Replace existing block for the same location regardless of current log_format
    pattern = re.compile(
        r"<localfile>\s*"
        r"<log_format>[^<]+</log_format>\s*"
        + re.escape(f"<location>{location}</location>")
        + r"\s*</localfile>",
        re.MULTILINE
    )

    if pattern.search(text):
        new_text, count = pattern.subn(desired_block, text, count=1)
        if count > 0 and new_text != text:
            text = new_text
            changed = True
    else:
        if "</ossec_config>" not in text:
            raise SystemExit("Closing </ossec_config> tag not found")
        head, tail = text.rsplit("</ossec_config>", 1)
        text = head + desired_block + "\n</ossec_config>" + tail
        changed = True

if changed:
    cfg.write_text(text)
    print("UPDATED")
else:
    print("NO_CHANGE")
PY

echo "=== configured localfiles ==="
grep -n -A2 -B1 "postgresql.log\|app\.json\|purple-web\|access\.log\|auth\.log\|error\.log" /var/ossec/etc/ossec.conf || true

/var/ossec/bin/wazuh-control restart || true
sleep 5

echo "=== ossec.log tail ==="
tail -n 40 /var/ossec/logs/ossec.log || true
'
