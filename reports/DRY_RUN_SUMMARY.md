# Dry Run Completo — Resultados
**Fecha:** 2026-05-23  
**Entorno:** Docker bridge `lab-net (172.20.0.0/24)` — Kali `172.20.0.10` vs Metasploitable2 `172.20.0.20`

---

## Estado por fase

| Fase | Script(s) | Resultado | Evidencia |
|---|---|---|---|
| 1 — Reconocimiento | `recon.sh` | PASS | `evidence/phase-1-recon/20260523-151342/` |
| 2 — Escaneo | `port-scan.sh` | PASS | `evidence/phase-2-scanning/20260523-151417/` |
| 3 — Enumeración | `enum-http/ftp/ssh/smb.sh` | PASS (×4) | `evidence/phase-3-enumeration/2026052315*/` |
| 4 — Credenciales | `default-creds.sh` | PASS | `evidence/phase-4-credentials/20260523-160012/` |
| 5 — Explotación | `msf-exploit.sh` | PASS (fix aplicado) | `evidence/phase-5-exploitation/20260523-161524/` |
| 5 — SQLi | `web-sqli.sh` | PASS (fix aplicado) | `evidence/phase-5-exploitation/sqli-dvwa/` |
| 5 — Web Shells | `web-shells.sh` | PASS | `evidence/phase-5-exploitation/20260523-161701/` |
| 6 — DoS | — | SKIP | Requiere ventana coordinada con Blue Team |
| 7 — Post-explotación | `privesc-check.sh` | PASS | `evidence/phase-7-post-exploitation/20260523-161704/` |

---

## Hallazgos confirmados

### Fase 1 — Reconocimiento
- 3 hosts activos: gateway `172.20.0.1`, target `172.20.0.20`, atacante `172.20.0.10`
- Banners capturados en puertos 21, 22, 23, 80, 139

### Fase 2 — Escaneo
- 22 puertos TCP abiertos en `172.20.0.20`
- NSE vuln confirmó **CVE-2011-2523** (vsftpd backdoor) como explotable: `uid=0(root)`
- Servicios críticos: vsftpd 2.3.4, OpenSSH 4.7p1, Apache 2.2.8, MySQL 5.0.51a, PostgreSQL 8.3

### Fase 3 — Enumeración
- **HTTP**: nikto encontró phpMyAdmin expuesto, phpinfo.php, directory listing en `/doc/`, `/icons/`. Gobuster descubrió `/dvwa/`, `/mutillidae/`, `/phpMyAdmin/`, `/webdav/`
- **FTP**: login anónimo permitido en vsftpd 2.3.4
- **SSH**: OpenSSH 4.7p1 con algoritmos legacy (diffie-hellman-group1-sha1, arcfour)
- **SMB**: enum4linux completado, WORKGROUP identificado

### Fase 4 — Credenciales
Credenciales SSH encontradas por defecto:

| Servicio | Usuario | Password |
|---|---|---|
| SSH | msfadmin | msfadmin |
| SSH | user | user |
| SSH | postgres | postgres |
| SSH | service | service |
| FTP | msfadmin | msfadmin |
| FTP | postgres | postgres |

### Fase 5 — Explotación

**vsftpd 2.3.4 backdoor (CVE-2011-2523):**
- Trigger vía `USER root:)` en puerto 21 → shell en puerto 6200
- Identidad confirmada: `uid=0(root) gid=0(root)`
- Fix aplicado: netcat manual como fallback al payload MSF incompatible en build actual

**SQL Injection (DVWA):**
- Vector: `GET /dvwa/vulnerabilities/sqli/?id=1` con `security=low`
- Técnicas confirmadas: boolean-based blind, error-based, time-based blind, UNION
- 7 bases de datos extraídas: `dvwa`, `information_schema`, `metasploit`, `mysql`, `owasp10`, `tikiwiki`, `tikiwiki195`
- Tablas de `dvwa`: `guestbook`, `users`
- Fix aplicado: autenticación automática + `security=low` reemplaza `--forms` que no detectaba injection

**LFI (Mutillidae):**
- `/etc/passwd` expuesto vía path traversal (`../../../../etc/passwd`)
- Confirmado también: `/etc/hosts`, `/proc/version`

### Fase 7 — Post-explotación
- LinPEAS ejecutado remotamente vía SSH como `msfadmin@172.20.0.20`
- Output: 526 KB — guardado en `evidence/phase-7-post-exploitation/20260523-161704/linpeas-output.txt`
- (Revisar output para vectores de escalada de privilegios)

---

## Fixes realizados durante el dry run

| Archivo | Problema | Solución |
|---|---|---|
| `scripts/phase-5-exploitation/msf-exploit.sh` | `cmd/unix/interact` no es payload válido en Metasploit moderno; LHOST requerido | Se agrega fase B con netcat manual: trigger FTP → conexión a puerto 6200 → captura `uid=0(root)` |
| `scripts/phase-5-exploitation/web-sqli.sh` | `--forms` con level=2 no detecta injection en Mutillidae | Se reemplaza por DVWA con auth automática y GET param directo; Mutillidae se testea con `-p username --level=3` |

---

## Estado de entregables

| Entregable del docente | Cubierto | Archivo de referencia |
|---|---|---|
| Vulnerabilidades encontradas | ✅ | `evidence/phase-2-scanning/*/vuln-scripts.txt` |
| Evidencia de ataques | ✅ | `evidence/phase-{1..7}/` |
| Descripción de técnicas | ✅ | `reports/INFORME_FINAL_template.md` §7 |
| Impacto logrado | ✅ | Root shell + 7 DBs + LFI + 4 cuentas SSH |
| Plantilla informe final | ✅ | `reports/INFORME_FINAL_template.docx` |
| Manual de demostración | ✅ | `reports/MANUAL_DEMOSTRACION.docx` |
