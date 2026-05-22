FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

COPY tools.list /tmp/tools.list

RUN apt-get update && \
    xargs apt-get install -y --no-install-recommends < /tmp/tools.list && \
    rm -rf /var/lib/apt/lists/* /tmp/tools.list

# Pre-bundle linpeas so phase-7 works without internet at runtime
RUN curl --fail --location --silent --show-error \
    "https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh" \
    -o /opt/linpeas.sh && chmod +x /opt/linpeas.sh

WORKDIR /root
