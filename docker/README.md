# Docker Stack — Red Team Lab

## Levantar el stack

```bash
# Stack mínimo: Kali + Metasploitable2
docker compose up -d

# Con clientes Ubuntu adicionales
docker compose --profile full up -d

# Con observabilidad (ntopng en :3000)
docker compose --profile observability up -d

# Con IDS Suricata (avanzado)
docker compose --profile advanced up -d
```

## Acceder al Kali

```bash
docker compose exec kali bash
```

Los scripts están montados en `/root/scripts` (solo lectura).
La evidencia se escribe en `/root/loot` (mapeado a `../evidence/` en el host).

## Resolver el nombre del bridge

Docker genera un nombre de interfaz dinámico para `lab-net`. Para observabilidad:

```bash
docker network inspect lab-net --format '{{.Id}}' | cut -c1-12 | xargs -I{} echo "br-{}"
```

Usa ese nombre en el campo `-i` del servicio `ntopng` en `docker-compose.yml`,
o usa `observability/start-pcap.sh` que lo resuelve automáticamente.

## Rebuild del Kali

```bash
docker compose build --no-cache kali
```

## Teardown

```bash
docker compose down
# Para eliminar también la imagen construida:
docker compose down --rmi local
```
