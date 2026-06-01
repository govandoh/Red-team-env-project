# fase6-dos-extraer.ps1
# Ejecuta la Fase 6 DoS (Slowloris vs bt-web) desde Windows y extrae la
# evidencia automaticamente a evidence\phase-6\<timestamp>\ al finalizar.
#
# Uso:
#   .\gns3\fase6-dos-extraer.ps1
#
# Requiere: PuTTY instalado en C:\Program Files\PuTTY\

$ErrorActionPreference = "Stop"

$PUTTY          = "C:\Program Files\PuTTY"
$GNS3_IP        = "192.168.116.128"
$GNS3_PW        = "gns3"
$KALI           = "GNS3.Kali-Attacker.be75d0fb-1988-48cd-8cef-55dfa91c8aba"
$SCRIPT_DIR     = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT   = Split-Path -Parent $SCRIPT_DIR
$EVIDENCE_BASE  = "$PROJECT_ROOT\evidence\phase-6"

function plink_run($cmd) {
    & "$PUTTY\plink.exe" -batch -pw $GNS3_PW "gns3@$GNS3_IP" $cmd
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  FASE 6 — DoS Slowloris vs bt-web (172.20.0.50:80)  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Subir el script al GNS3 VM ──────────────────────────────────────────
Write-Host "[1/4] Subiendo demo-dos-btweb.sh a la GNS3 VM..." -ForegroundColor Yellow
& "$PUTTY\pscp.exe" -batch -pw $GNS3_PW `
    "$SCRIPT_DIR\demo-dos-btweb.sh" `
    "gns3@${GNS3_IP}:/tmp/demo-dos-btweb.sh" | Out-Null

# ── 2. Ejecutar DoS dentro de Kali (tarda ~100s: 10 baseline + 60 ataque + 15 recovery + 10 monitor) ──
Write-Host "[2/4] Ejecutando ataque DoS (Slowloris 60s + baseline + recovery)..." -ForegroundColor Red
Write-Host "      Salida en tiempo real:" -ForegroundColor Gray
Write-Host ""
& "$PUTTY\plink.exe" -batch -pw $GNS3_PW "gns3@$GNS3_IP" `
    "docker exec -i $KALI bash < /tmp/demo-dos-btweb.sh"
Write-Host ""

# ── 3. Obtener ruta de evidencia y copiar del contenedor a la VM ────────────
Write-Host "[3/4] Extrayendo evidencia del contenedor Kali..." -ForegroundColor Yellow
$EVIDENCE_DIR = plink_run "docker exec $KALI cat /tmp/dos-evidence-dir 2>/dev/null"
if (-not $EVIDENCE_DIR -or $EVIDENCE_DIR -notmatch "phase-6") {
    Write-Host "[ERROR] No se encontro ruta de evidencia en /tmp/dos-evidence-dir" -ForegroundColor Red
    exit 1
}
Write-Host "  Ruta en contenedor: $EVIDENCE_DIR"

# Fallback: si /tmp/dos-evidence-dir fue limpiado, tomar la carpeta más reciente
if (-not $EVIDENCE_DIR -or $EVIDENCE_DIR -notmatch "phase-6") {
    $EVIDENCE_DIR = (plink_run "docker exec $KALI bash -c 'ls -td /root/loot/phase-6-dos-btweb/*/ 2>/dev/null | head -1 | tr -d """ '").Trim()
    Write-Host "  (usando ultima carpeta disponible: $EVIDENCE_DIR)"
    if (-not $EVIDENCE_DIR) { Write-Host "[ERROR] No hay evidencia de Fase 6 en el contenedor" -ForegroundColor Red; exit 1 }
}

# Copia la carpeta por su nombre al /tmp de la GNS3 VM (evita el path "/." que bloquea pscp)
$REMOTE_DIRNAME = ($EVIDENCE_DIR -split "/")[-1]
plink_run "docker cp ${KALI}:${EVIDENCE_DIR} /tmp/${REMOTE_DIRNAME}" | Out-Null

# ── 4. Descargar a Windows ──────────────────────────────────────────────────
$WIN_TARGET = "$EVIDENCE_BASE\$REMOTE_DIRNAME"
New-Item -ItemType Directory -Force -Path $WIN_TARGET | Out-Null

Write-Host "[4/4] Descargando a $WIN_TARGET ..." -ForegroundColor Yellow
& "$PUTTY\pscp.exe" -batch -pw $GNS3_PW -r `
    "gns3@${GNS3_IP}:/tmp/${REMOTE_DIRNAME}" `
    "$EVIDENCE_BASE" | Out-Null

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  EVIDENCIA GUARDADA                                  " -ForegroundColor Green
Write-Host "  $WIN_TARGET" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Get-ChildItem $WIN_TARGET | Format-Table Name, @{L="Tamano (KB)";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
