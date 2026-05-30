# Guía de Setup GNS3 — Red Team Lab

Migración del stack Docker Compose a GNS3 con infraestructura Blue Team extendida.

## Topología objetivo

```
                    172.20.0.0/24
                         │
                  [Switch L2 Central]
         ┌──────────┼──────────┼──────────┐
         │          │          │          │
  [Kali .10]  [MSF2 .20]  [Client .30] [Client .31]
                         │
         ┌──────────┼──────────┼──────────┐
         │          │          │          │
  [bt-web .50] [bt-dns .51] [bt-smb .52] [bt-mail .53]
```

| Host | IP | Imagen | Servicio |
|---|---|---|---|
| Kali (atacante) | 172.20.0.10 | `redteam/kali:latest` | Shell + herramientas |
| Metasploitable2 | 172.20.0.20 | `tleemcjr/metasploitable2` | Objetivo clásico |
| Ubuntu Client-1 | 172.20.0.30 | `ubuntu:22.04` | Cliente pasivo |
| Ubuntu Client-2 | 172.20.0.31 | `ubuntu:22.04` | Cliente pasivo |
| BT-Web | 172.20.0.50 | `blueteam/bt-web:latest` | Apache2 — vulnerable a DoS |
| BT-DNS | 172.20.0.51 | `blueteam/bt-dns:latest` | BIND9 — open resolver |
| BT-SMB | 172.20.0.52 | `blueteam/bt-smb:latest` | Samba — credenciales débiles |
| BT-Mail | 172.20.0.53 | `blueteam/bt-mail:latest` | Postfix — open relay |

---

## Fase 1 — Instalar GNS3

### Prerrequisitos

- Windows 11 con VMware Workstation Player (gratuito) o VirtualBox
- Virtualización habilitada en BIOS (Intel VT-x / AMD-V)
- Mínimo 16 GB RAM total | 60 GB espacio libre en disco

### Pasos

1. Descargar desde https://www.gns3.com/software/download (requiere cuenta gratuita):
   - `GNS3-X.X.X-all-in-one-regular.exe` — GUI para Windows
   - `GNS3.VM.VMware.Workstation.X.X.X.zip` — OVA para VMware (**misma versión que la GUI**)

2. Instalar GNS3 GUI como Administrador. Marcar: GNS3 Desktop, Npcap, Wireshark. **NO** marcar "GNS3 VM" en el wizard.

3. Importar la OVA en VMware. Antes de arrancar, configurar la VM:
   - RAM: **8 GB** | CPUs: 2-4
   - Habilitar "Virtualize Intel VT-x/AMD-V" (necesario para Docker dentro de la VM)
   - Adaptador 1: **NAT** (internet para pull de imágenes)
   - Adaptador 2: **Host-Only** (comunicación GUI ↔ VM)

4. Arrancar la GNS3 VM y anotar su IP (ej. `192.168.X.Y` — aparece en la pantalla de la VM).

5. En GNS3 GUI → Edit > Preferences > GNS3 VM → activar → seleccionar VMware → verificar barra verde en la parte inferior.

---

## Fase 2 — Preparar imágenes Docker en la GNS3 VM

Las imágenes deben estar en el Docker daemon de la GNS3 VM (Linux), no en Docker Desktop de Windows.

### 2a. Imagen Kali personalizada (con scripts empaquetados)

La variante para GNS3 usa `Dockerfile.gns3` que incluye los scripts dentro de la imagen. Ejecutar desde la raíz del proyecto en Windows:

```powershell
# Construir desde la raiz del proyecto (no desde docker/kali/)
docker build -f docker/kali/Dockerfile.gns3 -t redteam/kali:latest .

# Exportar
docker save redteam/kali:latest -o C:\Temp\redteam-kali.tar

# Copiar a GNS3 VM (password: gns3)
scp C:\Temp\redteam-kali.tar gns3@192.168.X.Y:/tmp/

# Importar en GNS3 VM
ssh gns3@192.168.X.Y "docker load -i /tmp/redteam-kali.tar"
```

### 2b. Imágenes Blue Team — construir en la GNS3 VM

```powershell
# Copiar Dockerfiles a la GNS3 VM
scp -r docker\blue-team gns3@192.168.X.Y:/tmp/
```

```bash
# En la GNS3 VM (SSH)
docker build -t blueteam/bt-web:latest  /tmp/blue-team/bt-web/
docker build -t blueteam/bt-dns:latest  /tmp/blue-team/bt-dns/
docker build -t blueteam/bt-smb:latest  /tmp/blue-team/bt-smb/
docker build -t blueteam/bt-mail:latest /tmp/blue-team/bt-mail/
```

### 2c. Imágenes públicas — pull directo en la GNS3 VM

```bash
docker pull tleemcjr/metasploitable2:latest
docker pull ubuntu:22.04
```

### Verificar imágenes disponibles

```bash
docker images
# Debe mostrar: redteam/kali, tleemcjr/metasploitable2, ubuntu, blueteam/bt-{web,dns,smb,mail}
```

---

## Fase 3 — Configurar Templates en GNS3 GUI

En GNS3 GUI → Edit > Preferences > Docker containers → **New** para cada template:

### Kali-Attacker
| Campo | Valor |
|---|---|
| Image | `redteam/kali:latest` |
| Adapters | 1 |
| Start command | `/bin/bash` |
| Console type | `telnet` |
| Environment | `CONTAINER_IP=172.20.0.10` |

> Nota: GNS3 corre los contenedores en modo privileged (todas las capabilities), así que `NET_ADMIN`/`NET_RAW` para hping3/tcpdump ya están disponibles sin configurar nada extra.

### Metasploitable2
| Campo | Valor |
|---|---|
| Image | `tleemcjr/metasploitable2:latest` |
| Adapters | 1 |
| Privileged mode | checked |
| Environment | `CONTAINER_IP=172.20.0.20` |

### Ubuntu-Client (crear dos instancias con distinto CONTAINER_IP)
| Campo | Valor |
|---|---|
| Image | `ubuntu:22.04` |
| Start command | `sleep infinity` |
| Environment | `CONTAINER_IP=172.20.0.30` / `CONTAINER_IP=172.20.0.31` |

### BT-Web
| Campo | Valor |
|---|---|
| Image | `blueteam/bt-web:latest` |
| Environment | `CONTAINER_IP=172.20.0.50` |

### BT-DNS
| Campo | Valor |
|---|---|
| Image | `blueteam/bt-dns:latest` |
| Environment | `CONTAINER_IP=172.20.0.51` |

### BT-SMB
| Campo | Valor |
|---|---|
| Image | `blueteam/bt-smb:latest` |
| Environment | `CONTAINER_IP=172.20.0.52` |

### BT-Mail
| Campo | Valor |
|---|---|
| Image | `blueteam/bt-mail:latest` |
| Environment | `CONTAINER_IP=172.20.0.53` |

---

## Fase 4 — Construir la topología en GNS3 GUI

1. File > New blank project → nombre: `red-team-lab`
2. Arrastrar al canvas desde el panel de templates:
   - 1× Kali-Attacker
   - 1× Metasploitable2
   - 2× Ubuntu-Client
   - 1× BT-Web, 1× BT-DNS, 1× BT-SMB, 1× BT-Mail
   - 1× **Ethernet Switch** (panel "Switches" — nativo en GNS3)
3. Conectar cada nodo al switch central con cables Ethernet (drag entre puertos)
4. Guardar el proyecto (Ctrl+S)
5. Respaldar el archivo generado en el repo:

```powershell
# La topologia queda en Documents\GNS3\projects\red-team-lab\
# Copiar al repo para version control
copy "$env:USERPROFILE\Documents\GNS3\projects\red-team-lab\red-team-lab.gns3" D:\Project-Red-Team\gns3\
```

---

## Verificación end-to-end

Arrancar todos los nodos en GNS3 (clic derecho en el switch → Start). Luego desde la consola del Kali (doble clic en el nodo):

```bash
# 1. Verificar IP configurada
ip addr show eth0   # esperado: 172.20.0.10/24

# 2. Ping sweep
for ip in 172.20.0.20 172.20.0.50 172.20.0.51 172.20.0.52 172.20.0.53; do
    ping -c1 -W2 "$ip" && echo "$ip UP" || echo "$ip DOWN"
done

# 3. Servicios Blue Team respondiendo
curl -s -o /dev/null -w "%{http_code}" http://172.20.0.50/     # 200
dig @172.20.0.51 lab.local ANY                                  # respuesta DNS
smbclient -L //172.20.0.52 -N                                   # lista shares
nc -w3 172.20.0.53 25                                           # banner SMTP 220

# 4. Scripts existentes sin cambio
bash /root/scripts/lib/test-common.sh
bash /root/scripts/phase-1-recon/recon.sh

# 5. Demo — botar bt-web
bash /root/scripts/phase-6-dos/run-dos-window-bt.sh   # seleccionar opción 2
# En segunda terminal:
LAB_TARGET=172.20.0.50 bash /root/scripts/phase-6-dos/99-monitor.sh 80
# Exito: monitor reporta HTTP 000 / timeout
```

---

## Solución de problemas comunes

**Las IPs no se configuran al arrancar un nodo**

Si el contenedor no tiene `ip` disponible, asignar manualmente desde la consola GNS3:
```bash
ip addr add 172.20.0.10/24 dev eth0
ip link set eth0 up
```

**`hping3` o `tcpdump` — capabilities de red**

No aplica en GNS3 2.2: el servidor ejecuta TODOS los contenedores Docker en **modo privileged** (`CapAdd=[ALL]`, `CapEff=000001ffffffffff`), por lo que `NET_ADMIN` y `NET_RAW` ya están disponibles. Verificado empíricamente: `tcpdump` captura y `hping3 -S` recibe SYN-ACK sin ajustes. El campo "Extra host capabilities" del template es innecesario (y la API REST de templates lo rechaza).

**smbd no inicia — error "Failed to find target server"**

El hostname `bt-smb` debe ser resoluble. Verificar que `/etc/hosts` dentro del contenedor contiene `127.0.0.1 bt-smb`.

**Postfix no inicia**

Ejecutar desde la consola del nodo bt-mail:
```bash
postfix check
postfix start
```

**Reconstruir y redeployar scripts después de cambios**

Los scripts están empaquetados dentro de la imagen Kali para GNS3. Después de modificar cualquier script:
```powershell
# Reconstruir imagen Kali (desde raiz del proyecto)
docker build -f docker/kali/Dockerfile.gns3 -t redteam/kali:latest .
docker save redteam/kali:latest -o C:\Temp\redteam-kali.tar
scp C:\Temp\redteam-kali.tar gns3@192.168.X.Y:/tmp/
ssh gns3@192.168.X.Y "docker load -i /tmp/redteam-kali.tar"
# Reiniciar el nodo Kali en GNS3
```

---

## Coexistencia con Docker Compose

El stack Docker Compose en `docker/docker-compose.yml` sigue funcionando independientemente. Son dos entornos separados:

| Entorno | Uso | Comando |
|---|---|---|
| Docker Compose | Desarrollo, dry runs rápidos | `docker compose up -d` |
| GNS3 | Demostración, topología visual, Blue Team extendido | Arrancar en GNS3 GUI |
