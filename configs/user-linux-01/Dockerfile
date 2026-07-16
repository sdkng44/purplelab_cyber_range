FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    gnupg \
    apt-transport-https \
    ca-certificates \
    net-tools \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd && \
    useradd -m -s /bin/bash ops && echo 'ops:Ops123456!' | chpasswd

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY start_wazuh_agent.sh /usr/local/bin/start-wazuh-agent.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/start-wazuh-agent.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
