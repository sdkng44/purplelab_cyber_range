FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    slapd \
    ldap-utils \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /var/log/slapd

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd

RUN echo "slapd slapd/internal/generated_adminpw password LabLdap123!" | debconf-set-selections && \
    echo "slapd slapd/internal/adminpw password LabLdap123!" | debconf-set-selections && \
    echo "slapd slapd/password2 password LabLdap123!" | debconf-set-selections && \
    echo "slapd slapd/password1 password LabLdap123!" | debconf-set-selections && \
    echo "slapd slapd/domain string corp.lab" | debconf-set-selections && \
    echo "slapd shared/organization string Purple Lab Corp" | debconf-set-selections && \
    echo "slapd slapd/backend string MDB" | debconf-set-selections && \
    echo "slapd slapd/purge_database boolean true" | debconf-set-selections && \
    echo "slapd slapd/move_old_database boolean true" | debconf-set-selections && \
    dpkg-reconfigure -f noninteractive slapd

COPY bootstrap.ldif /opt/bootstrap.ldif
COPY rsyslog-ldap.conf /etc/rsyslog.d/30-ldap.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22 389

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
