# 🔧 Terraform - Infrastructure Deployment

## Introduction

This document describes how to use Terraform to deploy and manage the RKE2 cluster infrastructure on Proxmox.

## Overview

Terraform allows you to define infrastructure as code and manage it declaratively. All cluster VMs are defined in `.tf` files and deployed automatically.

## File Structure

```
terraform/
├── provider.tf              # Proxmox provider configuration
├── valaskjalf-master-1.tf   # Master node 1
├── valaskjalf-master-2.tf   # Master node 2
├── valaskjalf-master-3.tf   # Master node 3
├── valaskjalf-worker-1.tf   # Worker node 1
├── valaskjalf-worker-2.tf   # Worker node 2
└── valaskjalf-worker-3.tf   # Worker node 3
```

## Provider Configuration (provider.tf)

### Proxmox Provider

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}
```

**Provider**: [Telmate/proxmox](https://registry.terraform.io/providers/Telmate/proxmox)  
**Version**: 3.0.2-rc05 (release candidate with improved support)

### Variables

| Variable | Type | Description | Sensitive |
|----------|------|-------------|----------|
| `PROXMOX_API_URL` | string | Proxmox API URL | No |
| `PROXMOX_ROOT_USER` | string | Proxmox user (e.g., root@pam) | Yes |
| `PROXMOX_ROOT_PASSWORD` | string | Proxmox password | Yes |
| `PUBLIC_SSH_KEY` | string | SSH public key for VMs (supports YubiKey) | Yes |
| `CI_ODIN_PASSWORD` | string | Hashed password for cloud-init | Yes |

### Provider Configuration

```hcl
provider "proxmox" {
  pm_api_url      = var.PROXMOX_API_URL
  pm_user         = var.PROXMOX_ROOT_USER
  pm_password     = var.PROXMOX_ROOT_PASSWORD
  pm_tls_insecure = true  # Ignore SSL errors (homelab)
}
```

## VM Resources

Each VM is defined by a `proxmox_vm_qemu` resource with specific parameters.

### Master Resource Structure

```hcl
resource "proxmox_vm_qemu" "valaskjalf_master_1" {
  # Basic configuration
  name        = "valaskjalf-master-1"
  description = "Production rke2 master 1, Master Node, Ubuntu LTS"
  vmid        = 1001
  target_node = "asgard"
  
  # Clone from template
  clone      = "pkr-ubuntu-noble-1"
  full_clone = true
  
  # QEMU Guest Agent
  agent = 1
  
  # CPU
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  
  # Memory
  memory = 4096  # 4 GB
  
  # Storage
  disks {
    virtio {
      virtio0 {
        disk {
          size     = 50      # 50 GB
          storage  = "local-zfs"
          iothread = true
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = "local-zfs"
        }
      }
    }
  }
  
  # Network
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  # System parameters
  scsihw = "virtio-scsi-pci"
  bios   = "seabios"
  
  # Boot
  onboot           = true
  automatic_reboot = true
  
  # Tags
  tags = "rke2"
  
  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=10.10.10.101/24,gw=10.10.10.1"
  nameserver = "10.10.10.1"
  ciuser     = "odin"
  cipassword = var.CI_ODIN_PASSWORD
  sshkeys    = var.PUBLIC_SSH_KEY
}
```

### Worker Resource Structure

Workers have more resources than masters:

```hcl
resource "proxmox_vm_qemu" "valaskjalf_worker_1" {
  # ... similar configuration to masters ...
  
  # CPU - More cores for workloads
  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }
  
  # Memory - More RAM for applications
  memory = 12288  # 12 GB
  
  # Storage - More disk space
  disks {
    virtio {
      virtio0 {
        disk {
          size     = 100     # 100 GB
          storage  = "local-zfs"
          iothread = true
        }
      }
    }
    # ... cloud-init disk ...
  }
  
  # Different IP
  ipconfig0 = "ip=10.10.10.111/24,gw=10.10.10.1"
}
```

## Detailed Configuration

### Cloning

```hcl
clone      = "pkr-ubuntu-noble-1"  # Source template
full_clone = true                   # Full clone (not linked)
```

**Full clone**: Complete independent copy of template. Recommended for production.

### CPU

```hcl
cpu {
  cores   = 2       # Number of cores
  sockets = 1       # Number of sockets
  type    = "host"  # CPU passthrough
}
```

**Type "host"**: Passes all host CPU features to the VM. Best performance. Takes advantage of Intel i9-9900K capabilities.

### Memory

- **Masters**: 4096 MB (4 GB) - Sufficient for etcd + control plane
- **Workers**: 12288 MB (12 GB) - Necessary for application workloads

### Disks

```hcl
disks {
  virtio {
    virtio0 {
      disk {
        size     = 50           # Size in GB
        storage  = "local-zfs"  # Proxmox storage pool
        iothread = true         # Dedicated I/O thread
      }
    }
  }
  ide {
    ide2 {
      cloudinit {
        storage = "local-zfs"   # Cloud-init disk
      }
    }
  }
}
```

**iothread**: Improves I/O performance, important for etcd on masters.

### Network

```hcl
network {
  id     = 0         # Network interface 0
  model  = "virtio"  # Paravirtualization
  bridge = "vmbr0"   # Proxmox bridge
}
```

**VirtIO**: Better network performance than emulated E1000.

### Cloud-init

```hcl
os_type    = "cloud-init"
ipconfig0  = "ip=10.10.10.101/24,gw=10.10.10.1"
nameserver = "10.10.10.1"
ciuser     = "odin"
cipassword = var.CI_ODIN_PASSWORD
sshkeys    = var.PUBLIC_SSH_KEY
```

**ipconfig0**: Static network configuration  
**sshkeys**: SSH public keys (separated by `\n` if multiple)

> 💡 **YubiKey Support**: The `PUBLIC_SSH_KEY` variable can contain your YubiKey's SSH public key for hardware-based authentication.

## VM Inventory

### Masters (Control Plane)

| Name | VMID | IP | CPU | RAM | Disk | File |
|------|------|-----|-----|-----|------|------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-1.tf |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-2.tf |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-3.tf |

**Total Masters**: 6 cores, 12 GB RAM, 150 GB disk

### Workers

| Name | VMID | IP | CPU | RAM | Disk | File |
|------|------|-----|-----|-----|------|------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-1.tf |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-2.tf |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-3.tf |

**Total Workers**: 9 cores, 36 GB RAM, 300 GB disk

### Cluster Totals

- **CPUs**: 15 cores (6 masters + 9 workers)
- **RAM**: 48 GB (12 GB masters + 36 GB workers)
- **Disk**: 450 GB (150 GB masters + 300 GB workers)

> 📊 **Hardware Note**: This configuration fits comfortably on the Intel i9-9900K (8 cores, 16 threads) with 64GB RAM homelab server, leaving resources available for additional VMs or services.

## Usage

### Prerequisites

1. **Terraform installed**:
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Packer template created**: The template `pkr-ubuntu-noble-1` must exist in Proxmox

3. **Network access**: Machine running Terraform must access Proxmox API

### Configure Credentials

```bash
cd terraform

cat > credentials.tfvars << 'EOF'
PROXMOX_API_URL       = "https://10.10.10.x:8006/api2/json"
PROXMOX_ROOT_USER     = "root@pam"
PROXMOX_ROOT_PASSWORD = "your-proxmox-password"
PUBLIC_SSH_KEY        = "ssh-rsa AAAAB3NzaC1yc2EA... user@host"
CI_ODIN_PASSWORD      = "$6$rounds=4096$salt$hash..."
EOF

chmod 600 credentials.tfvars
```

> 💡 **YubiKey Users**: For `PUBLIC_SSH_KEY`, use your YubiKey's SSH public key. You can extract it with: `ssh-keygen -D /path/to/libykcs11.so -e`

### Generate Hashed Password

For `CI_ODIN_PASSWORD`:

```bash
# Python
python3 -c 'import crypt; print(crypt.crypt("password", crypt.mksalt(crypt.METHOD_SHA512)))'

# OpenSSL
openssl passwd -6 -salt "yoursalt" "password"

# mkpasswd (if available)
mkpasswd -m sha-512
```

### Terraform Workflow

#### 1. Initialization

```bash
cd terraform
terraform init
```

Downloads Proxmox provider and initializes backend.

#### 2. Validation

```bash
terraform validate
```

Checks `.tf` file syntax.

#### 3. Plan

```bash
terraform plan -var-file="credentials.tfvars"
```

Shows changes that will be applied:
- Resources to create (+)
- Resources to modify (~)
- Resources to destroy (-)

#### 4. Apply

```bash
terraform apply -var-file="credentials.tfvars"
```

Applies changes. Asks for confirmation before execution.

**With auto-approve** (careful!):
```bash
terraform apply -var-file="credentials.tfvars" -auto-approve
```

#### 5. Verification

```bash
# Terraform state
terraform state list

# Resource details
terraform state show proxmox_vm_qemu.valaskjalf_master_1

# Show outputs (if defined)
terraform output
```

#### 6. Destruction

```bash
terraform destroy -var-file="credentials.tfvars"
```

Destroys all resources managed by Terraform. Asks for confirmation.

### Selective Deployment

#### Create Only One Master

```bash
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1
```

#### Create All Masters

```bash
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1 \
  -target=proxmox_vm_qemu.valaskjalf_master_2 \
  -target=proxmox_vm_qemu.valaskjalf_master_3
```

#### Recreate a Worker

```bash
# Mark for recreation
terraform taint proxmox_vm_qemu.valaskjalf_worker_1

# Apply
terraform apply -var-file="credentials.tfvars"
```

## Modifications

### Add a Node

1. **Copy existing file**:
   ```bash
   cp valaskjalf-worker-3.tf valaskjalf-worker-4.tf
   ```

2. **Modify parameters**:
   ```hcl
   resource "proxmox_vm_qemu" "valaskjalf_worker_4" {
     name      = "valaskjalf-worker-4"
     vmid      = 1014
     ipconfig0 = "ip=10.10.10.114/24,gw=10.10.10.1"
     # ... rest identical ...
   }
   ```

3. **Apply**:
   ```bash
   terraform apply -var-file="credentials.tfvars"
   ```

### Modify Resources

**CPU**:
```hcl
cpu {
  cores   = 4  # Instead of 2 or 3
  sockets = 1
  type    = "host"
}
```

**RAM**:
```hcl
memory = 16384  # 16 GB instead of 4 or 12
```

**Disk**:
```hcl
disk {
  size     = 200  # 200 GB instead of 50 or 100
  storage  = "local-zfs"
  iothread = true
}
```

After modification:
```bash
terraform apply -var-file="credentials.tfvars"
```

### Remove a Node

1. **Delete the file** or comment out the resource
2. **Apply**:
   ```bash
   terraform apply -var-file="credentials.tfvars"
   ```

## Troubleshooting

### Proxmox Connection Error

```
Error: error creating VM: error calling post https://...
```

**Solutions**:
- Verify API URL
- Check credentials
- Verify network connectivity
- Check user permissions

### "Template not found" Error

```
Error: template 'pkr-ubuntu-noble-1' not found
```

**Solution**: Create template with Packer first.

### IP Conflict Error

```
Error: IP address already in use
```

**Solution**: Verify IP isn't already used. Modify `ipconfig0`.

### Creation Timeout

```
Error: timeout while waiting for VM to become ready
```

**Solutions**:
- Verify QEMU Guest Agent is installed in template
- Increase timeouts in provider
- Check Proxmox logs

### Corrupted Terraform State

```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup

# Reset a resource
terraform state rm proxmox_vm_qemu.valaskjalf_worker_1

# Re-import from Proxmox
terraform import proxmox_vm_qemu.valaskjalf_worker_1 asgard/qemu/1011
```

## Terraform State

### terraform.tfstate File

**Contains**:
- Current state of all resources
- Metadata and Proxmox IDs
- Mappings between Terraform resources and Proxmox VMs

**Important**:
- Don't edit manually
- Backup regularly
- Don't commit (already in .gitignore)

### Remote Backend (optional)

For team use or automatic backup:

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Or other backends: Consul, etcd, HTTP, etc.

## Best Practices

1. **Variables**: Use `.tfvars` files for credentials
2. **Modules**: For code reuse (optional here)
3. **State**: Backup `terraform.tfstate` regularly
4. **Plan**: Always `plan` before `apply`
5. **Comments**: Document complex configurations
6. **Tags**: Use tags to organize resources
7. **Validation**: Test on one node before deploying entire cluster

## Automation

### Deployment Script

```bash
#!/bin/bash
set -e

cd terraform

echo "Initializing Terraform..."
terraform init

echo "Validating configuration..."
terraform validate

echo "Planning changes..."
terraform plan -var-file="credentials.tfvars" -out=plan.tfplan

echo "Applying changes..."
terraform apply plan.tfplan

echo "Deployment complete!"
terraform state list
```

### CI/CD (GitLab CI example)

```yaml
stages:
  - validate
  - plan
  - apply

validate:
  stage: validate
  script:
    - cd terraform
    - terraform init
    - terraform validate

plan:
  stage: plan
  script:
    - cd terraform
    - terraform plan -var-file="credentials.tfvars"
  only:
    - merge_requests

apply:
  stage: apply
  script:
    - cd terraform
    - terraform apply -var-file="credentials.tfvars" -auto-approve
  only:
    - main
  when: manual
```

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [Telmate Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
