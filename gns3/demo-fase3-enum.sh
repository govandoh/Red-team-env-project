#!/usr/bin/env bash
# Demo rápida Fase 3 — gobuster + enum4linux (sin nikto que tarda 10+ min)
set -uo pipefail
source /root/scripts/lib/common.sh

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — Enumeration HTTP + SMB (demo)"

URL="http://${LAB_TARGET}:80"

# ── WhatWeb: fingerprint rápido ───────────────────────────────────────────────
log INFO "WhatWeb fingerprint en ${URL}"
whatweb --color=never "${URL}" 2>/dev/null \
    | tee "${EVIDENCE_DIR}/whatweb.txt" || true

# ── Gobuster: descubrimiento de directorios ───────────────────────────────────
WORDLIST=""
for candidate in \
    /usr/share/wordlists/dirb/common.txt \
    /usr/share/dirb/wordlists/common.txt; do
    [[ -f "$candidate" ]] && WORDLIST="$candidate" && break
done

if [[ -n "$WORDLIST" ]]; then
    log INFO "Gobuster directorios en ${URL}"
    gobuster dir -u "${URL}" -w "${WORDLIST}" -q \
        --timeout 5s -o "${EVIDENCE_DIR}/gobuster.txt" 2>/dev/null \
        | tee -a "${EVIDENCE_DIR}/gobuster.txt" || true
    log INFO "Directorios encontrados:"
    cat "${EVIDENCE_DIR}/gobuster.txt"
else
    log WARN "Wordlist no encontrada — saltando gobuster"
fi

# ── Enum4linux: SMB null session ──────────────────────────────────────────────
log INFO "Enum4linux SMB en ${LAB_TARGET}"
enum4linux -a "${LAB_TARGET}" 2>/dev/null \
    | tee "${EVIDENCE_DIR}/enum4linux.txt" | grep -E "^\[|Share|Workgroup|user:|password" || true

log INFO "Evidence saved at: ${EVIDENCE_DIR}"
log INFO "Files generated:"
ls -la "${EVIDENCE_DIR}"
