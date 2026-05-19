#!/usr/bin/env bash
# Phase 2 — Escaneo UDP (top 50 puertos, selectivo por tiempo)

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-2-scanning")
banner "Phase 2 — UDP top-50 scan"

log WARN "UDP scanning is slow. Expected duration: 5-15 minutes."

# Top 50 puertos UDP con retries limitados para no eternizar el scan
nmap -sU --top-ports 50 \
    --max-retries 1 \
    --host-timeout 30s \
    -oN "${EVIDENCE_DIR}/udp-scan.txt" \
    "${LAB_TARGET}"

log INFO "Open/filtered UDP ports:"
grep "open\|open|filtered" "${EVIDENCE_DIR}/udp-scan.txt" \
    | tee -a "${EVIDENCE_DIR}/run.log" || true

finalize
