#!/bin/bash
# Extrae los datos clave de la ultima demo DoS para el informe.
D=$(cat /tmp/dos-evidence-dir)
echo "EVIDENCE_DIR=$D"
echo ""
echo "=== BASELINE (latencia normal, primeras 3 + ultima) ==="
head -4 "$D/baseline-curl.csv"
echo "..."
tail -1 "$D/baseline-curl.csv"
echo ""
echo "=== MONITOR — transiciones de estado ==="
awk -F, 'NR==1 || $2!=prev {print} {prev=$2}' "$D/monitor.csv"
echo ""
echo "=== MONITOR — conteo por codigo ==="
tail -n +2 "$D/monitor.csv" | cut -d, -f2 | sort | uniq -c
echo ""
echo "=== SLOWLORIS report (disponibilidad del servicio) ==="
grep -iE 'service|available|seconds|connection' "$D/slowloris.log" | head -15
