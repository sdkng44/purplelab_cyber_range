FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    iproute2 \
    iputils-ping \
    procps \
    sudo \
    vim \
    less \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d

# Usuarios de prueba
RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd && \
    useradd -m -s /bin/bash ops && echo 'ops:Ops123!' | chpasswd

# SSH
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    echo 'LogLevel VERBOSE' >> /etc/ssh/sshd_config

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY start_sandcat_agent.sh /usr/local/bin/start-sandcat-agent.sh
COPY reset_caldera_agent_registration.sh /usr/local/bin/reset-caldera-agent-registration.sh

RUN chmod +x /entrypoint.sh \
    /usr/local/bin/start-sandcat-agent.sh \
    /usr/local/bin/reset-caldera-agent-registration.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
