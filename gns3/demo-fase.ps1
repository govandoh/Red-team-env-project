# demo-fase.ps1  —  Ejecuta una fase del Red Team Lab y extrae evidencia a Windows
# Uso: .\gns3\demo-fase.ps1 -Fase <1-7>
#
# Requiere: PuTTY instalado en C:\Program Files\PuTTY\

param(
    [Parameter(Mandatory)]
    [ValidateRange(1,7)]
    [int]$Fase
)

$ErrorActionPreference = "Stop"

# ── Configuracion ─────────────────────────────────────────────────────────────
$PUTTY   = "C:\Program Files\PuTTY"
$IP      = "192.168.116.128"
$PW      = "gns3"
$KALI    = "GNS3.Kali-Attacker.be75d0fb-1988-48cd-8cef-55dfa91c8aba"
$TARGET  = "172.20.0.20"
$ROOT    = Split-Path -Parent $PSScriptRoot

# ── Helpers ───────────────────────────────────────────────────────────────────
function kali_run([string]$cmd) {
    # Ejecuta en Kali y transmite salida en tiempo real
    & "$PUTTY\plink.exe" -batch -pw $PW "gns3@$IP" "docker exec -i $KALI bash -c '$cmd'"
}

function kali_capture([string]$cmd) {
    (& "$PUTTY\plink.exe" -batch -pw $PW "gns3@$IP" "docker exec $KALI bash -c '$cmd'" 2>$null).Trim()
}

function Extract-Evidence([string]$loot_name, [string]$win_folder) {
    Write-Host ""
    Write-Host "-- Extrayendo evidencia: $loot_name -> evidence\$win_folder\" -ForegroundColor Yellow

    # find evita conflictos de comillas que da ls|sed en bash -c
    $latest = kali_capture "find /root/loot/$loot_name -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r | head -1"
    if (-not $latest) {
        Write-Host "   [!] No se encontro evidencia en /root/loot/$loot_name" -ForegroundColor Red
        return
    }

    $dirname = ($latest -split "/")[-1]
    $win_dest = "$ROOT\evidence\$win_folder"
    New-Item -ItemType Directory -Force -Path $win_dest | Out-Null

    # Copiar del contenedor al filesystem de la GNS3 VM (por nombre, evita bug pscp con "/.")
    & "$PUTTY\plink.exe" -batch -pw $PW "gns3@$IP" `
        "docker cp ${KALI}:${latest} /tmp/${dirname}" | Out-Null

    # Descargar de la VM a Windows
    & "$PUTTY\pscp.exe" -batch -pw $PW -r `
        "gns3@${IP}:/tmp/${dirname}" "$win_dest" | Out-Null

    Write-Host "   [OK] evidence\$win_folder\$dirname\" -ForegroundColor Green
    Get-ChildItem "$win_dest\$dirname" -ErrorAction SilentlyContinue `
        | Format-Table Name, @{L="KB";E={[math]::Round($_.Length/1KB,1)}} -AutoSize
}

# ── Fases ─────────────────────────────────────────────────────────────────────
switch ($Fase) {

    1 {
        Write-Host "=== FASE 1 — Reconocimiento ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET bash /root/scripts/phase-1-recon/recon.sh"
        Extract-Evidence "phase-1-recon" "phase-1-recon"
    }

    2 {
        Write-Host "=== FASE 2 — Escaneo de puertos (puertos clave, modo demo) ===" -ForegroundColor Cyan
        & "$PUTTY\pscp.exe" -batch -pw $PW "$PSScriptRoot\demo-fase2-scan.sh" "gns3@${IP}:/tmp/demo-fase2-scan.sh" | Out-Null
        & "$PUTTY\plink.exe" -batch -pw $PW "gns3@$IP" `
            "docker exec -i $KALI bash < /tmp/demo-fase2-scan.sh"
        Extract-Evidence "phase-2-scanning" "phase-2-scanning"
    }

    3 {
        Write-Host "=== FASE 3 — Enumeracion HTTP ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET bash /root/scripts/phase-3-enumeration/enum-http.sh"
        Write-Host ""
        Write-Host "=== FASE 3 — Enumeracion SMB ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET bash /root/scripts/phase-3-enumeration/enum-smb.sh"
        Extract-Evidence "phase-3-enumeration" "phase-3-enumeration"
    }

    4 {
        Write-Host "=== FASE 4 — Credenciales por defecto ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET bash /root/scripts/phase-4-credentials/default-creds.sh"
        Extract-Evidence "phase-4-credentials" "phase-4-credentials"
    }

    5 {
        Write-Host "=== FASE 5a — Explotacion: vsftpd backdoor → root (CVE-2011-2523) ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET bash /root/scripts/phase-5-exploitation/msf-exploit.sh"
        Extract-Evidence "phase-5-exploitation" "phase-5-exploitation"
        Write-Host ""
        Write-Host "=== FASE 5b — Explotacion: SQL Injection DVWA (7 bases de datos) ===" -ForegroundColor Cyan
        & "$PUTTY\pscp.exe" -batch -pw $PW "$PSScriptRoot\demo-fase5-sqli.sh" "gns3@${IP}:/tmp/demo-fase5-sqli.sh" | Out-Null
        & "$PUTTY\plink.exe" -batch -pw $PW "gns3@$IP" `
            "docker exec -i $KALI bash < /tmp/demo-fase5-sqli.sh"
        Extract-Evidence "phase-5-exploitation" "phase-5-exploitation"
    }

    6 {
        Write-Host "=== FASE 6 — DoS Slowloris vs bt-web ===" -ForegroundColor Cyan
        & "$PSScriptRoot\fase6-dos-extraer.ps1"
    }

    7 {
        Write-Host "=== FASE 7 — Post-explotacion (LinPEAS) ===" -ForegroundColor Cyan
        kali_run "LAB_TARGET=$TARGET SSH_USER=msfadmin SSH_PASS=msfadmin bash /root/scripts/phase-7-post-exploitation/privesc-check.sh"
        Extract-Evidence "phase-7-post-exploitation" "phase-7-post-exploitation"
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Fase $Fase completada. Evidencia guardada en Windows." -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
