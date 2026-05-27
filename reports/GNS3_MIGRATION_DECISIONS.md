# Migración a GNS3 — Cambios, Decisiones y Arquitectura Blue Team
## Red Team Lab · Redes 2 · Ciclo 2026

**Rama de trabajo:** `feat/gns3-migration`
**Fecha:** 27 de mayo de 2026
**Clasificación:** Documento técnico — uso académico

---

## 1. Contexto y Motivación

### 1.1 Estado previo

El laboratorio Red Team operaba como un stack **Docker Compose** ejecutado en Windows 11. La infraestructura consistía en:

- `redteam-kali` (172.20.0.10) — contenedor atacante con herramientas ofensivas
- `blueteam-target` (172.20.0.20) — Metasploitable2, objetivo principal de ataques
- `blueteam-client-1/2` (172.20.0.30-31) — clientes Ubuntu opcionales
- Red bridge `lab-net` (172.20.0.0/24) — completamente aislada del host

Este entorno fue suficiente para ejecutar el dry run del 2026-05-23, confirmando todas las fases de ataque (1-5 y 7). Sin embargo, presenta tres limitaciones para la demostración final:

1. **Sin visualización topológica** — no existe una representación gráfica de la red que sea comprensible para el docente o el Blue Team.
2. **Sin infraestructura Blue Team real** — Metasploitable2 es un objetivo deliberadamente roto, no representa servicios corporativos reales.
3. **Fase 6 (DoS) sin objetivo Blue Team** — el único servicio HTTP disponible era Metasploitable2; no había servidores del Blue Team que "botar" como demostración de impacto.

### 1.2 Objetivos de la migración

| Objetivo | Descripción |
|---|---|
| Visualización topológica | GNS3 provee un canvas gráfico donde se ven los nodos, enlaces y tráfico en tiempo real |
| Infraestructura Blue Team | Agregar 4 servidores nuevos con servicios reales que el Red Team puede atacar |
| Demostración de impacto | Poder "botar" al menos un servicio del Blue Team como resultado final del ejercicio |
| Preservar lo que funciona | Los scripts de ataque, IPs y metodología PTES existentes deben seguir funcionando sin cambios |

---

## 2. Decisión de Arquitectura: Rama Aislada

### Decisión

Todo el trabajo de migración se realiza en la rama `feat/gns3-migration`. La rama `master` se mantiene intacta con el stack Docker Compose funcional.

### Justificación

El laboratorio tiene un dry run exitoso en `master` con evidencia generada. Romper ese estado para experimentar con GNS3 implicaría perder la capacidad de ejecutar el lab en cualquier momento. La estrategia de ramas permite:

- Continuar usando Docker Compose para ejecuciones rápidas mientras se prepara GNS3
- Realizar merge a `master` solo cuando GNS3 esté completamente verificado
- Mantener un historial limpio de las decisiones de diseño

---

## 3. Topología de Red en GNS3

### 3.1 Diseño

```
                    172.20.0.0/24
                         |
                  [Switch L2 Central]
     ┌───────────────┼───────────────┐
     |               |               |
[Kali .10]     [MSF2 .20]    [Client-1 .30]
                                [Client-2 .31]
                    |
     ┌──────────────┼──────────────────┐
     |              |           |      |
[bt-web .50]  [bt-dns .51] [bt-smb .52] [bt-mail .53]
```

### 3.2 Asignación de IPs

| Host | IP | Imagen Docker | Rol |
|---|---|---|---|
| Kali | 172.20.0.10 | `redteam/kali:latest` | Atacante (Red Team) |
| Metasploitable2 | 172.20.0.20 | `tleemcjr/metasploitable2` | Objetivo clásico (mantenido) |
| Ubuntu Client-1 | 172.20.0.30 | `ubuntu:22.04` | Cliente pasivo |
| Ubuntu Client-2 | 172.20.0.31 | `ubuntu:22.04` | Cliente pasivo |
| bt-web | 172.20.0.50 | `blueteam/bt-web:latest` | Servidor web Apache2 (Blue Team) |
| bt-dns | 172.20.0.51 | `blueteam/bt-dns:latest` | Servidor DNS BIND9 (Blue Team) |
| bt-smb | 172.20.0.52 | `blueteam/bt-smb:latest` | Servidor de archivos Samba (Blue Team) |
| bt-mail | 172.20.0.53 | `blueteam/bt-mail:latest` | Servidor de correo Postfix (Blue Team) |

### 3.3 Por qué se mantiene la subred 172.20.0.0/24

Cambiar la subred habría requerido modificar `scripts/lib/common.sh`, todos los playbooks y la documentación existente. Al mantener la misma subred, los scripts de ataque funcionan sin modificación: `validate_target()` acepta cualquier IP con prefijo `172.20.*` y `LAB_TARGET` sigue apuntando a Metasploitable2 por defecto.

---

## 4. Infraestructura Blue Team — Diseño y Decisiones

Cada servidor Blue Team se implementa como un contenedor Docker ligero basado en `ubuntu:22.04`, con servicios reales configurados deliberadamente de forma insegura. Esto es intencional en un laboratorio académico: los servicios deben ser atacables para demostrar el impacto.

### 4.1 bt-web — Servidor Web Apache2 (172.20.0.50)

**Archivo:** `docker/blue-team/bt-web/Dockerfile`

**Servicio:** Apache2 HTTP en puerto 80

**Vulnerabilidades configuradas intencionalmente:**

| Parámetro | Valor configurado | Valor seguro | Impacto |
|---|---|---|---|
| `KeepAliveTimeout` | 300 s | 5 s | Slowloris mantiene conexiones 60× más tiempo |
| `MaxRequestWorkers` | 20 | 150 | HTTP flood agota el pool con ~20 conexiones concurrentes |
| `/server-status` | Expuesto (`Require all granted`) | `Require local` | Revela workers activos, IPs, URIs |
| Basic Auth `/admin` | `admin:admin123`, `webmaster:password` | Política de passwords | Credenciales crackeables con diccionario básico |

**Por qué Apache2 y no Nginx:** Apache2 usa un modelo de workers prefork por defecto, lo que lo hace más susceptible a Slowloris que Nginx (event-driven). Para la demostración DoS, Apache2 produce resultados más visibles y rápidos.

**Objetivo de ataque:** Este es el **target principal del ejercicio DoS final** — los tres vectores (Slowloris, HTTP flood, SYN flood) aplicados a este host demuestran degradación completa del servicio.

---

### 4.2 bt-dns — Servidor DNS BIND9 (172.20.0.51)

**Archivo:** `docker/blue-team/bt-dns/Dockerfile` + `named.conf`

**Servicio:** BIND9 DNS en puerto 53 (TCP y UDP)

**Vulnerabilidades configuradas intencionalmente:**

| Configuración | Estado | Riesgo |
|---|---|---|
| `allow-recursion { any; }` | Habilitado | Open resolver — acepta consultas de cualquier IP |
| `allow-query { any; }` | Habilitado | Sin restricción de clientes |
| Rate limiting (`rate-limit`) | Desactivado | No limita volumen de consultas por origen |
| `dnssec-validation` | `no` | Sin validación de integridad de registros |

**Zona interna configurada:** `lab.local` con registros A para todos los hosts del lab. Esto permite demostrar resolución de nombres interna y ataques de enumeración DNS (`dig`, `nslookup`).

**Objetivo de ataque:** DNS flood UDP con `hping3 --udp -p 53 --flood` — demuestra que un resolver abierto puede ser saturado con tráfico mínimo.

---

### 4.3 bt-smb — Servidor de Archivos Samba (172.20.0.52)

**Archivo:** `docker/blue-team/bt-smb/Dockerfile` + `smb.conf`

**Servicio:** Samba SMB en puertos 139 y 445

**Vulnerabilidades configuradas intencionalmente:**

| Configuración | Estado | Riesgo |
|---|---|---|
| `min protocol = NT1` | SMBv1 habilitado | Compatible con enum4linux, ataques legacy |
| `map to guest = Bad User` | Habilitado | Null sessions — enumeración sin credenciales |
| `server signing = disabled` | Deshabilitado | Vulnerable a relay attacks (MitM) |
| `ntlm auth = yes` + `lanman auth = yes` | Habilitado | NTLMv1 capturable con Responder y crackeable offline |
| Share `[public]` | `guest ok = yes` | Acceso completo sin credenciales |

**Credenciales débiles:** `smbuser:password`, `admin:admin123`

**Por qué Samba y no un servidor Windows:** La imagen `ubuntu:22.04` es ligera (~77 MB antes de instalar Samba) y suficiente para demostrar los vectores relevantes. Un servidor Windows requeriría una licencia y una VM de varios GB.

**Objetivo de ataque:** Enumeración con `enum4linux`, acceso al share público, intento de credenciales con `hydra` o `smbclient`, y SYN flood en puerto 445.

---

### 4.4 bt-mail — Servidor de Correo Postfix (172.20.0.53)

**Archivo:** `docker/blue-team/bt-mail/Dockerfile` + `main.cf`

**Servicio:** Postfix SMTP en puertos 25 y 587

**Vulnerabilidades configuradas intencionalmente:**

| Configuración | Estado | Riesgo |
|---|---|---|
| `mynetworks = 0.0.0.0/0` | Open relay | Acepta relay de correo desde cualquier IP |
| `smtpd_recipient_restrictions = permit_all` | Sin restricción | Acepta cualquier destinatario |
| `smtpd_client_connection_rate_limit = 0` | Sin límite | Vulnerable a SMTP flood |
| `smtpd_sasl_auth_enable = no` | Sin autenticación | Cualquiera puede enviar |

**Credenciales del sistema:** `mailuser:mail123`, `postmaster:admin`

**Objetivo de ataque:** Verificar open relay enviando correo con `telnet` al puerto 25, enumeración de usuarios con `VRFY`, y SYN flood con `hping3 -S -p 25`.

---

## 5. Decisión: Entrypoint Script para Configuración de IP

### El problema

GNS3 no soporta la directiva `ipv4_address` de Docker Compose. En Docker Compose, las IPs fijas se asignan automáticamente por el daemon de Docker. En GNS3, el daemon de Docker de la GNS3 VM levanta los contenedores pero la configuración de red la gestiona GNS3 internamente: conecta las interfaces pero **no configura IPs estáticas** a menos que el contenedor lo haga por sí mismo.

### La solución

Cada Dockerfile incluye un script `/entrypoint.sh` que lee la variable de entorno `CONTAINER_IP` y configura la interfaz `eth0` antes de lanzar el servicio principal:

```bash
#!/bin/bash
if [ -n "${CONTAINER_IP:-}" ]; then
    ip addr add "${CONTAINER_IP}/24" dev eth0 2>/dev/null || true
    ip link set eth0 up
    ip route add default via "${CONTAINER_GW:-172.20.0.1}" dev eth0 2>/dev/null || true
fi
exec "$@"
```

En GNS3 GUI, el template de cada nodo define `CONTAINER_IP=172.20.0.XX` en el campo "Environment". Al arrancar el nodo, el entrypoint configura automáticamente la IP correcta.

### Por qué no usar DHCP

Un servidor DHCP en GNS3 añadiría un nodo adicional con configuración compleja. Las IPs fijas son necesarias porque todos los scripts de ataque tienen `LAB_TARGET`, `BT_WEB`, etc. hardcodeadas como defaults. Con DHCP, las IPs podrían cambiar entre reinicios y los scripts necesitarían descubrimiento dinámico.

---

## 6. Decisión: Dockerfile.gns3 para el Kali

### El problema

En Docker Compose, los scripts de ataque se montan como volumen:
```yaml
volumes:
  - ../scripts:/root/scripts:ro
```

GNS3 no soporta bind mounts de directorios del host Windows. Si el Kali arranca sin `/root/scripts`, ninguna fase de ataque puede ejecutarse.

### Las opciones evaluadas

| Opción | Descripción | Ventaja | Desventaja |
|---|---|---|---|
| **A (elegida)** | Empaquetar scripts en la imagen con `COPY scripts /root/scripts` | Sin dependencias externas, la imagen es autocontenida | Hay que reconstruir y re-transferir la imagen al modificar scripts |
| B | Volumen Docker en la GNS3 VM | Scripts fuera de la imagen, fácil de actualizar | Requiere SSH a la VM y configuración de volumes en GNS3 (no estándar) |
| C | Solo GNS3 para visualización, Docker Compose para ejecución | Cero cambios en el flujo actual | No resuelve el objetivo de tener todo en GNS3 |

### La solución (Opción A)

Se crea `docker/kali/Dockerfile.gns3` — una variante del Dockerfile original que:

1. Usa la raíz del proyecto como build context (no `docker/kali/`)
2. Incluye `COPY scripts /root/scripts` y `COPY playbooks /root/playbooks`
3. Crea `/root/loot` dentro de la imagen (la evidencia vive en el contenedor, no en el host)

**Comando de construcción** (desde la raíz del proyecto):
```
docker build -f docker/kali/Dockerfile.gns3 -t redteam/kali:latest .
```

El Dockerfile original (`docker/kali/Dockerfile`) **no se modifica** — sigue funcionando con Docker Compose exactamente como antes.

---

## 7. Actualización de Scripts

### 7.1 `scripts/lib/common.sh` — mínimo cambio necesario

Se agregan 4 variables para las IPs de infraestructura Blue Team, sobreponibles via entorno (mismo patrón que `LAB_TARGET`):

```bash
BT_WEB="${BT_WEB:-172.20.0.50}"
BT_DNS="${BT_DNS:-172.20.0.51}"
BT_SMB="${BT_SMB:-172.20.0.52}"
BT_MAIL="${BT_MAIL:-172.20.0.53}"
```

`validate_target()` **no se modifica** — ya acepta cualquier IP `172.20.*.*`, por lo que `.50`–`.53` son válidas sin cambio.

Ningún otro script de fases 1–7 se modifica.

### 7.2 `scripts/phase-6-dos/run-dos-window-bt.sh` — orquestador extendido

Se crea un **nuevo script** (no reemplaza `run-dos-window.sh`) con las siguientes características:

- Menú interactivo con 5 opciones de target: Metasploitable2 + 4 servidores Blue Team
- Para targets HTTP (`.20` y `.50`): **reutiliza** los vectores `01-slowloris.sh`, `02-http-flood.sh`, `03-syn-flood.sh` exportando `LAB_TARGET` con el IP seleccionado. Los scripts de vectores no se modifican.
- Para bt-dns (UDP :53): vector DNS flood con `hping3 --udp`
- Para bt-smb (TCP :445): reutiliza `03-syn-flood.sh` con `PORT=445`
- Para bt-mail (TCP :25): vector SMTP SYN flood con `hping3 -S -p 25`

**Por qué no modificar `run-dos-window.sh`:** El script original funciona correctamente para Metasploitable2 y representa el flujo coordinado con Blue Team original. Crear uno nuevo evita regresar el comportamiento del script existente y mantiene separados los flujos "original" y "extendido".

---

## 8. Coexistencia Docker Compose y GNS3

Ambos entornos coexisten en la misma base de código:

| Aspecto | Docker Compose (master) | GNS3 (feat/gns3-migration) |
|---|---|---|
| Imagen Kali | `docker/kali/Dockerfile` (sin scripts) | `docker/kali/Dockerfile.gns3` (con scripts) |
| Red | Bridge Docker automático | Switch L2 virtual en GNS3 |
| IPs | Asignadas por Docker Compose | Configuradas por entrypoint script |
| Volúmenes | Bind mounts desde Windows | Scripts empaquetados en imagen |
| Evidencia | Persiste en `evidence/` en Windows | Vive dentro del contenedor |
| Observabilidad | tcpdump host-side + ntopng | Wireshark integrado por enlace en GNS3 |

**Recomendación de uso:**
- **Desarrollo y pruebas rápidas** → Docker Compose (`docker compose up -d`)
- **Demostración al docente / Blue Team** → GNS3 (visualización topológica, Wireshark integrado)

---

## 9. Estructura de Archivos Generados

```
D:\Project-Red-Team\
├── docker/
│   ├── blue-team/                        [NUEVO]
│   │   ├── bt-web/
│   │   │   └── Dockerfile                [NUEVO]
│   │   ├── bt-dns/
│   │   │   ├── Dockerfile                [NUEVO]
│   │   │   └── named.conf                [NUEVO]
│   │   ├── bt-smb/
│   │   │   ├── Dockerfile                [NUEVO]
│   │   │   └── smb.conf                  [NUEVO]
│   │   └── bt-mail/
│   │       ├── Dockerfile                [NUEVO]
│   │       └── main.cf                   [NUEVO]
│   └── kali/
│       ├── Dockerfile                    [SIN CAMBIOS]
│       ├── Dockerfile.gns3               [NUEVO]
│       └── tools.list                    [SIN CAMBIOS]
├── scripts/
│   ├── lib/
│   │   └── common.sh                     [MODIFICADO — +4 vars BT_*]
│   └── phase-6-dos/
│       ├── run-dos-window.sh             [SIN CAMBIOS]
│       └── run-dos-window-bt.sh          [NUEVO]
└── gns3/
    └── README-gns3-setup.md              [NUEVO]
```

**Scripts que NO se modifican:** `recon.sh`, `port-scan.sh`, `enum-*.sh`, `default-creds.sh`, `brute-force.sh`, `msf-exploit.sh`, `web-sqli.sh`, `web-shells.sh`, `01-slowloris.sh`, `02-http-flood.sh`, `03-syn-flood.sh`, `privesc-check.sh`, `docker-compose.yml`.

---

## 10. Pasos Siguientes

| Paso | Descripción | Dependencia |
|---|---|---|
| 1 | Instalar GNS3 GUI en Windows | Ninguna — puede hacerse ahora |
| 2 | Importar GNS3 VM en VMware/VirtualBox | GNS3 GUI instalado |
| 3 | Construir imagen Kali GNS3 y Blue Team | Docker Desktop + GNS3 VM operativa |
| 4 | Transferir imágenes a GNS3 VM | GNS3 VM con SSH accesible |
| 5 | Configurar templates en GNS3 GUI | Imágenes disponibles en la VM |
| 6 | Construir topología en GNS3 GUI | Templates configurados |
| 7 | Verificar conectividad y servicios | Topología construida |
| 8 | Ejecutar demostración final DoS vs bt-web | Verificación exitosa |

La guía detallada de instalación y configuración de GNS3 está en `gns3/README-gns3-setup.md`.
