# 🏗️ Infrastructure Overview

## Overview

This document describes the homelab infrastructure architecture based on Proxmox and RKE2.

## Global Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox VE - asgard                       │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Template VM (VMID 90001)                  │  │
│  │            pkr-ubuntu-noble-1                          │  │
│  │            Ubuntu 24.04 LTS                            │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                  │
│                            │ clone                            │
│                            ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         RKE2 Cluster - Valaskjalf                    │    │
│  │                                                       │    │
│  │  ┌────────────────────────────────────────┐         │    │
│  │  │    Control Plane (Masters)             │         │    │
│  │  │                                         │         │    │
│  │  │  • valaskjalf-master-1 (10.10.10.101) │         │    │
│  │  │  • valaskjalf-master-2 (10.10.10.102) │         │    │
│  │  │  • valaskjalf-master-3 (10.10.10.103) │         │    │
│  │  └────────────────────────────────────────┘         │    │
│  │                                                       │    │
│  │  ┌────────────────────────────────────────┐         │    │
│  │  │    Worker Nodes                        │         │    │
│  │  │                                         │         │    │
│  │  │  • valaskjalf-worker-1 (10.10.10.111) │         │    │
│  │  │  • valaskjalf-worker-2 (10.10.10.112) │         │    │
│  │  │  • valaskjalf-worker-3 (10.10.10.113) │         │    │
│  │  └────────────────────────────────────────┘         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Components

### Hardware Specifications

This homelab runs on a repurposed gaming PC with the following specifications:

- **CPU**: Intel Core i9-9900K (8 cores, 16 threads, up to 5.0 GHz)
- **RAM**: 64 GB DDR4
- **GPU**: NVIDIA GeForce RTX 2080 (available for GPU passthrough to VMs)
- **Storage**: ZFS pool (configured for high performance and reliability)

> 💡 **Note**: The RTX 2080 can be passed through to VMs for GPU-accelerated workloads. See the [GPU Passthrough Guide](./gpu-passthrough.md) for detailed setup instructions.

### Proxmox VE

**Node**: `asgard`

Proxmox Virtual Environment is the base hypervisor that hosts all virtual machines. It provides:

- KVM/QEMU Virtualization
- Centralized management via REST API
- ZFS Storage for performance and reliability
- Virtual networking via Linux bridge

**Configuration**:
- Primary Storage: `local-zfs`
- Network Bridge: `vmbr0`
- ISO Storage: `local`

### Ubuntu VM Template

**Template**: `pkr-ubuntu-noble-1` (VMID 90001)

Virtual machine template created with Packer, based on Ubuntu 24.04 LTS (Noble Numbat). This template serves as the base for all cluster nodes.

**Features**:
- OS: Ubuntu 24.04.3 LTS Server
- Cloud-init enabled for automatic customization
- QEMU Guest Agent installed
- Hardened SSH (port 2222, key-only authentication)
- Base packages: vim, zip, unzip
- Locale: fr_FR (French)
- Keyboard: fr (AZERTY)
- Timezone: Europe/Paris (configurable via cloud-init)

### RKE2 Cluster

**Cluster name**: `valaskjalf`

RKE2 (Rancher Kubernetes Engine 2) is a certified Kubernetes distribution, optimized for security and compliance.

#### Control Plane (Masters)

Master nodes run the Kubernetes control plane components:
- **etcd**: distributed cluster database
- **kube-apiserver**: Kubernetes API entry point
- **kube-scheduler**: pod scheduling
- **kube-controller-manager**: resource controllers

**Configuration per master**:
- vCPU: 2 cores (host type)
- RAM: 4 GB
- Disk: 50 GB (local-zfs, iothread enabled)
- Network: VirtIO on vmbr0
- SCSI: virtio-scsi-pci
- Auto-boot: enabled

| Hostname | VMID | IP Address | Role |
|----------|------|------------|------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | Control Plane |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | Control Plane |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | Control Plane |

#### Worker Nodes

Worker nodes run application workloads (pods, containers).

**Configuration per worker**:
- vCPU: 3 cores (host type)
- RAM: 12 GB
- Disk: 100 GB (local-zfs, iothread enabled)
- Network: VirtIO on vmbr0
- SCSI: virtio-scsi-pci
- Auto-boot: enabled

| Hostname | VMID | IP Address | Role |
|----------|------|------------|------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | Worker |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | Worker |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | Worker |

## Network

### IP Configuration

- **Network**: 10.10.10.0/24
- **Gateway**: 10.10.10.1
- **DNS**: 10.10.10.1
- **Assignment**: Static IPs via cloud-init

### IP Addressing Plan

| Range | Usage |
|-------|-------|
| 10.10.10.1 | Gateway/DNS |
| 10.10.10.101-103 | RKE2 Masters |
| 10.10.10.111-113 | RKE2 Workers |

## Security

### SSH

- **Port**: 2222 (non-standard to reduce automated scans)
- **Authentication**: Public key only (supports YubiKey)
- **Root login**: Disabled
- **Password authentication**: Disabled
- **User**: `odin` with sudo privileges

> 💡 **YubiKey Support**: This setup supports YubiKey hardware authentication for SSH. See the [Getting Started Guide](../GETTING-STARTED.md#yubikey-ssh-setup) for configuration instructions.

### Cloud-init

- Datasources: ConfigDrive, NoCloud
- Network configuration via cloud-init (no persistent netplan)
- SSH keys injected at boot
- Hashed password for console access if needed

## Storage

### Proxmox Storage

- **Type**: ZFS
- **Pool**: `local-zfs`
- **Features**:
  - Snapshots
  - Compression
  - Checksums
  - Copy-on-write

### VM Disks

- **Format**: Raw (best performance)
- **Bus**: VirtIO (optimal performance)
- **iothread**: Enabled (improves I/O performance)

## Performance

### CPU Optimizations

- **Type**: `host` (CPU passthrough)
- All host CPU features are passed to VMs
- Best performance for Kubernetes workloads
- Takes advantage of Intel i9-9900K features

### Network Optimizations

- **Model**: VirtIO (paravirtualization)
- Better network performance than emulated E1000
- Support for advanced features (multiqueue, etc.)

### Disk Optimizations

- **iothread**: Dedicated thread for I/O operations
- **VirtIO SCSI**: Better performance than IDE
- **ZFS**: Transparent compression and checksums

## High Availability

### Masters

- **3 master nodes** for etcd quorum (tolerates 1 failure)
- Distributed on the same Proxmox host (single node homelab)
- Auto-boot enabled for automatic restart

### Workers

- **3 worker nodes** for workload distribution
- Can handle worker node failure
- Auto-boot enabled

## Monitoring and Management

### QEMU Guest Agent

Installed on all VMs for:
- Detailed system information
- Clean shutdown/reboot
- Filesystem freeze for snapshots
- Password injection

### Proxmox Tags

- Tag `rke2` applied to all cluster VMs
- Facilitates filtering and organization in Proxmox interface

## Scalability

### Adding a Master

1. Copy and adapt a `valaskjalf-master-X.tf` file
2. Modify: name, vmid, IP
3. Apply with Terraform

### Adding a Worker

1. Copy and adapt a `valaskjalf-worker-X.tf` file
2. Modify: name, vmid, IP
3. Apply with Terraform

### Resources

Adjust in Terraform files:
- `cpu.cores`: number of vCPUs
- `memory`: RAM in MB
- `disks.virtio.virtio0.disk.size`: disk size in GB

## Maintenance

### Backup

Use Proxmox backup features:
- Scheduled VM backups
- ZFS snapshots
- Export Terraform configuration

### Updates

- OS: `apt update && apt upgrade` on each VM
- RKE2: via RKE2 update mechanisms
- Template: Rebuild with Packer and redeploy

### Destruction

```bash
cd terraform
terraform destroy -var-file="credentials.tfvars"
```

> ⚠️ **Warning**: This will permanently delete all VMs defined in Terraform!
