#!/usr/bin/env bash
# Phase 3 — Enumeración FTP: anonymous login y listado de directorios

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — FTP enumeration"

PORT="${1:-21}"

log INFO "FTP banner grab"
timeout 5 bash -c "echo '' | nc -w 3 ${LAB_TARGET} ${PORT}" \
    > "${EVIDENCE_DIR}/ftp-banner.txt" 2>&1 || true

log INFO "Testing anonymous login with curl"
curl -v --max-time 10 \
    --user "anonymous:anonymous@lab.local" \
    "ftp://${LAB_TARGET}:${PORT}/" \
    > "${EVIDENCE_DIR}/ftp-anon-listing.txt" 2>&1 || true

# Si el listing tuvo contenido, el anonymous login funcionó
if grep -q "^-\|^d" "${EVIDENCE_DIR}/ftp-anon-listing.txt" 2>/dev/null; then
    log WARN "ANONYMOUS LOGIN SUCCESSFUL — directory listing obtained"
else
    log INFO "Anonymous login denied or empty directory"
fi

log INFO "FTP NSE check"
nmap -p "${PORT}" --script ftp-anon,ftp-syst \
    -oN "${EVIDENCE_DIR}/ftp-nmap.txt" \
    "${LAB_TARGET}" || true

finalize
