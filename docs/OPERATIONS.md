# PurpleLab Operations Guide

This guide explains how to enter, validate, operate, observe, and extend a deployed PurpleLab environment. It is intended only for the isolated, authorized laboratory described in this repository.

For exact internal addresses, host ports, default laboratory accounts, service configuration, and log paths, see the [node and service reference](NODE_REFERENCE.md).

## 1. Operating model

PurpleLab has two management virtual machines:

- `lab-control` (`192.168.56.10`) hosts the repository, Docker, Wazuh, MITRE CALDERA, the segmented Linux containers, and the Linux-side management scripts.
- `win-endpoint-01` (`192.168.56.20` in the baseline diagram) is a separate Windows Server VM connected through the VirtualBox host-only network.

Most operator actions begin on `lab-control`. The service containers are reached either through published ports on `192.168.56.10` or with `docker exec`. The `10.10.x.x` addresses belong to the internal Docker networks and are primarily used by the laboratory nodes themselves.

## 2. First access after importing the OVA

1. Import the OVA into VirtualBox.
2. Attach its management interface to the expected host-only network (`192.168.56.0/24`).
3. Start `lab-control` and confirm that it uses `192.168.56.10`.
4. Log in from the VirtualBox console or over SSH:

   ```bash
   ssh labuser@192.168.56.10
   ```

   The current OVA's initial laboratory password is `labpassword`.

5. Change to the repository directory on the VM, then validate the environment:

   ```bash
   cd /path/to/purplelab_cyber_range/scripts/host
   ./validate_lab_control.sh
   ./validate_full_lab.sh
   ```

6. Print the current dashboard access information:

   ```bash
   ./print_dashboard_access.sh
   ```

The repository assumes a host user named `labuser`, but it does not create or reset that Ubuntu account. The current OVA uses `labpassword` as its initial laboratory password. Change it after first login if the VM will be shared or connected beyond the private host-only network, and never reuse a personal or institutional password.

## 3. First access after rebuilding from source

From the repository root on `lab-control`:

```bash
cd scripts/host
./ensure_full_lab.sh --pool-count 3
```

`ensure_full_lab.sh` is idempotent at the orchestration level: it first validates the current state and deploys missing or failed components. Use `--force` only when an intentional full redeployment is required.

Configure `win-endpoint-01` with its VirtualBox host-only adapter before running the Windows ensure script. The PowerShell bootstrap configures the endpoint services and agents, but it does not assign the VM's host-only IP address.

On the Windows VM, from an elevated PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd C:\path\to\scripts\windows
.\ensure_win_endpoint.ps1
```

Then run:

```powershell
.\validate_win_endpoint.ps1
```

## 4. Readiness checklist

Do not treat the laboratory as ready merely because the VMs and containers are running. Confirm all of the following:

```bash
cd scripts/host
./validate_lab_control.sh
./validate_full_lab.sh
./validate_segmentation_phase1.sh
```

On Windows:

```powershell
.\validate_win_endpoint.ps1
```

The checks cover the control-plane services, representative service health, Wazuh enrollment, expected telemetry inputs, CALDERA agents, and allowed/blocked east-west paths.

Useful status commands on `lab-control`:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
systemctl status caldera --no-pager
cd thirdparty/wazuh-docker/single-node
docker compose ps
```

## 5. Dashboards and control-plane access

### Wazuh Dashboard

- URL: `https://192.168.56.10`
- User: `admin`
- Default laboratory password: `SecretPassword`
- Expected first-use behavior: the browser reports a self-signed certificate.

Use the Endpoints view to confirm agent presence. Use Discover or the security-events views to filter by `agent.name`, `rule.id`, `rule.mitre.id`, and the scenario time window.

### MITRE CALDERA

- URL: `http://192.168.56.10:8888`
- User: `red`
- Password: generated locally during bootstrap.

Read the generated password from:

```bash
thirdparty/caldera/conf/local.yml
```

The helper below prints both dashboard access blocks without placing the generated CALDERA secret in version control:

```bash
cd scripts/host
./print_dashboard_access.sh
```

## 6. Direct access to Linux nodes

All container SSH ports are published on `192.168.56.10`. The main baseline account is `analyst`; its synthetic laboratory password is `Analyst123!`.

Examples:

```bash
ssh -p 2223 analyst@192.168.56.10   # int-endpoint-01
ssh -p 2224 analyst@192.168.56.10   # app-dmz-01
ssh -p 2225 analyst@192.168.56.10   # db-int-01
ssh -p 2231 analyst@192.168.56.10   # pool-node-01
```

For local administration from `lab-control`, `docker exec` is usually more convenient and does not require a container password:

```bash
docker exec -it app-dmz-01 bash
docker exec -it db-int-01 bash
docker exec -it files-int-01 bash
```

See [Node access inventory](NODE_REFERENCE.md#node-access-inventory) for every port and address. Default credentials are intentionally synthetic and public; never expose the published ports outside the host-only network.

## 7. Using the representative services

The following checks provide a safe operational smoke test. Credentials are entered interactively where the client supports it.

### Corporate web application

Open `http://192.168.56.10:8080/`. The synthetic application account is `webanalyst` with password `WebAnalyst123!`.

### PostgreSQL

```bash
psql -h 192.168.56.10 -p 15432 -U dbanalyst -d purpledb
```

When prompted, use the synthetic database password listed in the [service account table](NODE_REFERENCE.md#service-accounts).

### DNS

```bash
dig @192.168.56.10 app.corp.lab
dig @192.168.56.10 files.corp.lab
dig @192.168.56.10 db.corp.lab
```

### SMB file service

If `smbclient` is installed:

```bash
smbclient //192.168.56.10/CorpShare -U analyst
```

The share contains synthetic documents only and is writable by the `analyst` and `ops` laboratory accounts.

### HTTP proxy

```bash
curl -x http://192.168.56.10:3128 -I http://192.168.56.10:8080/
```

The baseline Squid policy allows clients from `192.168.56.0/24` and the USER network.

### LDAP directory

An anonymous test query can confirm the seeded directory:

```bash
ldapsearch -x -H ldap://192.168.56.10:389 \
  -b dc=corp,dc=lab '(uid=analyst)' dn cn mail
```

The full directory layout and bind accounts are in [LDAP directory](NODE_REFERENCE.md#ldap-directory).

### CUPS printing

Open `http://192.168.56.10:631/` and confirm that `Printer-HQ-01` exists. The queue uses CUPS-PDF and writes generated files inside the print container.

## 8. Routine lifecycle

### Start or restore the expected state

The preferred recovery action is:

```bash
cd scripts/host
./ensure_full_lab.sh --pool-count 3
```

This is safer than manually reconstructing individual dependencies because it also reapplies enrollment, local log inputs, firewall policy, and validation.

### Restart a single service container

Use its deployment helper so that post-start configuration is reapplied:

```bash
cd scripts/host
./deploy_app_dmz.sh
./deploy_db_int.sh
./deploy_dns_int.sh
```

Equivalent helpers exist for the other named nodes. These scripts may recreate a container; preserve any intentional experimental changes outside the container before running them.

### Stop the laboratory without deleting it

From `lab-control`:

```bash
cd compose
docker compose stop
docker ps -q --filter 'name=^pool-node-' | xargs -r docker stop
sudo systemctl stop caldera
cd ../thirdparty/wazuh-docker/single-node
docker compose stop
```

Start it again through `ensure_full_lab.sh` so all dependencies and policies are checked.

## 9. Scenario workflow

Scenario folders contain inputs, a runner when execution is script-driven, a collector, and a validator. Use them only inside this isolated laboratory.

A repeatable experiment follows this sequence:

1. Run the readiness checklist.
2. Record the start time and the scenario identifier.
3. Review the scenario's `inputs/` and runner before execution.
4. Execute the corresponding `run_*` script or approved CALDERA operation.
5. Run the scenario `collect_*` script to gather evidence.
6. Run the scenario `validate_*` script.
7. Check Wazuh for source events, ingestion, rule matches, and alert metadata.
8. Record one mutually exclusive verdict: `Detected`, `Logged only`, `Not ingested`, `Not generated`, or `Execution failed`.

Tool completion alone is not a detection result. The verdict must be supported by source logs and Wazuh evidence. Some scenarios, including the multistage S13 chain, are expected to expose detection gaps until additional telemetry and correlation rules are implemented.

The custom CALDERA content is under `overlays/caldera/plugins/purplelab/`. Scenario outputs and local evidence are intentionally excluded from Git.

## 10. Observability and troubleshooting

### Check a node's Wazuh agent

```bash
docker exec app-dmz-01 tail -n 50 /var/ossec/logs/ossec.log
docker exec db-int-01 tail -n 50 /var/ossec/logs/ossec.log
```

### Check service logs at the source

```bash
docker exec app-dmz-01 tail -n 50 /var/log/purple-web/app.json
docker exec db-int-01 tail -n 50 /var/log/postgresql/postgresql.log
docker exec dns-int-01 tail -n 50 /var/log/dnsmasq/dnsmasq.log
docker exec files-int-01 tail -n 50 /var/log/samba/log.smbd
docker exec proxy-int-01 tail -n 50 /var/log/squid/access.log
docker exec print-int-01 tail -n 50 /var/log/cups/access_log
```

### Validate segmentation

```bash
cd scripts/host
./apply_lab_firewall_phase1.sh
./validate_segmentation_phase1.sh
```

The policy is deny-by-default only for traffic whose source and destination are both laboratory container networks. Management access through host-published ports remains separate.

### Reset experimental logs

`clear_lab_container_logs.sh` truncates laboratory and container log files. This is destructive to local evidence, so export any needed evidence first and use it only between experiments:

```bash
cd scripts/host
./clear_lab_container_logs.sh
```

After clearing logs, run the validators and generate a fresh baseline before the next experiment.

## 11. Extending the laboratory

Before changing a service, locate its authoritative file in [Configuration ownership](NODE_REFERENCE.md#configuration-ownership).

General extension workflow:

1. Modify the repository-managed configuration, not the running container alone.
2. Update or add an idempotent deployment helper.
3. Add the required Wazuh `localfile` input when a new log source is introduced.
4. Update network policy only for the minimum required flow.
5. Add a validator for the service and for its expected segmentation.
6. Rebuild the affected node.
7. Re-run full validation and document the new node, account, port, log, and scenario dependency.

Avoid embedding real secrets. If a new default credential is required for a synthetic service, label it clearly as laboratory-only and keep the environment isolated.

## 12. Known operational constraints

- The baseline is validated with three pool nodes. `pool-node-01..03` use SSH host ports `2231..2233`; port `2234` is already assigned to `print-int-01`. Increasing the pool above three requires changing the host-port allocation first.
- The source repository does not create the Ubuntu `labuser` account or set its password; `labpassword` is the current OVA's initial credential, not a provisioning default for arbitrary source-built VMs.
- Recreating containers discards changes made only inside them.
- Passing platform validation does not imply that every emulated behavior generates a Wazuh alert.
- The Windows bootstrap intentionally enables detailed logging and laboratory agent services. Use it only on the dedicated endpoint VM.

## 13. Next references

- [Node and service reference](NODE_REFERENCE.md)
- [Main README](../README.md)
- [Docker Compose topology](../compose/docker-compose.yml)
- [Linux management scripts](../scripts/host/)
- [Windows scripts](../scripts/windows/)
- [Scenario content](../scenarios/)
