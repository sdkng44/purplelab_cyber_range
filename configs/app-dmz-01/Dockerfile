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
    python3 \
    python3-pip \
    python3-venv \
    net-tools \
    iproute2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /var/log/purple-web /opt/purple-web

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true

COPY requirements.txt /opt/purple-web/requirements.txt

RUN python3 -m venv /opt/purple-web/venv && \
    /opt/purple-web/venv/bin/pip install --upgrade pip setuptools wheel && \
    /opt/purple-web/venv/bin/pip install -r /opt/purple-web/requirements.txt

COPY app.py /opt/purple-web/app.py
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY start_wazuh_agent.sh /usr/local/bin/start-wazuh-agent.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/start-wazuh-agent.sh

WORKDIR /opt/purple-web

EXPOSE 22 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
