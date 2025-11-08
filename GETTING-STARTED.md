# 🚀 Getting Started Guide

This guide will walk you through forking and customizing this homelab boilerplate for your own infrastructure.

## Prerequisites

Before you begin, ensure you have:

- ✅ A server running Proxmox VE (tested on 8.x)
- ✅ Basic knowledge of Terraform and Packer
- ✅ SSH key pair generated (`ssh-keygen -t rsa -b 4096`)
- ✅ [Terraform](https://www.terraform.io/downloads) installed locally (>= 1.0)
- ✅ [Packer](https://www.packer.io/downloads) installed locally (>= 1.9)

## Step 1: Fork This Repository

1. Click the **Fork** button at the top right of this repository
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab.git
   cd homelab
   ```

## Step 2: Customize Configuration

### 2.1 Update Proxmox Node Name

The default Proxmox node name is `asgard`. If your node has a different name:

1. **In Packer** (`packer/90001-pkr-ubuntu-noble-1/build.pkr.hcl`):
   ```hcl
   node = "YOUR_NODE_NAME"  # Change from "asgard"
   ```

2. **In Terraform** (all `terraform/valaskjalf-*.tf` files):
   ```hcl
   target_node = "YOUR_NODE_NAME"  # Change from "asgard"
   ```

### 2.2 Customize Network Configuration

Default network: `10.10.10.0/24` with gateway `10.10.10.1`

To change the network:

1. **Update IP addresses** in Terraform files (`terraform/valaskjalf-*.tf`):
   ```hcl
   ipconfig0  = "ip=YOUR_IP/24,gw=YOUR_GATEWAY"
   nameserver = "YOUR_DNS_SERVER"
   ```

2. **Update the documentation** in `docs/network.md` to reflect your changes

### 2.3 Customize VM Names and Resources

Current cluster name: `valaskjalf`

To rename your cluster:

1. **Rename Terraform files**:
   ```bash
   mv terraform/valaskjalf-master-1.tf terraform/YOURNAME-master-1.tf
   # Repeat for all files
   ```

2. **Update resource names** in each file:
   ```hcl
   resource "proxmox_vm_qemu" "YOURNAME_master_1" {
     name = "YOURNAME-master-1"
     # ...
   }
   ```

To adjust resources (CPU, RAM, Disk):

```hcl
# In each Terraform file
cpu {
  cores   = 4  # Adjust cores
  sockets = 1
  type    = "host"
}

memory = 8192  # Adjust RAM in MB

disks {
  virtio {
    virtio0 {
      disk {
        size = 100  # Adjust disk size in GB
        # ...
      }
    }
  }
}
```

### 2.4 Customize User Configuration

Default user: `odin`

To change the username:

1. **In Packer** (`packer/90001-pkr-ubuntu-noble-1/http/user-data`):
   ```yaml
   users:
     - name: YOUR_USERNAME  # Change from "odin"
       # ...
   ```

2. **In Terraform** (all files):
   ```hcl
   ciuser = "YOUR_USERNAME"  # Change from "odin"
   ```

3. **Update SSH connection examples** in documentation

## Step 3: Setup Credentials

### 3.1 Create Proxmox API Token

On your Proxmox server:

```bash
# Create user for Packer
pveum user add packer@pve
pveum aclmod / -user packer@pve -role PVEVMAdmin

# Create API token
pveum user token add packer@pve packer-token --privsep=0
```

Save the token ID and secret for the next step.

### 3.2 Configure Packer Credentials

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Copy the example file
cp credentials.pkrvars.hcl.example credentials.pkrvars.hcl

# Edit with your values
nano credentials.pkrvars.hcl
```

Update:
- `proxmox_api_url` → Your Proxmox URL
- `proxmox_api_token_id` → Your token ID
- `proxmox_api_token_secret` → Your token secret
- `ssh_password` → A temporary password for the build
- `public_key` → Your SSH public key content

### 3.3 Configure Terraform Credentials

```bash
cd terraform

# Copy the example file
cp credentials.tfvars.example credentials.tfvars

# Edit with your values
nano credentials.tfvars
```

Update:
- `PROXMOX_API_URL` → Your Proxmox URL
- `PROXMOX_ROOT_USER` → Your Proxmox user (e.g., `root@pam`)
- `PROXMOX_ROOT_PASSWORD` → Your Proxmox password
- `PUBLIC_SSH_KEY` → Your SSH public key content
- `CI_ODIN_PASSWORD` → Hashed password (see below)

Generate a hashed password:
```bash
python3 -c 'import crypt; print(crypt.crypt("yourpassword", crypt.mksalt(crypt.METHOD_SHA512)))'
```

## Step 4: Prepare Proxmox

### 4.1 Upload Ubuntu ISO

Download Ubuntu 24.04 LTS ISO to your Proxmox server:

```bash
# On Proxmox server
cd /var/lib/vz/template/iso
wget https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso
```

### 4.2 Verify Storage

Ensure you have a `local-zfs` storage pool, or update the storage pool name in:
- `packer/90001-pkr-ubuntu-noble-1/build.pkr.hcl`
- All Terraform files (`terraform/valaskjalf-*.tf`)

## Step 5: Build the Template

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Initialize Packer
packer init .

# Validate configuration
packer validate -var-file="credentials.pkrvars.hcl" .

# Build the template (takes ~10-15 minutes)
packer build -var-file="credentials.pkrvars.hcl" .
```

This creates the VM template `pkr-ubuntu-noble-1` (VMID 90001) in Proxmox.

## Step 6: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file="credentials.tfvars"

# Deploy all VMs
terraform apply -var-file="credentials.tfvars"
```

Or deploy selectively:

```bash
# Deploy only masters
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1 \
  -target=proxmox_vm_qemu.valaskjalf_master_2 \
  -target=proxmox_vm_qemu.valaskjalf_master_3

# Deploy only workers
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_worker_1 \
  -target=proxmox_vm_qemu.valaskjalf_worker_2 \
  -target=proxmox_vm_qemu.valaskjalf_worker_3
```

## Step 7: Verify Deployment

### 7.1 Check Proxmox

In Proxmox web interface:
- Verify all VMs are created
- Check they're running
- Verify IP addresses via cloud-init

### 7.2 Test SSH Access

```bash
# Test connection (port 2222!)
ssh -p 2222 odin@10.10.10.101

# Or configure ~/.ssh/config:
cat >> ~/.ssh/config << EOF
Host homelab-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    IdentityFile ~/.ssh/id_rsa
EOF

# Then simply:
ssh homelab-master-1
```

## Step 8: Setup RKE2 (Next Steps)

At this point, you have:
- ✅ Ubuntu 24.04 LTS template
- ✅ 3 master VMs (control plane ready)
- ✅ 3 worker VMs (workload ready)
- ✅ Network configuration with static IPs
- ✅ SSH access configured

**Next:** Install and configure RKE2:

1. **Install RKE2 on first master**:
   ```bash
   ssh -p 2222 odin@10.10.10.101
   curl -sfL https://get.rke2.io | sudo sh -
   sudo systemctl enable rke2-server.service
   sudo systemctl start rke2-server.service
   ```

2. **Get the token**:
   ```bash
   sudo cat /var/lib/rancher/rke2/server/node-token
   ```

3. **Join other masters** (use the token from step 2)

4. **Join workers** (use the token from step 2)

For detailed RKE2 setup, see: https://docs.rke2.io/install/ha

## Troubleshooting

### Packer build fails

- Check Proxmox API credentials
- Verify ISO is present: `/var/lib/vz/template/iso/ubuntu-24.04.3-live-server-amd64.iso`
- Check Packer logs: `PACKER_LOG=1 packer build ...`

### Terraform errors

- Verify template exists: Check Proxmox for VM 90001
- Check network connectivity to Proxmox
- Verify credentials in `credentials.tfvars`

### Cannot SSH to VMs

- Wait 2-3 minutes after VM creation for cloud-init
- Check SSH is on port **2222**, not 22
- Verify your SSH key matches the one in credentials
- Check VM console in Proxmox for errors

### IP conflicts

- Ensure IPs aren't already in use on your network
- Update IPs in Terraform files to avoid conflicts

## Customization Ideas

Now that your base infrastructure is running, consider:

- 🔒 **Add Ansible** for configuration management
- 🔐 **Setup Vault** for secrets management
- 📊 **Deploy monitoring** (Prometheus + Grafana)
- 🔄 **Add GitOps** with ArgoCD or Flux
- 🌐 **Setup Ingress** with Traefik or Nginx Ingress
- 📦 **Deploy applications** to your K8s cluster

## Next Steps

1. ⭐ **Star this repository** if you find it useful!
2. 📝 **Document your customizations** in your fork
3. 🤝 **Share your setup** with the community
4. 🔄 **Keep your fork updated** with improvements

## Need Help?

- 📖 Check the [documentation](docs/)
- 🐛 Open an issue for bugs or questions
- 💬 Share your setup and get feedback

---

**Happy homelabbing! 🚀**
