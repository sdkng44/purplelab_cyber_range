FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    samba \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /srv/shares/corp /var/log/samba

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd && \
    useradd -m -s /bin/bash ops && echo 'ops:Ops123456!' | chpasswd

RUN (echo 'Analyst123!'; echo 'Analyst123!') | smbpasswd -a -s analyst && \
    (echo 'Ops123456!'; echo 'Ops123456!') | smbpasswd -a -s ops

COPY smb.conf /etc/samba/smb.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 445

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
