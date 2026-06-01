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
$SCRIPT_DIR     = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT   = Split-Path -Parent $SCRIPT_DIR
$EVIDENCE_BASE  = "$PROJECT_ROOT\evidence\phase-6"

function plink_run($cmd) {
    & "$PUTTY\plink.exe" -batch -pw $GNS3_PW "gns3@$GNS3_IP" $cmd
}

# ── Auto-deteccion del contenedor Kali (por nombre, sobrevive reimportaciones) ──
$kaliList = (& "$PUTTY\plink.exe" -batch -pw $GNS3_PW "gns3@$GNS3_IP" `
    "docker ps --filter name=GNS3.Kali-Attacker --format '{{.Names}}'" 2>$null) `
    | Where-Object { $_ -match 'Kali-Attacker' }
if (-not $kaliList) {
    Write-Host "[ERROR] No hay contenedor Kali corriendo. Arranca la topologia primero." -ForegroundColor Red
    exit 1
}
if (@($kaliList).Count -gt 1) {
    Write-Host "[ERROR] Hay mas de un Kali (proyectos duplicados). Deja solo uno." -ForegroundColor Red
    $kaliList | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    exit 1
}
$KALI = @($kaliList)[0]

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
$EVIDENCE_DIR = (plink_run "docker exec $KALI cat /tmp/dos-evidence-dir 2>/dev/null").Trim()

# Fallback: si /tmp/dos-evidence-dir fue limpiado por systemd-tmpfiles, buscar con find
if (-not $EVIDENCE_DIR -or $EVIDENCE_DIR -notmatch "phase-6") {
    $EVIDENCE_DIR = (plink_run "docker exec $KALI find /root/loot/phase-6-dos-btweb -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r | head -1").Trim()
    if ($EVIDENCE_DIR) { Write-Host "  (usando ultima carpeta disponible: $EVIDENCE_DIR)" -ForegroundColor Yellow }
}
if (-not $EVIDENCE_DIR) {
    Write-Host "[ERROR] No hay evidencia de Fase 6 en el contenedor. Ejecuta primero el ataque." -ForegroundColor Red
    exit 1
}
Write-Host "  Ruta en contenedor: $EVIDENCE_DIR"

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
