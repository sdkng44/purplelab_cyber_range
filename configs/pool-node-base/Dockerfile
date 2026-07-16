FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    rsyslog \
    supervisor \
    curl \
    ca-certificates \
    python3 \
    python3-venv \
    net-tools \
    iproute2 \
    procps \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /var/log/supervisor /etc/supervisor/conf.d /opt/purple-lab /var/log/purple-lab /srv/labdata

RUN useradd -m -s /bin/bash analyst && echo 'analyst:Analyst123!' | chpasswd && \
    useradd -m -s /bin/bash ops && echo 'ops:Ops123456!' | chpasswd

RUN mkdir -p /home/analyst/Documents /home/ops/Documents && \
    printf 'employee_id,name,amount\n1001,Alice,4200\n1002,Bob,3900\n' > /home/analyst/Documents/Finance_Q4_2026.csv && \
    printf 'quarterly ops notes for purple lab only\n' > /srv/labdata/Operations_Notes.txt && \
    printf 'host,service,owner\napp-dmz-01,http,web-team\n' > /home/ops/Documents/Service_Index.csv && \
    chown -R analyst:analyst /home/analyst && \
    chown -R ops:ops /home/ops

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
COPY start_wazuh_agent.sh /usr/local/bin/start-wazuh-agent.sh
COPY lab_vuln_service.py /opt/purple-lab/lab_vuln_service.py

RUN chmod +x /entrypoint.sh /usr/local/bin/start-wazuh-agent.sh

EXPOSE 22 8081

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
