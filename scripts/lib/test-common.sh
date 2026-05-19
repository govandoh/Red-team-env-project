#!/usr/bin/env bash
# Smoke test de scripts/lib/common.sh
# Ejecutar dentro del contenedor Kali: bash /root/scripts/lib/test-common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

ok()   { echo "[PASS] $*"; ((PASS++)); }
fail() { echo "[FAIL] $*"; ((FAIL++)); }

# --- Test 1: source sin errores ---
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh" && ok "source common.sh" || fail "source common.sh"

# --- Test 2: init_evidence_dir crea el directorio ---
EVIDENCE_DIR=$(init_evidence_dir "test")
[[ -d "$EVIDENCE_DIR" ]] && ok "init_evidence_dir creates directory" || fail "init_evidence_dir did not create directory"

# --- Test 3: log escribe en run.log ---
log INFO "test message"
[[ -f "${EVIDENCE_DIR}/run.log" ]] && ok "log writes run.log" || fail "log did not write run.log"

# --- Test 4: validate_target rechaza IP fuera de subred ---
set +e
validate_target "192.168.1.1" 2>/dev/null
EXIT_CODE=$?
set -e
[[ "$EXIT_CODE" -eq 2 ]] && ok "validate_target rejects out-of-subnet IP" || fail "validate_target did not reject 192.168.1.1 (exit: $EXIT_CODE)"

# --- Test 5: validate_target acepta IP válida ---
set +e
validate_target "172.20.0.20" 2>/dev/null
EXIT_CODE=$?
set -e
[[ "$EXIT_CODE" -eq 0 ]] && ok "validate_target accepts 172.20.0.20" || fail "validate_target rejected valid IP (exit: $EXIT_CODE)"

# --- Test 6: finalize no falla ---
finalize 2>/dev/null && ok "finalize runs without error" || fail "finalize failed"

# --- Cleanup ---
rm -rf "$EVIDENCE_DIR"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
