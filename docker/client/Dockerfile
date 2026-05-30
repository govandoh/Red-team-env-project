# Cliente Ubuntu para GNS3 con herramientas de red mínimas.
# ubuntu:22.04 puro no trae iproute2/ifconfig y la red del lab está aislada
# (sin internet), por lo que no se puede instalar nada en caliente.
# Esta imagen incluye iproute2 + el mismo entrypoint que Kali, que lee
# CONTAINER_IP para auto-configurar la IP al arrancar el contenedor.
#
# Construir en la GNS3 VM:
#   docker build -t redteam/client:latest docker/client/

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        curl \
        netcat-openbsd \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Entrypoint: configura IP desde CONTAINER_IP antes de ejecutar el CMD
RUN printf '#!/bin/bash\n\
if [ -n "${CONTAINER_IP:-}" ]; then\n\
    ip addr add "${CONTAINER_IP}/24" dev eth0 2>/dev/null || true\n\
    ip link set eth0 up\n\
    ip route add default via "${CONTAINER_GW:-172.20.0.1}" dev eth0 2>/dev/null || true\n\
fi\n\
exec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

ENV CONTAINER_IP=""
ENV CONTAINER_GW="172.20.0.1"

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
