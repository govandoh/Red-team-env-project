FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bind9 \
    bind9utils \
    dnsutils \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Configuracion de open resolver — vulnerable a amplificacion DNS y flood
COPY named.conf /etc/bind/named.conf

# Zona interna lab.local
RUN printf '$TTL 300\n\
@ IN SOA bt-dns.lab.local. admin.lab.local. (\n\
        2026052701 ; serial\n\
        3600       ; refresh\n\
        1800       ; retry\n\
        604800     ; expire\n\
        300 )      ; minimum\n\
  IN NS  bt-dns.lab.local.\n\
bt-dns   IN A 172.20.0.51\n\
bt-web   IN A 172.20.0.50\n\
bt-smb   IN A 172.20.0.52\n\
bt-mail  IN A 172.20.0.53\n\
kali     IN A 172.20.0.10\n' > /etc/bind/db.lab.local

RUN printf '$TTL 300\n\
@ IN SOA bt-dns.lab.local. admin.lab.local. (\n\
        2026052701 2 1800 900 604800 300 )\n\
  IN NS  bt-dns.lab.local.\n\
51 IN PTR bt-dns.lab.local.\n\
50 IN PTR bt-web.lab.local.\n\
52 IN PTR bt-smb.lab.local.\n\
53 IN PTR bt-mail.lab.local.\n' > /etc/bind/db.172.20

RUN chown -R bind:bind /etc/bind /var/cache/bind

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

EXPOSE 53/tcp 53/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
