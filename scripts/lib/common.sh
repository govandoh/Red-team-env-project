#!/usr/bin/env bash
# Funciones compartidas para todos los scripts del Red Team Lab

set -euo pipefail

# shellcheck source=colors.sh
source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

LAB_TARGET="${LAB_TARGET:-172.20.0.20}"
LAB_NETWORK="${LAB_NETWORK:-172.20.0.0/24}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/root/loot}"

# Blue Team infrastructure IPs (GNS3 topology — sobreponibles via env)
BT_WEB="${BT_WEB:-172.20.0.50}"
BT_DNS="${BT_DNS:-172.20.0.51}"
BT_SMB="${BT_SMB:-172.20.0.52}"
BT_MAIL="${BT_MAIL:-172.20.0.53}"

# Rechaza targets fuera de 172.20.0.0/24 — regla operativa no negociable
validate_target() {
    local target="$1"
    local prefix
    prefix=$(echo "$target" | cut -d. -f1-2)
    if [[ "$prefix" != "172.20" ]]; then
        echo -e "${RED}[ABORT]${NC} Target '${target}' is outside lab-net (172.20.0.0/24). Refusing." >&2
        exit 2
    fi
}

# Crea directorio de evidencia con timestamp para la fase indicada
# Uso: EVIDENCE_DIR=$(init_evidence_dir "phase-1-recon")
init_evidence_dir() {
    local phase="$1"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local dir="${EVIDENCE_ROOT}/${phase}/${ts}"
    mkdir -p "$dir"
    echo "$dir"
}

# Logger estructurado: timestamp + nivel + mensaje (escribe a stdout y a run.log)
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    local color="$NC"
    case "$level" in
        INFO)  color="$GREEN"  ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED"    ;;
    esac
    echo -e "[${ts}] [${color}${level}${NC}] ${msg}" | tee -a "${EVIDENCE_DIR:-/tmp}/run.log"
}

# Encabezado estándar al inicio de un script
banner() {
    local title="$1"
    cat <<EOF | tee -a "${EVIDENCE_DIR}/run.log"
================================================================
 ${title}
 Target  : ${LAB_TARGET}
 Network : ${LAB_NETWORK}
 Date    : $(date '+%Y-%m-%d %H:%M:%S')
 Output  : ${EVIDENCE_DIR}
================================================================
EOF
}

# Cierre estándar: lista archivos generados
finalize() {
    log INFO "Evidence saved at: ${EVIDENCE_DIR}"
    log INFO "Files generated:"
    ls -la "${EVIDENCE_DIR}" | tee -a "${EVIDENCE_DIR}/run.log"
}
