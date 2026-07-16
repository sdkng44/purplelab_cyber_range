FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cups \
    cups-pdf \
    cups-client \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /var/log/cups /var/spool/cups-pdf

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd

COPY cupsd.conf /etc/cups/cupsd.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 631

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
