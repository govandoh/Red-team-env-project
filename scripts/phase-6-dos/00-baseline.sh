#!/usr/bin/env bash
# Phase 6 — DoS — Línea base de latencia ANTES del ataque
# Ejecutar primero y siempre. Sin baseline, las métricas no tienen significado.

source "$(dirname "$0")/../lib/common.sh"

validate_target "${LAB_TARGET}"
EVIDENCE_DIR=$(init_evidence_dir "phase-6-dos")
export EVIDENCE_DIR  # Compartido con todos los scripts hijos de la ventana DoS

banner "Phase 6 — DoS — Baseline measurement"

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log INFO "Capturing baseline. Target: ${URL}"

# 30 muestras de latencia a 1 muestra/segundo
log INFO "30-sample latency baseline (30 seconds)"
{
    echo "timestamp,http_code,time_total"
    for i in {1..30}; do
        TS=$(date +%H:%M:%S)
        OUT=$(curl -s -o /dev/null \
            -w '%{http_code},%{time_total}' \
            --max-time 5 "$URL" 2>&1 || echo "000,5.000")
        echo "${TS},${OUT}"
        sleep 1
    done
} > "${EVIDENCE_DIR}/baseline-curl.csv"

# Apache Bench baseline: 100 requests, concurrencia 5
log INFO "Apache Bench baseline (100 req, c=5)"
ab -n 100 -c 5 "$URL" > "${EVIDENCE_DIR}/baseline-ab.txt" 2>&1

log INFO "Baseline summary:"
grep -E "(Requests per second|Time per request|Failed requests)" \
    "${EVIDENCE_DIR}/baseline-ab.txt" | tee -a "${EVIDENCE_DIR}/run.log"

# Persistir la ruta del directorio para que los vectores la compartan
echo "${EVIDENCE_DIR}" > /tmp/dos-evidence-dir

log INFO "Evidence dir persisted to /tmp/dos-evidence-dir for this DoS window"
finalize
