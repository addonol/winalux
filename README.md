# Winalux: On-Demand Containerized Workspaces

Winalux is an automation tool designed to deploy persistent, secure development environments using rootless Podman containers.

It provides a professional "escape hatch" for developers working in constrained environments (corporate workstations, shared servers) where administrative privileges (`sudo`) are unavailable. Winalux bridges the gap between your local IDE (VS Code) and isolated, high-performance containerized resources.

## Project Context and Purpose

The primary objective of Winalux is to solve the "Restricted Host" problem. In many enterprise environments, installing system-level dependencies or Docker daemons is prohibited. Winalux provides a professional escape hatch by leveraging rootless containerization.

### Core Architecture Principles

1. Rootless Execution: By utilizing Podman's user namespaces, the entire stack runs without root privileges. This ensures that even in the event of a container breakout, the host system remains secure.
2. Selective Persistence: Winalux decouples the compute lifecycle (Pod/Container) from the data lifecycle. Compute resources can be destroyed and recreated on-demand, while developer data and configurations persist in managed volumes.
3. Infrastructure as Code: Every environment is defined via a versioned Containerfile and Ansible playbooks, ensuring perfect parity between development, staging, and production nodes (e.g., Raspberry Pi, x86 Servers, or Cloud instances).

### Visual Preview: Secure Authentication Flow

Winalux features a dual-state terminal. First, the security challenge, followed by the workstation dashboard upon successful validation.

**1. Identity Challenge**
```text
  W I N A L U X   W O R K S T A T I O N
  Secure rootless development environment

  Passcode for WORSKPACE-1: ************
```

**2. Access Granted & Telemetry Dashboard**
```text
  W I N A L U X   W O R K S T A T I O N
  Secure rootless development environment

  STATUS
  CPU Load:    ■■□□□□□□□□ 14.3%
  Storage:     ■□□□□□□□□□ 4% (0.49GB / 10GB)
  Memory:      42MB / 3918MB
  Activity:    12 processes

  NETWORK
  ◦ Primary Port : 8000 (Web Server)
  ◦ Admin Port   : 2222 (Internal SSH)

  SANDBOX NOTES
  ◦ Persistence  Files in /home/developer are volume-backed.
                 Redeploying the container will NOT delete your work.
  ◦ Security     This is a rootless system. No sudo access available.
                 Direct access outside of the home directory is restricted.
  ◦ Interface    Type task --list to see all available commands.

  Connected as developer | Profile: WEB | 18:30:14

(venv) ➜  ~ (venv) $ pwd
/home/developer
(venv) ➜  ~ (venv) $
```

## Network Isolation and Sidecar Architecture

Winalux leverages the Pod concept from Podman to ensure strict network and resource isolation between different developer environments.

### Pod-Level Isolation
When an environment is provisioned, Winalux creates a dedicated Pod. All containers within this Pod share the same network stack (`localhost`). This architecture provides:
- **Exclusive Services**: Sidecar containers (e.g., Redis, Memcached, Faktory, or Airflow) are attached exclusively to a specific developer's Pod. They are invisible to other developers on the same host.
- **Zero Interference**: A developer can modify, restart, or crash their private service instances without impacting other environments. This eliminates "noisy neighbor" effects and version conflicts.
- **Lifecycle Linking**: Services are logically grouped. When a developer stops their main workspace, all associated sidecar resources are terminated simultaneously, ensuring efficient host resource management.

### Extra Ports and Service Mapping
The `extra_ports` attribute allows developers to expose specific internal services to their local machine. While internal communication between the web server (Gunicorn, Uvicorn) and sidecars happens privately within the Pod, `extra_ports` enables access to database UIs, debuggers, or message brokers from the local workstation.

## Technical Features

- **Multi-Architecture Support**: Automated hybrid builds for x86_64 and ARM64 architectures using Podman Manifests and QEMU emulation.
- **Access Control Gatekeeper**: A dual-layer security model combining SSH public-key authentication with a deployment-specific access token.
- **High-Performance Dependency Management**: Integration with Astral UV for near-instant Python virtual environment provisioning and package injection.
- **Profile-Based Stacks**:
    - **Web**: Optimized for backend development (Django, Java tools) with Taskfile automation.
    - **Data**: Pre-configured for data science (JupyterLab, Pandas, Numpy, Scipy).
- **Integrated Monitoring**: Embedded Taskfile CLI for real-time tracking of storage quotas and host memory consumption.

## Isolation-Aware Telemetry

Unlike standard container environments that incorrectly report the host's total resources, Winalux features a specialized monitoring engine that reflects the **true sandbox state**:

- **Isolated RAM (RSS Sum)**: Instead of showing your entire PC/Server's RAM, Winalux calculates the cumulative Resident Set Size (RSS) of all processes running *inside* your specific pod.
- **Dedicated CPU Tracking**: Measures delta processor usage specifically for the container namespace using `/proc/stat` differential analysis.
- **Smart Storage Quotas**: Tracks usage against your assigned `disk_limit_gb` within the persistent Podman volume, rather than the host's entire disk capacity.
- **Zero-Latency Dashboard**: Metrics are pre-calculated by a lightweight background daemon every 10s, ensuring the `task` dashboard remains instant and non-blocking.



## Requirements

- Control Node: Ansible 2.15.0 or higher and the uv package manager.
- Target Host: Linux (Fedora, Ubuntu, or Debian) with Podman configured in rootless mode and properly defined subuid/subgid ranges.

## Developer Profile API

Environments are defined in inventory/hosts.yml via the winalux_devs dictionary.


| Attribute | Type | Req. | Description |
| :--- | :--- | :---: | :--- |
| name | string | Yes | Unique identifier for container and volume naming. |
| profile | enum | Yes | Technical stack type: web or data. |
| ssh_port | int | Yes | Host port for SSH access (Internal container port: 2222). |
| app_port | int | Yes | Host port for primary service (8000 Web / 8888 Data). |
| public_key | string | Yes | SSH Public Key for primary authentication. |
| libraries | string | No | Additional PyPI packages to be injected via UV. |
| disk_limit_gb | int | No | Storage quota used for resource monitoring tasks. |
| extra_ports | list | No | Additional port mappings in "Host:Container" format. |


## Quick Start Guide

### 1. Setup Control Node
```bash
uv sync
uv run ansible-galaxy collection install -r requirements.yml
```

### 2. Deployment Workflow
Use the provided **Makefile** for common operations:

**Local Sandbox (Development):**
Build and deploy locally using your current machine as the target.
```bash
make build
make deploy TARGET_NODE=local_dev USE_LOCAL_IMAGE=true
```

**Remote Node (Production):**
Deploy to a remote server or Raspberry Pi using images from a registry.
```bash
make deploy TARGET_NODE=remote_pi USE_LOCAL_IMAGE=false
```

## Security and Connectivity

### Gatekeeper Mechanism
Winalux generates a unique Access Token during the deployment of each container. This token is persistent for the container's lifetime and is required for all shell sessions.

- Automated Access (VS Code): Configure your local SSH config to pass the token via environment variables: `SetEnv LC_WINALUX_TOKEN=your_token`.
- Interactive Access: The Gatekeeper script intercepts the login process and initiates a secure challenge, requiring manual entry of the token.

### Hardened Shells
Unlike standard containers, Winalux wraps `/bin/sh` and `/bin/bash`. This ensures that even an unauthorized local user trying to "jump into" the container via the host terminal is blocked by the security challenge.

Note: The internal SSH daemon listens on port 2222 to maintain rootless compatibility.

## License and Attribution

This project is licensed under the MIT License. Developed by addonol.
