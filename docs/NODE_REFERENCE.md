# PurpleLab Node and Service Reference

This document is the technical inventory for the default PurpleLab baseline.

## Node access inventory

All host-published services bind to `192.168.56.10`.

| Node | Internal address or addresses | Host access | Main role |
| --- | --- | --- | --- |
| `lab-control` | `192.168.56.10` | SSH `22`, Wazuh HTTPS `443`, CALDERA HTTP `8888` | Control plane, Docker host, SIEM, emulation |
| `win-endpoint-01` | `192.168.56.20` baseline host-only address | VM console, WinRM as configured on the VM | Windows telemetry and scenario endpoint |
| `int-endpoint-01` | USER `10.10.40.10`; CORE `10.10.50.10` | SSH `2223` | Internal Linux endpoint |
| `app-dmz-01` | DMZ `10.10.10.20`; DATA `10.10.30.20`; CORE `10.10.50.20` | Web `8080`; SSH `2224` | Corporate web application and DMZ surface |
| `db-int-01` | DATA `10.10.30.30`; CORE `10.10.50.30` | PostgreSQL `15432`; SSH `2225` | PostgreSQL database |
| `user-linux-01` | USER `10.10.40.40`; CORE `10.10.50.40` | SSH `2226` | User workstation and final S13 target |
| `dns-int-01` | CORE `10.10.50.50` | DNS TCP/UDP `53`; SSH `2227` | `corp.lab` DNS |
| `files-int-01` | CORE `10.10.50.60` | SMB `445`; SSH `2228` | Corporate file share |
| `proxy-int-01` | CORE `10.10.50.70` | Squid `3128`; SSH `2229` | HTTP/HTTPS proxy |
| `ldap-int-01` | CORE `10.10.50.80` | LDAP `389`; SSH `2230` | Directory service |
| `print-int-01` | CORE `10.10.50.90` | CUPS `631`; SSH `2234` | Virtual print service |
| `pool-node-01..03` | USER/CORE `10.10.40.101..103` and `10.10.50.101..103` | SSH `2231..2233`; HTTP `2301..2303` | Scalable internal workloads and S13 path |

For pool node index `i`, the current deployment script derives:

- USER IP: `10.10.40.(100+i)`
- CORE IP: `10.10.50.(100+i)`
- SSH host port: `2230+i`
- local service host port: `2300+i`

## SSH accounts

Connect through the host-only address, for example:

```bash
ssh -p 2228 analyst@192.168.56.10
```

| Nodes | User | Default laboratory password | Notes |
| --- | --- | --- | --- |
| All Linux containers | `analyst` | `Analyst123!` | Primary baseline account |
| `int-endpoint-01` | `ops` | `Ops123!` | Additional endpoint account |
| `files-int-01`, `user-linux-01`, `pool-node-*` | `ops` | `Ops123456!` | Additional service/workload account |
| `lab-control` VM | `labuser` | `labpassword` in the current OVA | The repository does not create/reset this host account; source builds use the password selected during Ubuntu installation |

Some container SSH configurations permit root login, but the project does not provision a root password. Use `analyst`, `ops`, or `docker exec` for administration; do not depend on root SSH.

## Service accounts

| Service | Principal | Default laboratory password | Scope |
| --- | --- | --- | --- |
| Wazuh Dashboard | `admin` | `SecretPassword` | Web dashboard on `https://192.168.56.10` |
| MITRE CALDERA | `red` | Generated in `thirdparty/caldera/conf/local.yml` | Web interface and operations |
| Corporate web app | `webanalyst` | `WebAnalyst123!` | `/login` on port `8080` |
| PostgreSQL | `dbanalyst` | `DBAnalyst123!` | Database `purpledb` |
| LDAP administrator | `cn=admin,dc=corp,dc=lab` | `LabLdap123!` | Directory bootstrap and administration |
| LDAP user | `uid=analyst,ou=People,dc=corp,dc=lab` | `Analyst123!` | Seeded directory identity |
| LDAP user | `uid=ops,ou=People,dc=corp,dc=lab` | `Ops123456!` | Seeded directory identity |
| Windows local user | `labuser` | `WinPassword123!` | Created by the Windows bootstrap |
| SMB share | `analyst` / `ops` | Same as the corresponding Linux LDAP user account | `CorpShare` |

The Wazuh password is the default password. The CALDERA password is generated during installation.

## DNS zone

The default search domain is `corp.lab` and the authoritative laboratory resolver is `10.10.50.50`.

| Record | Address |
| --- | --- |
| `app.corp.lab` | `10.10.10.20` |
| `app-int.corp.lab` | `10.10.50.20` |
| `db.corp.lab` | `10.10.30.30` |
| `int-endpoint-01.corp.lab` | `10.10.40.10` |
| `user-linux-01.corp.lab` | `10.10.40.40` |
| `dns.corp.lab` | `10.10.50.50` |
| `files.corp.lab` | `10.10.50.60` |
| `proxy.corp.lab` | `10.10.50.70` |
| `ldap.corp.lab` | `10.10.50.80` |
| `print.corp.lab` | `10.10.50.90` |

Authoritative file: `configs/dns-int-01/dnsmasq.conf`.

After changing records:

```bash
cd scripts/host
./deploy_dns_int.sh
./validate_dns_int.sh
```

## Corporate web application

- Host URL: `http://192.168.56.10:8080/`
- Internal DMZ URL: `http://app.corp.lab:8080/`
- Internal CORE URL: `http://app-int.corp.lab:8080/`
- User-facing routes include `/`, `/login`, `/announcements`, `/departments`, and `/search`.
- Source: `configs/app-dmz-01/app.py`.
- Runtime variables: `compose/docker-compose.yml` and generated environment values used by the deploy script.

The application writes four telemetry streams:

- `/var/log/purple-web/access.log`
- `/var/log/purple-web/auth.log`
- `/var/log/purple-web/error.log`
- `/var/log/purple-web/app.json`

The first three are ingested as syslog-like input and `app.json` is ingested as JSON.

## PostgreSQL

- Host endpoint: `192.168.56.10:15432`
- Internal endpoint: `db.corp.lab:5432`
- Database: `purpledb`
- Role: `dbanalyst`
- Authentication: SCRAM-SHA-256 for network clients.
- Query, connection, and disconnection logging are enabled for laboratory observability.
- Main log: `/var/log/postgresql/postgresql.log`.

The database and role are created in `configs/db-int-01/entrypoint.sh`. PostgreSQL configuration is applied during container startup.

## SMB file service

- Host endpoint: `//192.168.56.10/CorpShare`
- Internal endpoint: `//files.corp.lab/CorpShare`
- Share path: `/srv/shares/corp`
- Valid users: `analyst`, `ops`
- Guest access: disabled
- Main log: `/var/log/samba/log.smbd`

Synthetic files are recreated by `configs/files-int-01/entrypoint.sh` whenever the container starts. Persistent additions should therefore be represented in the repository or mounted from a managed volume rather than edited only inside the running container.

## HTTP proxy

- Host endpoint: `http://192.168.56.10:3128`
- Internal endpoint: `http://proxy.corp.lab:3128`
- Allowed client ranges: `192.168.56.0/24` and `10.10.40.0/24`
- Safe destination ports: `80`, `443`, `8080`, and `1025-65535`; CONNECT is restricted to `443`.
- Resolver: `10.10.50.50`
- Logs: `/var/log/squid/access.log` and `/var/log/squid/cache.log`

Authoritative file: `configs/proxy-int-01/squid.conf`.

## LDAP directory

- Host endpoint: `ldap://192.168.56.10:389`
- Internal endpoint: `ldap://ldap.corp.lab:389`
- Base DN: `dc=corp,dc=lab`
- Administrative DN: `cn=admin,dc=corp,dc=lab`

Seeded tree:

```text
dc=corp,dc=lab
├── ou=People
│   ├── uid=analyst
│   └── uid=ops
├── ou=Groups
│   ├── cn=engineering
│   ├── cn=operations
│   └── cn=it-admins
└── ou=Printers
    └── cn=Printer-HQ-01
```

Seed file: `configs/ldap-int-01/bootstrap.ldif`. Bootstrap logic and the administrative password are in `configs/ldap-int-01/entrypoint.sh`.

The seed is applied only when the container's LDAP state is uninitialized. Recreate the node through `scripts/host/deploy_ldap_int.sh` after changing the baseline LDIF file.

## CUPS printing

- Host UI and IPP endpoint: `http://192.168.56.10:631/`
- Internal endpoint: `http://print.corp.lab:631/`
- Queue: `Printer-HQ-01`
- Backend: CUPS-PDF
- Generated output: `/var/spool/cups-pdf` inside the container
- Logs: `/var/log/cups/access_log`, `/var/log/cups/error_log`, `/var/log/cups/page_log`

The queue is created idempotently by `scripts/host/deploy_print_int.sh`.

## Windows endpoint

The Windows bootstrap creates or configures:

- Local user `labuser`.
- Read-only SMB share `PurpleShare` at `C:\PurpleShare` for that user.
- WinRM and file/printer sharing.
- Wazuh agent name `win-endpoint-01`.
- PowerShell Script Block Logging.
- Task Scheduler Operational logging.
- Process creation command-line logging.
- CALDERA agent services implemented as scheduled tasks for the dedicated lab VM.

Authoritative files:

- `scripts/windows/bootstrap_win_endpoint.ps1`
- `scripts/windows/ensure_win_endpoint.ps1`
- `scripts/windows/validate_win_endpoint.ps1`

The scripts do not configure the VirtualBox adapter or assign `192.168.56.20`; configure the VM network first.

## Pool nodes

Pool nodes are created dynamically by `scripts/host/deploy_pool_nodes.sh`, not by the static Compose file. Each node includes:

- SSH accounts `analyst` and `ops`.
- USER and CORE interfaces.
- Wazuh agent enrollment.
- Auth, syslog, and local-service telemetry.
- A small HTTP service on internal port `8081` used by controlled scenario orchestration.

The default S13 fixture places one synthetic operational clue on `pool-node-02`. Redeploying the pool recreates that fixture. This should be treated as scenario data, not as a real credential source.

## Telemetry inventory

| Node or service | Wazuh-monitored source |
| --- | --- |
| `int-endpoint-01` | `/var/log/auth.log`, `/var/log/syslog`, Sandcat/service logs as deployed |
| `app-dmz-01` | Purple web access, auth, error, and JSON application logs |
| `db-int-01` | `/var/log/postgresql/postgresql.log` |
| `user-linux-01` | `/var/log/auth.log`, `/var/log/syslog` |
| `dns-int-01` | `/var/log/syslog`, `/var/log/auth.log`, `/var/log/dnsmasq/dnsmasq.log` |
| `files-int-01` | `/var/log/syslog`, `/var/log/auth.log`, `/var/log/samba/log.smbd` |
| `proxy-int-01` | `/var/log/syslog`, `/var/log/auth.log`, Squid access and cache logs |
| `ldap-int-01` | `/var/log/syslog`, `/var/log/auth.log`, supervisor slapd stdout/stderr logs |
| `print-int-01` | `/var/log/syslog`, `/var/log/auth.log`, CUPS access/error/page logs |
| `pool-node-*` | `/var/log/auth.log`, `/var/log/syslog`, `/var/log/purple-lab/lab-vuln-service.log` |
| `win-endpoint-01` | Windows security-relevant channels plus PowerShell and Task Scheduler Operational channels |

For most Linux nodes, the deployment helper installs the Wazuh agent and injects the `localfile` entries after the container starts. Editing only a Dockerfile is therefore not sufficient when adding a new telemetry source.

## Network policy summary

The actual phase of implementation of the firewall allows the minimum baseline dependencies, including:

- Every lab subnet to DNS on `10.10.50.50:53`.
- `app-dmz-01` to PostgreSQL on `5432` and to Squid on `3128`.
- User workloads to the corporate application.
- Internal endpoint, user, and pool workloads to approved file, proxy, LDAP, and print services.
- Explicit S13 paths from the application to pool SSH and from pool nodes to `user-linux-01` SSH.

Representative blocked flows include internal endpoints to PostgreSQL and the DMZ application to SMB, LDAP, or printing. The authoritative rules and tests are:

- `scripts/host/apply_lab_firewall_phase1.sh`
- `scripts/host/validate_segmentation_phase1.sh`

Do not add a broad allow rule to make a new service work. Add the narrow flow, document why it is needed, and add an expected-open or expected-blocked validation.

## Configuration of services

| Services | Authoritative repository path | Apply or validate with |
| --- | --- | --- |
| Static nodes, networks, host ports | `compose/docker-compose.yml` | `scripts/host/ensure_full_lab.sh` |
| Per-node packages and users | `configs/<node>/Dockerfile` | Corresponding `deploy_<node>.sh` |
| Service startup | `configs/<node>/entrypoint.sh`, `supervisord.conf` | Corresponding validator |
| DNS records | `configs/dns-int-01/dnsmasq.conf` | `deploy_dns_int.sh`, `validate_dns_int.sh` |
| SMB | `configs/files-int-01/smb.conf` | `deploy_files_int.sh`, `validate_files_int.sh` |
| Proxy | `configs/proxy-int-01/squid.conf` | `deploy_proxy_int.sh`, `validate_proxy_int.sh` |
| LDAP seed | `configs/ldap-int-01/bootstrap.ldif` | `deploy_ldap_int.sh`, `validate_ldap_int.sh` |
| CUPS | `configs/print-int-01/cupsd.conf` and deploy helper | `deploy_print_int.sh`, `validate_print_int.sh` |
| Wazuh local rules | `configs/wazuh/local_rules.xml` | `apply_wazuh_local_rules.sh` |
| Linux Wazuh inputs | `scripts/host/deploy_*.sh` | Node validator and Wazuh UI |
| CALDERA content | `overlays/caldera/plugins/purplelab/` | `enable_caldera_purplelab.sh` and CALDERA UI |
| Pool topology and fixtures | `scripts/host/deploy_pool_nodes.sh` | Full and segmentation validators |
| Windows endpoint | `scripts/windows/` | `validate_win_endpoint.ps1` |

## Changing defaults safely

Default credentials support reproducibility, not security. If the environment is shared beyond a private host-only lab, replace them and restrict management access before use.
