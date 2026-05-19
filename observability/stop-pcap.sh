#!/usr/bin/env bash
# Detiene la captura tcpdump iniciada por start-pcap.sh

set -euo pipefail

PID_FILE="/tmp/lab-pcap.pid"
PCAP_FILE_REF="/tmp/lab-pcap-file"

if [[ ! -f "$PID_FILE" ]]; then
    echo "[WARN] No se encontró PID file (${PID_FILE}). ¿start-pcap.sh fue ejecutado?" >&2
    exit 1
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "[INFO] tcpdump (PID ${PID}) detenido"
else
    echo "[WARN] Proceso ${PID} ya no existe"
fi

rm -f "$PID_FILE"

if [[ -f "$PCAP_FILE_REF" ]]; then
    PCAP_FILE=$(cat "$PCAP_FILE_REF")
    echo "[INFO] Captura guardada en: ${PCAP_FILE}"
    echo "[INFO] Para analizar: wireshark ${PCAP_FILE}"
    rm -f "$PCAP_FILE_REF"
fi
