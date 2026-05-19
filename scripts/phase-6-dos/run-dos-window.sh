#!/usr/bin/env bash
# Orquesta la ventana completa de DoS con confirmaciones humanas en cada paso
# Ejecutar desde el contenedor Kali: bash /root/scripts/phase-6-dos/run-dos-window.sh

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pausa entre vectores — reducir a 30 para pruebas de validación
PAUSE_BETWEEN_VECTORS="${PAUSE_BETWEEN_VECTORS:-300}"

echo "============================================"
echo " DoS WINDOW — Coordinated attack execution"
echo "============================================"
echo ""
echo "Pre-flight checklist:"
echo "  [ ] Blue Team notificado y monitoreando"
echo "  [ ] Ventana acordada (hora inicio / hora fin)"
echo "  [ ] Canal de señal de abort establecido"
echo "  [ ] 99-monitor.sh corriendo en segunda terminal"
echo ""
read -rp "Todo confirmado? Escribe YES para continuar: " confirm
[[ "$confirm" != "YES" ]] && exit 1

# 1. Baseline
bash "${DIR}/00-baseline.sh"
echo ""
read -rp "Baseline capturado. Iniciar Vector 1 (Slowloris)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/01-slowloris.sh"

echo "Pausando ${PAUSE_BETWEEN_VECTORS}s para recuperación del servicio y revisión del Blue Team..."
sleep "${PAUSE_BETWEEN_VECTORS}"
bash "${DIR}/recovery-check.sh"

# 2. HTTP flood
read -rp "Iniciar Vector 2 (HTTP flood)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/02-http-flood.sh"

echo "Pausando ${PAUSE_BETWEEN_VECTORS}s..."
sleep "${PAUSE_BETWEEN_VECTORS}"
bash "${DIR}/recovery-check.sh"

# 3. SYN flood
read -rp "Iniciar Vector 3 (SYN flood)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/03-syn-flood.sh"

echo "Pausando ${PAUSE_BETWEEN_VECTORS}s..."
sleep "${PAUSE_BETWEEN_VECTORS}"
bash "${DIR}/recovery-check.sh"

echo ""
echo "Ventana DoS completa."
echo "Evidencia en: $(cat /tmp/dos-evidence-dir)"
