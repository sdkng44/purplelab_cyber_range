#!/usr/bin/env bash
set -euo pipefail

CALDERA_DIR="${CALDERA_DIR:-/home/labuser/purple-lab/thirdparty/caldera}"
LOCAL_YML="${CALDERA_DIR}/conf/local.yml"

log() {
  echo "[enable_caldera_purplelab] $1"
}

if [ ! -f "${LOCAL_YML}" ]; then
  echo "[enable_caldera_purplelab] Missing local.yml: ${LOCAL_YML}"
  exit 1
fi

if ! grep -Eq '^[[:space:]]*-[[:space:]]*purplelab[[:space:]]*$' "${LOCAL_YML}"; then
  tmp="$(mktemp)"
  awk '
    BEGIN { inserted=0 }
    {
      print
      if ($0 ~ /^plugins:[[:space:]]*$/ && inserted==0) {
        print "  - purplelab"
        inserted=1
      }
    }
    END {
      if (inserted==0) {
        print ""
        print "plugins:"
        print "  - purplelab"
      }
    }
  ' "${LOCAL_YML}" > "${tmp}"
  mv "${tmp}" "${LOCAL_YML}"
  log "Added purplelab plugin entry"
else
  log "purplelab plugin already present"
fi

if ! grep -Eq '^objects\.planners\.default:[[:space:]]*atomic[[:space:]]*$' "${LOCAL_YML}"; then
  if grep -Eq '^objects\.planners\.default:' "${LOCAL_YML}"; then
    sed -i 's/^objects\.planners\.default:.*/objects.planners.default: atomic/' "${LOCAL_YML}"
  else
    printf '\nobjects.planners.default: atomic\n' >> "${LOCAL_YML}"
  fi
  log "Ensured atomic planner as default"
fi
