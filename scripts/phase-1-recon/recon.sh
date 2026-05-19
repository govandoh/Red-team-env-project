#!/usr/bin/env bash
# Phase 1 — Reconnaissance: ping sweep, banner grabbing, DNS inverso

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-1-recon")
banner "Phase 1 — Reconnaissance"

# 1. Ping sweep de toda la subred
log INFO "Ping sweep over ${LAB_NETWORK}"
nmap -sn "${LAB_NETWORK}" -oN "${EVIDENCE_DIR}/ping-sweep.txt"

# 2. Banner grabbing en puertos comunes del target
log INFO "Banner grabbing on common ports of ${LAB_TARGET}"
for port in 21 22 23 25 80 139 443 445 3306; do
    echo "--- Port ${port} ---" >> "${EVIDENCE_DIR}/banners.txt"
    timeout 3 bash -c "echo '' | nc -v -w 2 ${LAB_TARGET} ${port}" \
        >> "${EVIDENCE_DIR}/banners.txt" 2>&1 || true
done

# 3. DNS reverso del target
log INFO "Reverse DNS lookup for ${LAB_TARGET}"
dig -x "${LAB_TARGET}" +short > "${EVIDENCE_DIR}/dns-reverse.txt" 2>/dev/null || true

finalize
