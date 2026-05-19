FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

COPY tools.list /tmp/tools.list

RUN apt-get update && \
    xargs apt-get install -y --no-install-recommends < /tmp/tools.list && \
    rm -rf /var/lib/apt/lists/* /tmp/tools.list

WORKDIR /root
