#!/usr/bin/env bash
# Phase 3 — Enumeración SSH: banner, algoritmos soportados, hostkey
# No intenta login — eso es fase 4

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — SSH enumeration"

PORT="${1:-22}"

log INFO "SSH banner grab"
timeout 5 bash -c "echo '' | nc -w 3 ${LAB_TARGET} ${PORT}" \
    > "${EVIDENCE_DIR}/ssh-banner.txt" 2>&1 || true

log INFO "SSH algorithms and host key (nmap NSE)"
nmap -p "${PORT}" \
    --script ssh2-enum-algos,ssh-hostkey,sshv1 \
    -oN "${EVIDENCE_DIR}/ssh-enum.txt" \
    "${LAB_TARGET}" || true

log INFO "SSH version:"
grep -E "(SSH|Protocol|banner)" "${EVIDENCE_DIR}/ssh-banner.txt" \
    | tee -a "${EVIDENCE_DIR}/run.log" || true

finalize
