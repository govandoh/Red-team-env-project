#!/usr/bin/env bash
# Lanza tcpdump host-side sobre la interfaz bridge de lab-net
# Ejecutar en el HOST con permisos root, NO dentro del contenedor Kali

set -euo pipefail

EVIDENCE_ROOT="${EVIDENCE_ROOT:-./evidence}"
PCAP_DIR="${EVIDENCE_ROOT}/pcap"
mkdir -p "$PCAP_DIR"

PCAP_FILE="${PCAP_DIR}/capture-$(date +%Y%m%d-%H%M%S).pcap"
PID_FILE="/tmp/lab-pcap.pid"

# Verificar que el stack está levantado
if ! docker network inspect lab-net > /dev/null 2>&1; then
    echo "[ERROR] Red 'lab-net' no encontrada. Levanta el stack primero: docker compose up -d" >&2
    exit 1
fi

# Resolver el nombre real del bridge (Docker genera br-XXXXXXXXXXXX)
BRIDGE_ID=$(docker network inspect lab-net --format '{{.Id}}' | cut -c1-12)
BRIDGE_IF="br-${BRIDGE_ID}"

# Verificar que la interfaz existe en el host
if ! ip link show "$BRIDGE_IF" > /dev/null 2>&1; then
    echo "[ERROR] Interfaz '${BRIDGE_IF}' no encontrada en el host." >&2
    echo "        Interfaces disponibles:" >&2
    ip link show | grep "br-" | awk '{print "          " $2}' >&2
    exit 1
fi

echo "[INFO] Bridge resuelto: ${BRIDGE_IF}"
echo "[INFO] Iniciando captura -> ${PCAP_FILE}"

tcpdump -i "$BRIDGE_IF" -w "$PCAP_FILE" -n &
TCPDUMP_PID=$!
echo "$TCPDUMP_PID" > "$PID_FILE"
echo "$PCAP_FILE" > /tmp/lab-pcap-file

echo "[INFO] tcpdump PID ${TCPDUMP_PID} corriendo en background"
echo "[INFO] Para detener: bash observability/stop-pcap.sh"
echo "[INFO] Para abrir en Wireshark: wireshark ${PCAP_FILE}"
