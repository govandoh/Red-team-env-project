#!/usr/bin/env bash
# Phase 2 — Escaneo TCP completo con detección de versión y OS

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-2-scanning")
banner "Phase 2 — Full TCP scan + version detection"

# Escaneo SYN completo (todos los puertos), versión, OS y scripts default
log INFO "Running nmap -sS -sV -O -p- (may take 5-10 minutes)"
nmap -sS -sV -O -p- \
    --min-rate 1000 \
    -oA "${EVIDENCE_DIR}/full-scan" \
    "${LAB_TARGET}"

# Resumen legible de puertos abiertos
log INFO "Generating open-ports summary"
grep "/open/" "${EVIDENCE_DIR}/full-scan.gnmap" \
    | tr ',' '\n' \
    | grep "/open/" \
    | awk -F/ '{print $1, $5}' \
    > "${EVIDENCE_DIR}/open-ports.txt" || true

# Scripts NSE de vulnerabilidades
log INFO "Running NSE vuln scripts"
nmap --script vuln \
    -oN "${EVIDENCE_DIR}/vuln-scripts.txt" \
    "${LAB_TARGET}"

finalize
