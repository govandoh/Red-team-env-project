#!/usr/bin/env bash
# Phase 3 — Enumeración SMB: shares, usuarios, políticas

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — SMB enumeration"

# enum4linux: enumeración completa (users, shares, password policy, OS info)
log INFO "Running enum4linux -a"
enum4linux -a "${LAB_TARGET}" > "${EVIDENCE_DIR}/enum4linux.txt" 2>&1 || true

# smbclient: listar shares sin credenciales
log INFO "Listing SMB shares (null session)"
smbclient -L "//${LAB_TARGET}" -N \
    > "${EVIDENCE_DIR}/smbclient-shares.txt" 2>&1 || true

# Intentar acceso al share IPC$ null session
log INFO "Testing IPC$ null session"
smbclient "//${LAB_TARGET}/IPC\$" -N -c "ls" \
    > "${EVIDENCE_DIR}/smbclient-ipc.txt" 2>&1 || true

log INFO "SMB findings summary:"
grep -E "(Sharename|WORKGROUP|Domain|ERROR)" \
    "${EVIDENCE_DIR}/smbclient-shares.txt" | tee -a "${EVIDENCE_DIR}/run.log" || true

finalize
