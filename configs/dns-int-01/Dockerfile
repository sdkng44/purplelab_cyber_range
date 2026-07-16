FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    dnsmasq \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    iproute2 \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /var/log/dnsmasq

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd

COPY dnsmasq.conf /etc/dnsmasq.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 53/tcp 53/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
