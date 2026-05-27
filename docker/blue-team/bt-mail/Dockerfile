FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    postfix \
    mailutils \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY main.cf /etc/postfix/main.cf

# Usuarios con credenciales debiles — intencionalmente inseguros (lab academico)
RUN useradd -m -s /bin/bash mailuser && \
    echo "mailuser:mail123" | chpasswd && \
    useradd -m -s /bin/bash postmaster && \
    echo "postmaster:admin" | chpasswd

RUN mkdir -p /var/mail && \
    touch /var/mail/mailuser && \
    chown mailuser:mail /var/mail/mailuser

# Inicializar estructura de postfix y aliases
RUN postfix check 2>/dev/null || true && newaliases

# Entrypoint: configura IP antes de iniciar el servicio
RUN printf '#!/bin/bash\n\
if [ -n "${CONTAINER_IP:-}" ]; then\n\
    ip addr add "${CONTAINER_IP}/24" dev eth0 2>/dev/null || true\n\
    ip link set eth0 up\n\
    ip route add default via "${CONTAINER_GW:-172.20.0.1}" dev eth0 2>/dev/null || true\n\
fi\n\
exec "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

ENV CONTAINER_IP=""
ENV CONTAINER_GW="172.20.0.1"

EXPOSE 25 587

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/lib/postfix/sbin/master", "-d"]
