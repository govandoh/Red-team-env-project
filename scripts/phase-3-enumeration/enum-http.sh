#!/usr/bin/env bash
# Phase 3 — Enumeración HTTP: nikto, gobuster, whatweb

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — HTTP enumeration"

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}"

# Buscar wordlist en orden de preferencia
WORDLIST="${2:-}"
if [[ -z "$WORDLIST" ]]; then
    for candidate in \
        /usr/share/wordlists/dirb/common.txt \
        /usr/share/dirb/wordlists/common.txt \
        /usr/share/metasploit-framework/data/wordlists/http_owa_common.txt; do
        if [[ -f "$candidate" ]]; then
            WORDLIST="$candidate"
            break
        fi
    done
fi
[[ -z "$WORDLIST" ]] && { log ERROR "No wordlist found. Install dirb or pass path as arg 2."; exit 1; }

log INFO "Target URL: ${URL}"

# Nikto: escaneo de vulnerabilidades web
log INFO "Running nikto"
nikto -h "${URL}" -o "${EVIDENCE_DIR}/nikto.txt" 2>&1 || true

# Gobuster: descubrimiento de directorios
log INFO "Running gobuster with ${WORDLIST}"
gobuster dir -u "${URL}" -w "${WORDLIST}" \
    -o "${EVIDENCE_DIR}/gobuster.txt" \
    -q 2>&1 | tee "${EVIDENCE_DIR}/gobuster.log" || true

# Whatweb: fingerprinting del stack web
log INFO "Running whatweb"
whatweb -v "${URL}" > "${EVIDENCE_DIR}/whatweb.txt" 2>&1 || true

log INFO "HTTP findings summary:"
grep -E "(200|301|403|Found)" "${EVIDENCE_DIR}/gobuster.txt" \
    | head -20 | tee -a "${EVIDENCE_DIR}/run.log" || true

finalize
