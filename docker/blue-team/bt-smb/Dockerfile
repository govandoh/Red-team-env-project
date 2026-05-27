FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    samba \
    samba-common \
    smbclient \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY smb.conf /etc/samba/smb.conf

# Usuarios con credenciales debiles — intencionalmente inseguros (lab academico)
RUN useradd -M -s /sbin/nologin smbuser && \
    useradd -M -s /sbin/nologin admin && \
    (printf 'password\npassword\n') | smbpasswd -a -s smbuser && \
    (printf 'admin123\nadmin123\n') | smbpasswd -a -s admin

# Shares
RUN mkdir -p /srv/samba/public /srv/samba/private && \
    chmod 777 /srv/samba/public && \
    chmod 755 /srv/samba/private && \
    echo "Blue Team SMB Share — bt-smb" > /srv/samba/public/README.txt && \
    echo "Confidential data" > /srv/samba/private/confidential.txt

# bt-smb debe ser resoluble para smbd
RUN echo "127.0.0.1 bt-smb bt-smb.lab.local" >> /etc/hosts

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

EXPOSE 139 445

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/smbd", "--foreground", "--no-process-group", "--debug-stdout"]
