# 📦 Packer - VM Template Creation

## Introduction

This document describes how to use Packer to create Ubuntu virtual machine templates on Proxmox.

## Overview

Packer allows you to create reproducible and automated VM templates. The created template serves as the base for all RKE2 cluster nodes.

## Ubuntu Noble Template

**Location**: `packer/90001-pkr-ubuntu-noble-1/`

This template creates an Ubuntu 24.04 LTS (Noble Numbat) VM optimized for Proxmox and cloud-init.

### Files

```
90001-pkr-ubuntu-noble-1/
├── config.pkr.hcl       # Variables and configuration
├── build.pkr.hcl        # Build specification and provisioning
├── files/
│   └── 99-pve.cfg       # Cloud-init configuration for Proxmox
└── http/
    ├── user-data        # Ubuntu autoinstall configuration
    └── meta-data        # Metadata (empty)
```

## Configuration (config.pkr.hcl)

### Proxmox Plugin

```hcl
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```

### Variables

| Variable | Type | Description | Sensitive |
|----------|------|-------------|----------|
| `proxmox_api_url` | string | Proxmox API URL | No |
| `proxmox_api_token_id` | string | API token ID | No |
| `proxmox_api_token_secret` | string | Token secret | Yes |
| `ssh_username` | string | SSH username (odin) | No |
| `ssh_password` | string | Temporary password | Yes |
| `public_key` | string | SSH public key (supports YubiKey) | Yes |

> 💡 **YubiKey Support**: The `public_key` can be your YubiKey's SSH public key. See the [Getting Started Guide](../GETTING-STARTED.md#yubikey-ssh-setup) for YubiKey configuration.

## Build Specification (build.pkr.hcl)

### Source proxmox-iso

VM template configuration:

#### Proxmox
- **Node**: `asgard`
- **VMID**: `90001`
- **Name**: `pkr-ubuntu-noble-1`
- **Description**: "Ubuntu 24.04 LTS"

#### ISO
- **Source**: `local:iso/ubuntu-24.04.3-live-server-amd64.iso`
- **Type**: SCSI
- **Storage**: local

#### Hardware
- **CPU**: 1 core, 1 socket
- **RAM**: 2048 MB
- **Disk**: 20 GB (raw format on local-zfs)
- **Network**: VirtIO on vmbr0
- **SCSI Controller**: virtio-scsi-pci
- **VGA**: VirtIO
- **QEMU Agent**: Enabled
- **Cloud-init**: Enabled (storage: local-zfs)

#### Boot

**Boot command** for Ubuntu autoinstall:
```
<esc><wait>
e<wait>
<down><down><down><end>
<bs><bs><bs><bs><wait>
autoinstall ds=nocloud-net\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>
<f10><wait>
```

- **Boot wait**: 6 seconds
- **HTTP directory**: `http/` (serves user-data and meta-data)

#### SSH
- **Communicator**: SSH
- **Username**: value of `var.ssh_username`
- **Password**: value of `var.ssh_password`
- **Timeout**: 30 minutes
- **PTY**: Enabled
- **Handshake attempts**: 15

### Provisioning

The build executes several provisioning steps:

#### 1. Cloud-init Cleanup

```bash
# Wait for cloud-init to finish
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do 
    echo 'Waiting for cloud-init...'; 
    sleep 1; 
done

# Remove SSH host keys (will be regenerated)
sudo rm /etc/ssh/ssh_host_*

# Reset machine-id
sudo truncate -s 0 /etc/machine-id

# APT cleanup
sudo apt -y autoremove --purge
sudo apt -y clean
sudo apt -y autoclean

# Reset cloud-init
sudo cloud-init clean

# Remove installer network config
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo rm -f /etc/netplan/00-installer-config.yaml

sudo sync
```

#### 2. Cloud-init Configuration for Proxmox

Copies the file `files/99-pve.cfg` to `/etc/cloud/cloud.cfg.d/99-pve.cfg`.

**Content of 99-pve.cfg**:
```yaml
datasource_list: [ConfigDrive, NoCloud]
```

Configures cloud-init to use Proxmox datasources (ConfigDrive) and NoCloud.

#### 3. SSH Key Installation and Hardening

```bash
# Install SSH public key
echo 'ssh-rsa AAAA...' > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Secure SSH configuration
sudo tee /etc/ssh/sshd_config.d/99-security.conf > /dev/null <<'EOF'
Port 2222
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AuthenticationMethods publickey
EOF

# Test configuration
sudo sshd -t
```

**SSH Hardening**:
- Custom port: 2222
- Key-only authentication
- No root login
- No password authentication

## Autoinstall (http/user-data)

Ubuntu autoinstall configuration (cloud-config format):

```yaml
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  ssh:
    install-server: true
    allow-pw: false          # No password authentication
    disable_root: true       # Root disabled
  storage:
    layout:
      name: direct
    swap:
      size: 0                # No swap (recommended for K8s)
  user-data:
    package_upgrade: true    # Update packages
    timezone: UTC
    ssh_pwauth: true         # Temporary for Packer build
    users:
      - name: odin
        groups: [adm, sudo]
        lock-passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        passwd: $6$...       # Password hash
  packages:
    - qemu-guest-agent       # QEMU Agent for Proxmox
    - sudo
    - vim
    - zip
    - unzip
```

### Important Parameters

- **Locale**: en_US.UTF-8 (English) - customize in user-data if needed
- **Keyboard**: us (QWERTY) - change to your preferred layout (uk, de, fr, etc.)
- **Timezone**: UTC (configurable via cloud-init later) - can be changed to your timezone
- **Swap**: 0 (disabled, recommended for Kubernetes)
- **User**: odin with passwordless sudo
- **Packages**: qemu-guest-agent + basic tools

> 💡 **Customization Tip**: While the default locale is English (en_US.UTF-8) and keyboard is US, you can easily change these in the `http/user-data` file to match your preferences (e.g., `locale: fr_FR`, `layout: fr` for French).

## Usage

### Prerequisites

1. **Ubuntu ISO** in Proxmox:
   ```bash
   # On Proxmox server
   cd /var/lib/vz/template/iso
   wget https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso
   ```

2. **Packer installed**:
   ```bash
   # macOS
   brew install packer
   
   # Linux
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

### Create Credentials File

```bash
cd packer/90001-pkr-ubuntu-noble-1

cat > credentials.pkrvars.hcl << 'EOF'
proxmox_api_url          = "https://10.10.10.x:8006/api2/json"
proxmox_api_token_id     = "packer@pve!packer-token"
proxmox_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ssh_username             = "odin"
ssh_password             = "temporary-password"
public_key               = "ssh-rsa AAAAB3NzaC1yc2EA... user@host"
EOF
```

> 💡 **YubiKey Users**: For the `public_key`, use your YubiKey's SSH public key. Extract it with: `ssh-keygen -D /path/to/libykcs11.so -e`

### Create Proxmox API Token

```bash
# On Proxmox server (or via web interface)
pveum user add packer@pve
pveum aclmod / -user packer@pve -role PVEVMAdmin
pveum user token add packer@pve packer-token --privsep=0
```

### Build the Template

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Initialize plugins
packer init .

# Validate configuration
packer validate -var-file="credentials.pkrvars.hcl" .

# Build template
packer build -var-file="credentials.pkrvars.hcl" .
```

### Build Monitoring

The build takes about 10-15 minutes:

1. **VM Creation** (VMID 90001)
2. **Boot Ubuntu ISO**
3. **Autoinstall** via cloud-init
4. **Provisioning** (cleanup, SSH config, etc.)
5. **Convert to template**

Monitor:
- Proxmox console for installation
- Packer output for provisioning
- Logs in `/tmp/packer-*` on Proxmox server

### Verification

After the build, in Proxmox:

1. Template visible: `pkr-ubuntu-noble-1` (VMID 90001)
2. Type: Template (not bootable)
3. Cloud-init configured
4. QEMU Agent detected

## Troubleshooting

### SSH Connection Error

- Verify temporary password is correct
- Increase `ssh_timeout` if necessary
- Verify autoinstall is complete

### Autoinstall Timeout

- Verify Ubuntu ISO is present
- Check boot command
- Verify Packer HTTP server is accessible

### Proxmox API Error

- Verify URL and token
- Check token permissions
- Verify SSL certificate (insecure_skip_tls_verify)

### Cloud-init Won't Start

- Verify cloud-init package is installed
- Check datasources in 99-pve.cfg
- Check logs: `sudo cloud-init status --long`

## Modifications

### Change Ubuntu Configuration

Modify `http/user-data`:
- Locale and timezone
- Packages to install
- User configuration
- Network settings

### Add Provisioners

In `build.pkr.hcl`, add after existing provisioners:

```hcl
provisioner "shell" {
  inline = [
    "# Your commands here",
  ]
}
```

### Create New Template

1. Copy the folder `90001-pkr-ubuntu-noble-1`
2. Rename (e.g., `90002-pkr-debian-12`)
3. Modify config.pkr.hcl and build.pkr.hcl
4. Adapt user-data for the distribution
5. Build with Packer

## Best Practices

1. **Versioning**: Include version in name (e.g., ubuntu-24.04-v1)
2. **Minimal**: Install only what's necessary
3. **Cloud-init**: Always use cloud-init for Proxmox
4. **Security**: No hardcoded credentials
5. **Cleanup**: Always clean artifacts (logs, cache, etc.)
6. **Testing**: Test template before production use

## References

- [Packer Proxmox Builder](https://www.packer.io/plugins/builders/proxmox)
- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Proxmox Cloud-init](https://pve.proxmox.com/wiki/Cloud-Init_Support)
