# PurpleLab Cyber Range

PurpleLab Cyber Range is a reproducible cyber range for adversary emulation, detection validation, and security monitoring exercises. The environment combines a segmented Docker-based enterprise lab, Apache CALDERA for adversary emulation, and Wazuh for telemetry collection and alerting.

## Scope

This repository contains:

- Docker-based lab node definitions
- Deployment and validation scripts
- A custom CALDERA plugin (`purplelab`)
- Scenario runners and scenario inputs
- Host bootstrap and provisioning automation for `lab-control`
- Windows endpoint bootstrap scripts

This repository does **not** vendor CALDERA or Wazuh-docker directly. Those dependencies are cloned automatically during provisioning.

## High-level architecture

The baseline environment includes:

- `lab-control`
- `app-dmz-01`
- `db-int-01`
- `dns-int-01`
- `files-int-01`
- `proxy-int-01`
- `ldap-int-01`
- `print-int-01`
- `int-endpoint-01`
- `user-linux-01`
- `pool-node-*`
- `win-endpoint-01`

The environment uses segmented Docker networks to represent DMZ, DATA, USER, and CORE zones.

## Repository structure

- `compose/` — Docker Compose definitions
- `configs/` — container images, entrypoints, and service configuration
- `scripts/host/` — host provisioning, deployment, validation, and orchestration
- `scripts/linux/` — Linux-side helper scripts
- `scripts/windows/` — Windows endpoint bootstrap and validation
- `scenarios/` — scenario runners, validation scripts, and inputs
- `overlays/caldera/plugins/purplelab/` — custom CALDERA plugin overlay

## Prerequisites

Recommended baseline:

- Ubuntu host for `lab-control`
- Docker
- Docker Compose
- Python 3
- Git
- VirtualBox for the Windows endpoint workflow
- Internet access to clone upstream dependencies

## Provisioning flow

### lab-control

Run from the repository root host:

```bash
cd scripts/host
./ensure_full_lab.sh --pool-count 3
```

The `ensure_full_lab.sh` flow will call the lab-control ensure logic, which provisions dependencies when needed, bootstraps CALDERA and Wazuh, deploys the Linux lab nodes, and validates the environment.

### Windows endpoint

From the Windows endpoint VM:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\ensure_win_endpoint.ps1
```

## Dependency setup model

The repository reconstructs third-party dependencies automatically.

The host provisioning flow clones pinned revisions of:

- Apache CALDERA
- Wazuh Docker

It then applies the `purplelab` overlay into CALDERA and enables the plugin in the generated `local.yml`.

## Validation

Primary validation commands:

```bash
cd scripts/host
./validate_lab_control.sh
./validate_full_lab.sh
```

On Windows:

```powershell
.\validate_win_endpoint.ps1
```

## Scenarios

Scenario content is located under `scenarios/`. Scenario execution outputs are intentionally excluded from version control. The repository currently includes baseline scenario runners and inputs. Some advanced chains, including S13, are under active refinement.

## Notes

- This repository excludes runtime artifacts, generated files, local evidence, and third-party repository state.
- CALDERA and Wazuh runtime data are created during provisioning.
- Review and adapt any hard-coded IP addresses if your host-only network differs from `192.168.56.0/24`.

## License

GPL-3.0
