#!/usr/bin/env bash
# Phase 6 — Verificación de recuperación del servicio tras el ataque

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || { echo "[ERROR] Run 00-baseline.sh first" >&2; exit 1; })

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log INFO "Recovery check: 10 samples over 20 seconds"
{
    echo "sample,http_code,time_total"
    for i in {1..10}; do
        OUT=$(curl -s -o /dev/null \
            -w '%{http_code},%{time_total}' \
            --max-time 5 "$URL" 2>&1 || echo "000,5.000")
        echo "${i},${OUT}"
        sleep 2
    done
} | tee "${EVIDENCE_DIR}/recovery-check.csv"

log INFO "Compare with baseline-curl.csv to confirm full recovery"

# Indicador rápido de recuperación
HTTP_200=$(grep -c "^[0-9]*,200," "${EVIDENCE_DIR}/recovery-check.csv" || true)
log INFO "${HTTP_200}/10 samples returned HTTP 200"
[[ "$HTTP_200" -ge 8 ]] \
    && log INFO "Service appears RECOVERED" \
    || log WARN "Service may still be degraded — wait before next vector"
