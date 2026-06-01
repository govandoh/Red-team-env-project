#!/usr/bin/env bash
# Demo rápida Fase 2 — escanea puertos clave sin -p- completo (para video de 5 min)
set -uo pipefail
source /root/scripts/lib/common.sh

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-2-scanning")
banner "Phase 2 — Port scan + version detection (demo)"

log INFO "Escaneando puertos clave en ${LAB_TARGET} (modo rapido)"
nmap -sS -sV --open \
    -p 21,22,23,25,53,80,139,443,445,3306,5432,5900,6200,8080 \
    --min-rate 2000 \
    -oA "${EVIDENCE_DIR}/port-scan" \
    "${LAB_TARGET}"

log INFO "Generando resumen de puertos abiertos"
grep "/open/" "${EVIDENCE_DIR}/port-scan.gnmap" \
    | tr ',' '\n' | grep "/open/" \
    | awk -F/ '{print $1, $5}' \
    > "${EVIDENCE_DIR}/open-ports.txt" || true

log INFO "Evidence saved at: ${EVIDENCE_DIR}"
log INFO "Files generated:"
ls -la "${EVIDENCE_DIR}"
