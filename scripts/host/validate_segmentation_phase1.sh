#!/usr/bin/env bash
set -euo pipefail

FAILURES=0

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; FAILURES=$((FAILURES + 1)); }

log() {
  echo "[validate_segmentation_phase1] $1"
}

test_expect_open() {
  local label="$1"
  local container="$2"
  local host="$3"
  local port="$4"

  if docker exec "${container}" bash -lc "timeout 5 bash -c '</dev/tcp/${host}/${port}'" >/dev/null 2>&1; then
    pass "${label}"
  else
    fail "${label}"
  fi
}

test_expect_blocked() {
  local label="$1"
  local container="$2"
  local host="$3"
  local port="$4"

  if docker exec "${container}" bash -lc "timeout 5 bash -c '</dev/tcp/${host}/${port}'" >/dev/null 2>&1; then
    fail "${label}"
  else
    pass "${label}"
  fi
}

log "Validating allowed flows..."
test_expect_open "DMZ app can reach DB on 5432" app-dmz-01 db.corp.lab 5432
test_expect_open "int-endpoint can reach Files on 445" int-endpoint-01 files.corp.lab 445
test_expect_open "int-endpoint can reach Proxy on 3128" int-endpoint-01 proxy.corp.lab 3128
test_expect_open "int-endpoint can reach LDAP on 389" int-endpoint-01 ldap.corp.lab 389
test_expect_open "int-endpoint can reach Print on 631" int-endpoint-01 print.corp.lab 631
test_expect_open "int-endpoint can reach app internal web endpoint on 8080" int-endpoint-01 app-int.corp.lab 8080
test_expect_open "user-linux can reach Files on 445" user-linux-01 files.corp.lab 445
test_expect_open "user-linux can reach Proxy on 3128" user-linux-01 proxy.corp.lab 3128
test_expect_open "user-linux can reach app internal web endpoint on 8080" user-linux-01 app-int.corp.lab 8080
test_expect_open "pool-node-01 can reach Files on 445" pool-node-01 files.corp.lab 445
test_expect_open "pool-node-01 can reach app internal web endpoint on 8080" pool-node-01 app-int.corp.lab 8080
test_expect_open "pool-node-01 can reach user-linux over SSH for S13" pool-node-01 user-linux-01.corp.lab 22

log "Validating blocked flows..."
test_expect_blocked "int-endpoint cannot reach DB on 5432" int-endpoint-01 db.corp.lab 5432
test_expect_blocked "user-linux cannot reach DB on 5432" user-linux-01 db.corp.lab 5432
test_expect_blocked "pool-node-01 cannot reach DB on 5432" pool-node-01 db.corp.lab 5432
test_expect_blocked "DMZ app cannot reach Files on 445" app-dmz-01 files.corp.lab 445
test_expect_blocked "DMZ app cannot reach LDAP on 389" app-dmz-01 ldap.corp.lab 389
test_expect_blocked "DMZ app cannot reach Print on 631" app-dmz-01 print.corp.lab 631

log "Validation summary..."
if [ "$FAILURES" -eq 0 ]; then
  log "Segmentation phase 1 validation passed."
  exit 0
fi

log "Segmentation phase 1 validation failed with ${FAILURES} failure(s)."
exit 1
