FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    squid \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /var/log/squid /etc/supervisor/conf.d

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd

COPY squid.conf /etc/squid/squid.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 3128

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
