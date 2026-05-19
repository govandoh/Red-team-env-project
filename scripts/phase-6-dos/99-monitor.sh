#!/usr/bin/env bash
# Phase 6 — Monitor continuo de latencia durante el ataque
# Lanzar en una segunda terminal del Kali ANTES de iniciar los vectores:
#   docker compose exec kali bash -c "bash /root/scripts/phase-6-dos/99-monitor.sh"

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || init_evidence_dir "phase-6-dos")

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"
DURATION="${2:-180}"  # segundos a monitorear (default 3 minutos)

OUT="${EVIDENCE_DIR}/monitor-$(date +%H%M%S).csv"
echo "timestamp,http_code,time_total" > "$OUT"

log INFO "Monitoring ${URL} for ${DURATION}s -> ${OUT}"
log INFO "Press Ctrl+C to stop early"

END=$(($(date +%s) + DURATION))
while [ "$(date +%s)" -lt "$END" ]; do
    TS=$(date +%H:%M:%S)
    OUT_LINE=$(curl -s -o /dev/null \
        -w '%{http_code},%{time_total}' \
        --max-time 5 "$URL" 2>&1 || echo "000,5.000")
    echo "${TS},${OUT_LINE}" >> "$OUT"
    echo "${TS} | ${OUT_LINE}"
    sleep 1
done

log INFO "Monitor finished. CSV: ${OUT}"
