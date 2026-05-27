FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 \
    apache2-utils \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# KeepAliveTimeout alto = vulnerable a Slowloris (default es 5s)
RUN sed -i 's/KeepAliveTimeout 5/KeepAliveTimeout 300/' /etc/apache2/apache2.conf

# MaxRequestWorkers bajo = HTTP flood la agota con ~20 conexiones concurrentes
RUN printf '<IfModule mpm_prefork_module>\n\
  StartServers 2\n\
  MinSpareServers 2\n\
  MaxSpareServers 5\n\
  MaxRequestWorkers 20\n\
  MaxConnectionsPerChild 0\n\
</IfModule>\n' > /etc/apache2/mods-available/mpm_prefork.conf

# Pagina de inicio
RUN echo "<h1>bt-web — Blue Team Web Server</h1><p>Apache/2.x Ubuntu Lab</p>" \
    > /var/www/html/index.html

# Credenciales debiles para /admin — intencionalmente inseguras (lab academico)
RUN htpasswd -cb /etc/apache2/.htpasswd admin admin123 && \
    htpasswd -b /etc/apache2/.htpasswd webmaster password

RUN mkdir -p /var/www/html/admin && \
    echo "<h1>Admin Panel</h1>" > /var/www/html/admin/index.html && \
    printf '\n<Directory "/var/www/html/admin">\n\
  AuthType Basic\n\
  AuthName "Admin Area"\n\
  AuthUserFile /etc/apache2/.htpasswd\n\
  Require valid-user\n\
</Directory>\n' >> /etc/apache2/sites-available/000-default.conf

# /server-status expuesto sin restriccion de IP (information disclosure)
RUN a2enmod status && \
    sed -i 's/Require local/Require all granted/' /etc/apache2/mods-available/status.conf

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

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
