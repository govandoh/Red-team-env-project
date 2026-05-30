# Manual de Ejecución — Topología GNS3
## Red Team Lab · Redes 2 · Ciclo 2026

Manual operativo para **arrancar, demostrar y botar servicios** en la topología GNS3.
Complementa al `reports/MANUAL_DEMOSTRACION.md` (que cubre el flujo Docker Compose).

---

## Índice

1. [Arquitectura y switches](#1-arquitectura-y-switches)
2. [Visualizar la topología en GNS3 GUI — paso a paso](#2-visualizar-la-topología-en-gns3-gui--paso-a-paso)
3. [Arrancar la topología](#3-arrancar-la-topología)
4. [Abrir consolas de los nodos](#4-abrir-consolas-de-los-nodos)
5. [Demostración estrella — botar bt-web (DoS)](#5-demostración-estrella--botar-bt-web-dos)
6. [Otros servicios Blue Team como target](#6-otros-servicios-blue-team-como-target)
7. [Fases de ataque clásicas (Metasploitable2)](#7-fases-de-ataque-clásicas)
8. [Recoger evidencia](#8-recoger-evidencia)
9. [Detener la topología](#9-detener-la-topología)
10. [Solución de problemas](#10-solución-de-problemas)
11. [Escenario multi-equipo (otra PC en la misma red)](#11-escenario-multi-equipo-otra-pc-en-la-misma-red)

---

## 1. Arquitectura y switches

La topología usa **un único switch Ethernet de capa 2** (`Switch-Central`, 16 puertos) que conecta los 9 nodos en la subred `172.20.0.0/24`.

```
                          172.20.0.0/24
                     [ Switch-Central · L2 · 16p ]
        ┌───────┬───────┬──────┼──────┬───────┬───────┬───────┐
      Eth0    Eth1    Eth2   Eth3   Eth4    Eth5    Eth6    Eth7
        │       │       │      │      │       │       │       │
   🔴 Kali   MSF2   Ub-1   Ub-2  bt-web  bt-dns  bt-smb  bt-mail
      .10    .20    .30    .31    .50     .51     .52     .53
```

| Puerto switch | Nodo | IP | Rol |
|---|---|---|---|
| Ethernet0 | Kali-Attacker | 172.20.0.10 | 🔴 Atacante (Red Team) |
| Ethernet1 | Metasploitable2 | 172.20.0.20 | 🔵 Objetivo clásico |
| Ethernet2 | Ubuntu-Client-1 | 172.20.0.30 | Cliente pasivo |
| Ethernet3 | Ubuntu-Client-2 | 172.20.0.31 | Cliente pasivo |
| Ethernet4 | bt-web | 172.20.0.50 | 🔵 Apache2 — **target DoS principal** |
| Ethernet5 | bt-dns | 172.20.0.51 | 🔵 BIND9 open resolver |
| Ethernet6 | bt-smb | 172.20.0.52 | 🔵 Samba inseguro |
| Ethernet7 | bt-mail | 172.20.0.53 | 🔵 Postfix open relay |

**Tipo de switch:** Ethernet switch nativo de GNS3 (no gestionado, modo access, VLAN 1). No requiere imagen ni configuración — es un nodo integrado de GNS3.

---

## 2. Visualizar la topología en GNS3 GUI — paso a paso

> **Dónde vive el proyecto.** El proyecto **NO está en el disco de Windows**. Vive dentro de la **GNS3 VM** (el servidor GNS3 corre en esa VM). No busques un archivo `.gns3` en `C:\` — se abre desde la GUI **conectada a la VM**.

### Rutas de referencia

| Qué | Ruta |
|---|---|
| Proyecto en la GNS3 VM (servidor) | `/opt/gns3/projects/be75d0fb-1988-48cd-8cef-55dfa91c8aba/red-team-lab.gns3` |
| GNS3 GUI instalada en Windows | `C:\Program Files\GNS3\gns3.exe` |
| Config/inventario de GNS3 GUI (Windows) | `%APPDATA%\GNS3\gns3_gui.conf` |
| VM de VMware (archivo .vmx) | `C:\Users\govan\Documents\Virtual Machines\GNS3-VM\GNS3-VM.vmx` |
| IP del servidor GNS3 (la VM) | `192.168.116.128` (puerto 80) |

### Paso 2.1 — Arrancar la GNS3 VM en VMware

1. Abre **VMware Workstation**.
2. En la biblioteca selecciona **GNS3-VM** y pulsa **Power on this virtual machine** (▶).
3. Espera a la pantalla negra de la VM. Debe mostrar un recuadro con:
   ```
   GNS3 server
   Version: 2.2.59
   Running on: http://192.168.116.128
   ```
4. **Anota la IP** que aparece ahí. Si NO es `192.168.116.128`, VMware reasignó DHCP — usa la nueva IP en todos los comandos de este manual.

### Paso 2.2 — Conectar GNS3 GUI a la VM

1. Abre **GNS3 GUI** (`C:\Program Files\GNS3\gns3.exe`).
2. Mira la **barra inferior**: el indicador del servidor *GNS3 VM* debe estar **verde**.
3. Si está rojo/gris: **Edit → Preferences → GNS3 VM** → marca **Enable the GNS3 VM**, selecciona **VMware Workstation**, elige la VM `GNS3-VM` y pulsa **OK**. Espera a que la barra cambie a verde.
4. Verificación rápida: **Edit → Preferences → Server** muestra `Main server` con host `192.168.116.128`.

### Paso 2.3 — Abrir el proyecto (IMPORTANTE: usar Import, no Open)

> **No uses `File → Open project`.** Ese diálogo es el **explorador de archivos de Windows** y solo ve proyectos guardados en el disco local (`C:\Users\<tu_usuario>\GNS3\projects\`). El proyecto `red-team-lab` vive en la **GNS3 VM** (servidor remoto), así que **nunca aparecerá** en ese diálogo.

**Vía correcta — importar el proyecto portable:**

1. Si tienes abierto el diálogo "Open project", pulsa **Cancelar**.
2. Menú **File → Import portable project**.
3. Navega a **`D:\Project-Red-Team\gns3\red-team-lab.gns3project`** y pulsa **Abrir**.
4. Cuando pregunte el nombre/servidor, deja **`red-team-lab`** y elige el servidor **GNS3 VM**. Pulsa **OK**.
5. El proyecto se abre y el canvas muestra los 8 nodos + el switch central.
6. Arranca los nodos (▶ Start, ver §3).

> El archivo `.gns3project` se regenera en cualquier momento desde Windows:
> ```powershell
> $base="http://192.168.116.128/v2"; $p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
> Invoke-RestMethod "$base/projects/$p/close" -Method Post -ContentType "application/json" -Body "{}"
> Invoke-WebRequest "$base/projects/$p/export?include_images=no" -OutFile D:\Project-Red-Team\gns3\red-team-lab.gns3project
> ```

### Paso 2.4 — Qué se ve en el canvas

Al abrir, el **canvas** (área central) muestra la topología completa:

```
   Kali-Attacker   Metasploitable2   Ubuntu-Client-1   Ubuntu-Client-2
        │                │                  │                 │
        └────────────────┴──────[ Switch-Central ]────────────┘
                                   │     │    │
                  bt-web ──────────┘     │    └────────── bt-mail
                            bt-dns ──────┴────── bt-smb
```

- **Iconos de nodo:** cada contenedor aparece con su nombre y un punto de estado
  (🟢 verde = corriendo, 🔴 rojo = detenido).
- **Switch-Central:** icono de switch en el centro, con 8 enlaces saliendo a los nodos.
- **Enlaces:** líneas entre cada nodo y el switch. Con los nodos corriendo, un
  **punto verde** en cada extremo indica enlace activo.

**Mejorar la lectura del diagrama (opcional):**
- **View → Show/Hide interface labels** → muestra `eth0` / `Ethernet0` en cada enlace.
- **View → Snap to grid** → alinea los iconos.
- Clic derecho en un nodo → **Change symbol** para usar iconos más descriptivos
  (ej. servidor para los bt-*, atacante para Kali).
- Clic derecho en el canvas → **Add a note** para etiquetar la subred `172.20.0.0/24`.

### Paso 2.5 — Ver el tráfico en vivo (Wireshark por enlace)

GNS3 integra captura Wireshark por enlace, ideal para demostrar el DoS al Blue Team:

1. **Clic derecho sobre el enlace** entre `Kali-Attacker` y `Switch-Central` (o sobre el enlace de `bt-web`).
2. Selecciona **Start capture**.
3. Se abre **Wireshark** mostrando los paquetes en tiempo real de ese enlace.
4. Durante la demo DoS (§5) verás el flujo de Slowloris / SYN flood en vivo.

> Si Wireshark no abre, instálalo en Windows y verifícalo en **Edit → Preferences → Wireshark** (ruta del ejecutable).

---

## 3. Arrancar la topología

### Opción A — desde GNS3 GUI
Clic en el botón **▶ Start/Resume all nodes** (barra superior). Los nodos pasan a verde.

### Opción B — desde Windows (PowerShell, vía API)
```powershell
$base="http://192.168.116.128/v2"; $p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
Invoke-RestMethod "$base/projects/$p/open"  -Method Post -ContentType "application/json" -Body "{}"
Invoke-RestMethod "$base/projects/$p/nodes/start" -Method Post
```

**Verificar conectividad end-to-end** (sube y ejecuta el script de verificación):
```powershell
$lf=(Get-Content D:\Project-Red-Team\gns3\verify-sweep.sh -Raw)-replace "`r`n","`n"
[IO.File]::WriteAllText("$env:TEMP\verify-sweep.sh",$lf)
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw gns3 "$env:TEMP\verify-sweep.sh" gns3@192.168.116.128:/tmp/
plink -batch -pw gns3 gns3@192.168.116.128 "docker exec -i GNS3.Kali-Attacker.$p bash < /tmp/verify-sweep.sh"
```
Salida esperada: 7 IPs `UP`, bt-web `200`, bt-smb shares, bt-mail `220`, MSF2 puertos abiertos.

---

## 4. Abrir consolas de los nodos

**Desde GNS3 GUI:** doble clic en cualquier nodo → abre una consola **telnet** (PuTTY/terminal integrada). El Kali abre una shell `bash`.

**Desde Windows (sin GUI):**
```powershell
$p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
plink -batch -pw gns3 gns3@192.168.116.128 "docker exec -it GNS3.Kali-Attacker.$p bash"
```

> Los nombres de contenedor siguen el patrón `GNS3.<NombreNodo>.<project_id>`.

---

## 5. Demostración estrella — botar bt-web (DoS)

bt-web es un Apache2 configurado con `MaxRequestWorkers=20` y `KeepAliveTimeout=300` — basta con un Slowloris de 500 conexiones lentas para agotar su pool de workers y tumbarlo.

### Ejecución automatizada (one-shot)

```powershell
$p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
$lf=(Get-Content D:\Project-Red-Team\gns3\demo-dos-btweb.sh -Raw)-replace "`r`n","`n"
[IO.File]::WriteAllText("$env:TEMP\demo.sh",$lf)
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw gns3 "$env:TEMP\demo.sh" gns3@192.168.116.128:/tmp/demo.sh
plink -batch -pw gns3 gns3@192.168.116.128 "docker exec -i GNS3.Kali-Attacker.$p bash < /tmp/demo.sh"
```

El script: captura baseline → lanza monitor + pcap → ejecuta Slowloris 60s → verifica recuperación → imprime resumen.

### Resultado verificado (2026-05-30)

```
--- Línea de tiempo (http_code por segundo) ---
  08:23:37  code=200  (baseline — servicio normal)
  08:23:42  code=000  (BOTADO — timeout durante Slowloris)
  08:24:42  code=200  (recuperado tras detener el ataque)

Recuperacion final: 200 en 0.0027s
```

El servicio pasó de `200` a `000` (timeout) durante el ataque y se recuperó al terminar. **DoS demostrado.**

### Ejecución manual e interactiva (para presentar en vivo)

Abre **dos consolas del Kali** en GNS3 GUI:

**Consola 1 — monitor** (deja corriendo, muestra el impacto en vivo):
```bash
LAB_TARGET=172.20.0.50 bash /root/scripts/phase-6-dos/99-monitor.sh 80
```

**Consola 2 — orquestador de ataque:**
```bash
PAUSE_BETWEEN_VECTORS=30 bash /root/scripts/phase-6-dos/run-dos-window-bt.sh
```
- Selecciona **`2`** (bt-web) → escribe `YES` → escribe `y` para el Vector 1 (Slowloris).
- En la Consola 1 verás `200` cambiar a `000`.

### Verificar recuperación manual
```bash
curl -s -o /dev/null -w "%{http_code} - %{time_total}s\n" http://172.20.0.50/
```

---

## 6. Otros servicios Blue Team como target

El orquestador `run-dos-window-bt.sh` ofrece 5 targets:

| Opción | Target | Servicio | Vector |
|---|---|---|---|
| 1 | 172.20.0.20 | Metasploitable2 :80 | Slowloris + HTTP flood + SYN flood |
| 2 | 172.20.0.50 | bt-web :80 | Slowloris + HTTP flood + SYN flood |
| 3 | 172.20.0.51 | bt-dns :53 | DNS UDP flood (`hping3 --udp`) |
| 4 | 172.20.0.52 | bt-smb :445 | SYN flood |
| 5 | 172.20.0.53 | bt-mail :25 | SYN flood |

> **Nota:** todos los vectores funcionan porque GNS3 ejecuta los contenedores Docker en **modo privileged** (todas las capabilities, incluidas NET_RAW/NET_ADMIN). hping3 y tcpdump operan sin ajustes.

---

## 7. Fases de ataque clásicas

Las fases 1–7 contra Metasploitable2 funcionan igual que en Docker Compose, ejecutándolas desde la consola del Kali (los scripts están empaquetados en `/root/scripts`):

```bash
# Fase 1 — Recon
LAB_TARGET=172.20.0.20 bash /root/scripts/phase-1-recon/recon.sh
# Fase 2 — Scan
LAB_TARGET=172.20.0.20 bash /root/scripts/phase-2-scanning/port-scan.sh
# Fase 3 — Enum HTTP
LAB_TARGET=172.20.0.20 bash /root/scripts/phase-3-enumeration/enum-http.sh
# Fase 4 — Credenciales
LAB_TARGET=172.20.0.20 bash /root/scripts/phase-4-credentials/default-creds.sh
# Fase 5 — Explotación web
LAB_TARGET=172.20.0.20 bash /root/scripts/phase-5-exploitation/web-shells.sh
# Fase 7 — Post-explotación
LAB_TARGET=172.20.0.20 SSH_USER=msfadmin SSH_PASS=msfadmin bash /root/scripts/phase-7-post-exploitation/privesc-check.sh
```

El detalle paso a paso de cada fase está en `reports/MANUAL_DEMOSTRACION.md` (secciones 4–10) — la metodología es idéntica.

---

## 8. Recoger evidencia

La evidencia vive **dentro del contenedor Kali** (en GNS3 no hay bind mount al host):

```powershell
$p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
# Listar evidencia
plink -batch -pw gns3 gns3@192.168.116.128 "docker exec GNS3.Kali-Attacker.$p find /root/loot -type f"
# Copiar al host (VM -> /tmp, luego pscp a Windows)
plink -batch -pw gns3 gns3@192.168.116.128 "docker cp GNS3.Kali-Attacker.$p`:/root/loot /tmp/loot"
& "C:\Program Files\PuTTY\pscp.exe" -batch -pw gns3 -r gns3@192.168.116.128:/tmp/loot D:\Project-Red-Team\evidence-gns3
```

La demo DoS genera: `baseline-curl.csv`, `monitor.csv`, `slowloris-report.html`, `slowloris.pcap`, `slowloris.log`.

---

## 9. Detener la topología

### Opción A — GNS3 GUI
Botón **⏹ Stop all nodes**. Para cerrar: **File → Close project**.

### Opción B — Windows
```powershell
$base="http://192.168.116.128/v2"; $p="be75d0fb-1988-48cd-8cef-55dfa91c8aba"
Invoke-RestMethod "$base/projects/$p/nodes/stop" -Method Post
```

> No apagues la GNS3 VM bruscamente con nodos corriendo — deja contenedores huérfanos (ver §10).

---

## 10. Solución de problemas

| Problema | Causa | Solución |
|---|---|---|
| `409 Conflict ... container name already in use` al abrir el proyecto | La VM se reinició/apagó con nodos corriendo; quedaron contenedores Docker huérfanos | `plink -batch -pw gns3 gns3@192.168.116.128 "docker ps -aq --filter name=GNS3 \| xargs -r docker rm -f"` y reabrir |
| Un nodo no toma IP | Cambio de config no aplicado (GNS3 reutiliza el contenedor) | Borrar y **recrear** el nodo desde el template (no basta con stop/start) |
| `bt-mail` sin banner SMTP | (Resuelto) `main.cf` tenía `permit_all` inválido | Ya corregido — usa `permit_mynetworks, reject_unauth_destination` |
| Ubuntu clients sin IP | `ubuntu:22.04` puro no trae net tools | Usan imagen `redteam/client:latest` (con iproute2) |
| API GNS3 no responde | VM apagada o IP cambiada | Verificar VMware; confirmar IP en pantalla de la VM |
| hping3/tcpdump "fallan" | — | No aplica: GNS3 corre los contenedores en modo privileged, todas las caps disponibles |

---

## 11. Escenario multi-equipo (otra PC en la misma red)

Escenario realista: **otro integrante del equipo, en otra computadora de la misma red WiFi/LAN**, participa en el laboratorio (opera la topología o ataca los servicios). Por defecto **no es posible** por cómo están aisladas las redes. Esta sección explica por qué y cómo habilitarlo.

### 11.1 Las tres capas de red (por qué no es accesible por defecto)

```
[ Otra PC del equipo ]        192.168.1.x        ← red WiFi/LAN fisica
        │ (192.168.1.0/24)
[ Tu PC (Windows) ]           192.168.1.3 (Wi-Fi) + 192.168.116.1 (VMnet3)
        │ (red host-only VMware VMnet3, 192.168.116.0/24)
[ GNS3 VM ]                   192.168.116.128
        │ (switch virtual GNS3, interno a la VM)
[ Topología ]                 172.20.0.0/24  (Kali, bt-web, bt-dns, ...)
```

- La **GNS3 VM** está en **VMnet3 (host-only)**: solo tu PC Windows la ve. Otra PC en la WiFi **no alcanza** `192.168.116.128`.
- La **red de la topología** (`172.20.0.0/24`) vive en el **switch virtual de GNS3**, interno a la VM: ni siquiera tu PC Windows la alcanza directamente.

Hay que tender un puente. El método depende del objetivo.

> Sustituye las IPs por las tuyas: tu Wi-Fi es `192.168.1.3`, la GNS3 VM `192.168.116.128`. Confírmalas con `ipconfig` (Windows) y la pantalla de la VM.

### 11.2 Objetivo A (recomendado) — Otra PC OPERA la misma topología (GNS3 GUI remoto)

Dos integrantes ven y controlan la **misma** topología en tiempo real. El Kali y los targets siguen en la VM; cada quien abre consolas y lanza ataques desde su propio GNS3 GUI. Es el escenario multi-equipo más simple y robusto.

**Paso 1 — Hacer la GNS3 VM accesible desde la WiFi (modo Bridged):**

1. Apaga la GNS3 VM (o detén los nodos y ciérrala).
2. VMware Workstation → selecciona **GNS3-VM** → **Edit virtual machine settings** → **Network Adapter** (el de VMnet3).
3. Cambia a **Bridged (Automatic)** → marca **Replicate physical network connection state**. (Alternativa: **Add** un tercer adaptador en Bridged y deja VMnet3.)
4. Arranca la VM. Ahora obtiene una IP **de la WiFi** (ej. `192.168.1.50`). Anótala de la pantalla de la VM.
5. Desde otra PC, comprueba: `ping 192.168.1.50`.

> Bridged **cambia la IP de la GNS3 VM**. Actualiza esa IP en todos los comandos de este manual (API `http://<nueva_ip>/v2`, `plink ... gns3@<nueva_ip>`).

**Paso 2 — Configurar el GNS3 GUI de la otra PC:**

1. En la otra PC instala **GNS3 GUI** (misma versión: 2.2.59).
2. **Edit → Preferences → Server** → desmarca *Enable local server* → en *Main server* pon **Host = `192.168.1.50`**, **Port = 80**, sin autenticación → **OK**.
3. **File → Import portable project** → usa `red-team-lab.gns3project` (cópialo a la otra PC), o si tu PC ya lo tiene abierto en el servidor, aparecerá al conectar.
4. Ambos GUIs apuntan al mismo servidor: cualquiera arranca nodos, abre consolas (doble clic en Kali) y ejecuta las fases/DoS. Los cambios se ven en ambas pantallas.

### 11.3 Objetivo B (avanzado) — Otra PC ATACA los servicios desde afuera (Red Team externo real)

Aquí la otra PC usa **su propio Kali/navegador** para atacar `bt-web` y compañía. Requiere sacar la red `172.20.0.0/24` de GNS3 hacia la red física mediante un **nodo Cloud** (puente L2 de GNS3 a una interfaz de la VM).

1. En GNS3 GUI, arrastra un nodo **Cloud** al canvas.
2. Conéctalo con un cable al **Switch-Central** (a un puerto libre, ej. Ethernet8).
3. Doble clic en el Cloud → pestaña de interfaces → selecciona la interfaz de la VM que esté en **Bridged** a la WiFi (la del Paso 1 de §11.2).
4. Inicia el Cloud. Ahora el segmento `172.20.0.0/24` queda **puenteado** a la WiFi a nivel L2.
5. En la otra PC (su Kali), para entrar a ese segmento:
   - Asigna una IP del rango: `ip addr add 172.20.0.99/24 dev <iface_wifi>` **o** deja que el switch la enrute si hay gateway.
   - Ataca directamente: `curl http://172.20.0.50/`, `nmap 172.20.0.0/24`, etc.

> **Advertencia:** este es el punto que falló en intentos previos ("Cloud node mal configurado"). Requiere que el Cloud apunte a la interfaz **bridged correcta** y que la otra PC esté en la misma subred L2. Es sensible a la config de VMware y del firewall. Para una demo confiable, el **Objetivo A** es más predecible.

### 11.4 Alternativa sin Bridged — Port forwarding desde tu PC

Si no quieres cambiar la red de la VM (mantener `192.168.116.128`), tu PC Windows puede hacer de **puente** reenviando puertos de la WiFi hacia la VM. Útil para exponer la **API GNS3** o un **servicio puntual**.

En PowerShell **como Administrador** en tu PC:
```powershell
# Exponer la API GNS3 (puerto 80 de la VM) en tu IP WiFi
netsh interface portproxy add v4tov4 listenaddress=192.168.1.3 listenport=3080 `
    connectaddress=192.168.116.128 connectport=80
# Abrir el puerto en el firewall
New-NetFirewallRule -DisplayName "GNS3 API LAN" -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 3080
```
Desde otra PC: `http://192.168.1.3:3080/v2/version` llega a la API GNS3.

Para deshacerlo:
```powershell
netsh interface portproxy delete v4tov4 listenaddress=192.168.1.3 listenport=3080
Remove-NetFirewallRule -DisplayName "GNS3 API LAN"
```

> Exponer las **consolas** de los nodos por este método requiere reenviar también su rango de puertos (GNS3 los asigna dinámicamente, ~5000+), por lo que para GUI remoto completo el **modo Bridged (§11.2)** es más práctico.

### 11.5 Resumen de decisión

| Quiero que otra PC… | Método | Complejidad |
|---|---|---|
| Vea/opere la misma topología (colaborar) | §11.2 Bridged + GUI remoto | Baja ✅ |
| Solo consulte la API/un servicio puntual | §11.4 Port forwarding | Baja |
| Ataque los servicios con su propio Kali | §11.3 Cloud node | Alta ⚠️ |

---

## Referencia rápida — IPs y credenciales

| Componente | IP | Usuario | Contraseña |
|---|---|---|---|
| Kali (atacante) | 172.20.0.10 | root | — |
| Metasploitable2 | 172.20.0.20 | msfadmin | msfadmin |
| bt-web `/admin` | 172.20.0.50 | admin | admin123 |
| bt-smb | 172.20.0.52 | smbuser | password |
| bt-mail | 172.20.0.53 | mailuser | mail123 |
| GNS3 VM (SSH) | 192.168.116.128 | gns3 | gns3 |
| GNS3 API REST | http://192.168.116.128/v2 | — | (sin auth) |
