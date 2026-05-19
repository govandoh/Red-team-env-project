# Observabilidad — Red Team Lab

## Captura de tráfico (host-side)

Los scripts de captura corren en el **host**, no dentro del contenedor Kali, porque necesitan acceso directo a la interfaz bridge del daemon Docker.

### Iniciar captura

```bash
# Requiere root en Linux/macOS
sudo bash observability/start-pcap.sh
```

El script resuelve automáticamente el nombre de la interfaz bridge (`br-XXXXXXXXXXXX`) y escribe el pcap en `evidence/pcap/capture-YYYYMMDD-HHMMSS.pcap`.

### Detener captura

```bash
sudo bash observability/stop-pcap.sh
```

### Abrir en Wireshark

```bash
wireshark evidence/pcap/capture-YYYYMMDD-HHMMSS.pcap
```

Filtros útiles para el informe:
- SYN flood: `tcp.flags.syn == 1 && tcp.flags.ack == 0`
- HTTP flood: `http.request.method == "GET"`
- Slowloris: `tcp.flags.fin == 0 && http` (conexiones abiertas sin cierre)

---

## Dashboard ntopng

Para activar el dashboard de flujos de red en tiempo real:

```bash
# 1. Resolver el nombre del bridge
docker network inspect lab-net --format '{{.Id}}' | cut -c1-12 | xargs -I{} echo "br-{}"

# 2. Actualizar el campo -i en docker/docker-compose.yml (servicio ntopng)

# 3. Levantar con perfil observability
docker compose --profile observability up -d ntopng
```

Acceder en: **http://localhost:3000** (usuario: `admin`, contraseña: `admin` en primer acceso)

---

## IDS Suricata (avanzado)

```bash
docker compose --profile advanced up -d suricata
```

Los alertas quedan en el volumen `suricata-logs` (accesible en `evidence/suricata/` si se monta localmente). Formato EVE JSON, visualizable con `jq` o con Kibana/Splunk.

---

## Resolución del nombre del bridge

Docker genera nombres de interfaz dinámicos. Comando de referencia:

```bash
docker network inspect lab-net --format '{{.Id}}' | cut -c1-12 | xargs -I{} echo "br-{}"
```
