#!/usr/bin/env bash
# Phase 2 — Detección de servicios con NSE por servicio específico
# Ejecutar después de port-scan.sh para profundizar en puertos abiertos

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"

# Reutilizar el directorio del run de port-scan si existe, o crear uno nuevo
LATEST=$(ls -td "${EVIDENCE_ROOT}/phase-2-scanning/"*/ 2>/dev/null | head -1)
if [[ -n "$LATEST" ]]; then
    EVIDENCE_DIR="$LATEST"
    log INFO "Appending to existing phase-2 run: ${EVIDENCE_DIR}"
else
    EVIDENCE_DIR=$(init_evidence_dir "phase-2-scanning")
fi

banner "Phase 2 — Service-specific NSE detection"

# Scripts NSE por servicio sobre puertos comunes de Metasploitable2
log INFO "SSH version and auth methods"
nmap -p 22 --script ssh2-enum-algos,ssh-auth-methods \
    -oN "${EVIDENCE_DIR}/nse-ssh.txt" "${LAB_TARGET}" || true

log INFO "FTP anonymous access check"
nmap -p 21 --script ftp-anon,ftp-syst \
    -oN "${EVIDENCE_DIR}/nse-ftp.txt" "${LAB_TARGET}" || true

log INFO "SMB security and shares"
nmap -p 139,445 --script smb-security-mode,smb-enum-shares \
    -oN "${EVIDENCE_DIR}/nse-smb.txt" "${LAB_TARGET}" || true

log INFO "HTTP headers and methods"
nmap -p 80 --script http-headers,http-methods,http-title \
    -oN "${EVIDENCE_DIR}/nse-http.txt" "${LAB_TARGET}" || true

log INFO "MySQL anonymous access"
nmap -p 3306 --script mysql-empty-password,mysql-info \
    -oN "${EVIDENCE_DIR}/nse-mysql.txt" "${LAB_TARGET}" || true

finalize
