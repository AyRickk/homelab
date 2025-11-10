# 🏠 Homelab Boilerplate - Proxmox + RKE2 Infrastructure as Code

<div align="center">

![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Kubernetes](https://img.shields.io/badge/RKE2-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

**Production-ready template for deploying RKE2 clusters on Proxmox using Infrastructure as Code**

[📖 Documentation](./docs) • [🚀 Getting Started](./GETTING-STARTED.md) • [⚙️ Configuration](#-configuration)

</div>

---

> **🎯 What is this?**  
> This is a **boilerplate/template repository** for building your own homelab infrastructure. Fork it, customize it, and deploy a production-ready Kubernetes cluster on Proxmox in minutes!

## 💡 Why Use This Boilerplate?

Stop starting from scratch every time you rebuild your homelab! This template provides:

- ✨ **Battle-tested configurations** for Proxmox + RKE2
- 🚀 **Ready to deploy** - Just update credentials and go
- 📚 **Comprehensive documentation** - Learn as you build
- 🔧 **Fully customizable** - Adapt to your network and needs
- 🏗️ **Infrastructure as Code** - Reproducible, version-controlled infrastructure
- 🔐 **Security hardened** - SSH best practices, no passwords

**Perfect for:** Homelab enthusiasts, DevOps learners, Kubernetes experimenters, self-hosting advocates

## 📋 Table of Contents

- [Features](#-features)
- [Hardware Requirements](#-hardware-requirements)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Configuration](#-configuration)
- [Customization](#-customization)
- [Documentation](#-documentation)
- [Contributing](#-contributing)

## ✨ Features

This boilerplate includes everything you need to deploy a production-ready Kubernetes cluster:

### Infrastructure as Code
- ✅ **Packer templates** for automated VM image creation
- ✅ **Terraform modules** for infrastructure deployment
- ✅ **Cloud-init** for automatic VM configuration
- ✅ **Version controlled** - Track all changes in Git

### Production-Ready Setup
- ✅ **High availability** - 3 master nodes with etcd quorum
- ✅ **Scalable workers** - 3 worker nodes (easily add more)
- ✅ **Static networking** - Predictable IP addresses
- ✅ **SSH hardening** - Key-only auth on non-standard port (2222), YubiKey support
- ✅ **Performance optimized** - VirtIO, iothread, CPU passthrough

### Comprehensive Documentation
- ✅ **Step-by-step guides** - From zero to running cluster
- ✅ **Architecture diagrams** - Understand what you're building
- ✅ **Troubleshooting tips** - Common issues and solutions
- ✅ **Customization examples** - Adapt to your environment
- ✅ **Real-world setup** - Based on actual production homelab

## 💻 Hardware Requirements

This boilerplate is designed for homelab enthusiasts with a dedicated server. Here's what you need:

### Minimum Requirements
- **CPU**: 4+ cores (8 cores recommended)
- **RAM**: 32GB minimum (64GB recommended)
- **Storage**: 500GB+ (SSD/NVMe recommended for ZFS)
- **Network**: Gigabit Ethernet

### Reference Hardware Setup

This boilerplate was built and tested on:

- **Server**: Repurposed gaming PC
- **CPU**: Intel Core i9-9900K (8 cores, 16 threads, up to 5.0 GHz)
- **RAM**: 64 GB DDR4
- **GPU**: NVIDIA GeForce RTX 2080 (available for GPU passthrough)
- **Storage**: ZFS pool on SSD/NVMe
- **Network**: 1 Gbps Ethernet

> 💡 **GPU Passthrough**: The RTX 2080 can be passed through to VMs for GPU-accelerated workloads like AI/ML, gaming VMs, or transcoding. Documentation for GPU passthrough setup will be added in future updates.

> 🔐 **Security Hardware**: This setup uses a YubiKey for SSH authentication, providing hardware-based security. See the [Getting Started Guide](./GETTING-STARTED.md#yubikey-ssh-setup) for YubiKey configuration.

## 🚀 Quick Start

**Want to deploy fast?** Here's the TL;DR:

```bash
# 1. Fork and clone this repo
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# 2. Setup credentials
cp packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl.example \
   packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl
cp terraform/credentials.tfvars.example terraform/credentials.tfvars
# Edit both files with your Proxmox details

# 3. Build the VM template
cd packer/90001-pkr-ubuntu-noble-1
packer init .
packer build -var-file="credentials.pkrvars.hcl" .

# 4. Deploy infrastructure
cd ../../terraform
terraform init
terraform apply -var-file="credentials.tfvars"

# 5. Deploy RKE2 Kubernetes cluster (optional)
cd ../ansible
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventory.yml install-rke2.yml
```

**⚠️ First time?** Check the [detailed Getting Started guide](./GETTING-STARTED.md) for a complete walkthrough!

## 🎯 What You Get

After deploying this boilerplate, you'll have:

```
Proxmox VE (asgard)
└── VM Template: Ubuntu 24.04 LTS
    └── RKE2 Cluster (valaskjalf)
        ├── 3x Master Nodes (Control Plane)
        │   └── 2 vCPU, 4GB RAM, 50GB disk each
        └── 3x Worker Nodes
            └── 3 vCPU, 12GB RAM, 100GB disk each
```

**Total Resources:** 15 vCPUs, 48GB RAM, 450GB storage

## 🏗️ Architecture

### Default Configuration

This boilerplate deploys the following infrastructure (easily customizable):

**Proxmox Node:** `asgard` (change to match your node name)  
**Network:** 10.10.10.0/24 (customize to your network)  
**Storage:** local-zfs (adjust to your storage pool)

### VM Specifications

#### Master Nodes (Control Plane)
| Name | VMID | IP | vCPU | RAM | Disk |
|------|------|-----|------|-----|------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | 2 | 4 GB | 50 GB |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | 2 | 4 GB | 50 GB |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | 2 | 4 GB | 50 GB |

#### Worker Nodes
| Name | VMID | IP | vCPU | RAM | Disk |
|------|------|-----|------|-----|------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | 3 | 12 GB | 100 GB |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | 3 | 12 GB | 100 GB |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | 3 | 12 GB | 100 GB |

**Network:** 10.10.10.0/24 with gateway 10.10.10.1

> 💡 **Tip:** All names, IPs, and resources are customizable! See the [Getting Started guide](./GETTING-STARTED.md#step-2-customize-configuration) for details.

## 📦 Prerequisites

Before using this boilerplate, ensure you have:

### Infrastructure
- ✅ A server running **Proxmox VE** (tested on 8.x)
- ✅ At least 32GB RAM (64GB recommended) and 500GB storage available
- ✅ Network access to Proxmox API
- ✅ Ubuntu 24.04 LTS ISO uploaded to Proxmox

### Local Tools
- ✅ [Terraform](https://www.terraform.io/downloads) >= 1.0
- ✅ [Packer](https://www.packer.io/downloads) >= 1.9
- ✅ SSH key pair generated (`ssh-keygen -t rsa -b 4096`) or YubiKey configured
- ✅ Git installed

### Knowledge (Helpful but not required)
- 🎓 Basic Terraform and Packer usage
- 🎓 Proxmox basics (or willingness to learn!)
- 🎓 SSH and Linux fundamentals
- 🎓 Basic Kubernetes concepts

> 📚 **New to these tools?** Don't worry! The documentation includes explanations and examples.

## 🚦 Getting Started

### For First-Time Users

**Never deployed infrastructure as code before?** Start here:

1. 📖 Read the [Getting Started Guide](./GETTING-STARTED.md) - Complete walkthrough
2. 🔧 Follow [Step 2: Customize Configuration](./GETTING-STARTED.md#step-2-customize-configuration)
3. 🔐 Setup credentials using the provided example files
4. 🚀 Deploy step-by-step following the guide

### For Experienced Users

**Already familiar with Terraform/Packer?** Quick path:

1. Fork this repository
2. Copy example credentials and fill in your details:
   ```bash
   cp packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl.example \
      packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl
   
   cp terraform/credentials.tfvars.example terraform/credentials.tfvars
   ```
3. Customize network/names in Terraform files if needed
4. Build template: `packer build -var-file="credentials.pkrvars.hcl" .`
5. Deploy: `terraform apply -var-file="credentials.tfvars"`

## ⚙️ Configuration

### Credential Files

This boilerplate includes example credential files that you copy and customize:

**Packer credentials** (`packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl`):
- Proxmox API URL, token ID, and secret
- SSH username and temporary password for build
- Your SSH public key

**Terraform credentials** (`terraform/credentials.tfvars`):
- Proxmox API URL and credentials
- Your SSH public key (same as Packer)
- Hashed password for cloud-init user

📋 **See example files:**
- [`packer/.../credentials.pkrvars.hcl.example`](packer/90001-pkr-ubuntu-noble-1/credentials.pkrvars.hcl.example)
- [`terraform/credentials.tfvars.example`](terraform/credentials.tfvars.example)

### Customization Points

This boilerplate is designed to be easily customized:

| What to Customize | Where | Difficulty |
|-------------------|-------|------------|
| **Network IPs** | `terraform/*.tf` → `ipconfig0` | ⭐ Easy |
| **VM Resources** | `terraform/*.tf` → `cpu`, `memory`, `disk` | ⭐ Easy |
| **Node Names** | `terraform/*.tf` → `name`, `target_node` | ⭐⭐ Medium |
| **Cluster Name** | Rename `terraform/valaskjalf-*.tf` files | ⭐⭐ Medium |
| **SSH Port** | `packer/.../build.pkr.hcl` → provisioner | ⭐⭐ Medium |
| **OS/Packages** | `packer/.../http/user-data` | ⭐⭐⭐ Advanced |

📖 **Detailed customization guide:** [GETTING-STARTED.md#step-2-customize-configuration](./GETTING-STARTED.md#step-2-customize-configuration)

## 🎨 Customization Examples

### Change Network Range

```hcl
# In terraform/valaskjalf-master-1.tf (repeat for all files)
ipconfig0  = "ip=192.168.1.101/24,gw=192.168.1.1"  # Changed from 10.10.10.x
nameserver = "192.168.1.1"
```

### Increase Worker Resources

```hcl
# In terraform/valaskjalf-worker-1.tf
cpu {
  cores   = 6  # Increased from 3
}
memory = 24576  # 24GB instead of 12GB
disks {
  virtio {
    virtio0 {
      disk {
        size = 200  # 200GB instead of 100GB
      }
    }
  }
}
```

### Add More Workers

```bash
# Copy an existing worker file
cp terraform/valaskjalf-worker-3.tf terraform/valaskjalf-worker-4.tf

# Edit the new file:
# - Change resource name: valaskjalf_worker_4
# - Change VM name: "valaskjalf-worker-4"
# - Change VMID: 1014
# - Change IP: 10.10.10.114

# Apply
terraform apply -var-file="credentials.tfvars"
```

## 📁 Project Structure

```
homelab/
├── README.md                           # This file - Overview and quick start
├── GETTING-STARTED.md                  # Detailed setup guide
├── docs/                               # Comprehensive documentation
│   ├── infrastructure.md               # Architecture deep-dive
│   ├── packer.md                       # Packer template details
│   ├── terraform.md                    # Terraform configuration guide
│   ├── rke2-installation.md            # RKE2 + Cilium installation guide
│   └── gpu-passthrough.md              # GPU passthrough configuration
├── packer/                             # VM template creation
│   └── 90001-pkr-ubuntu-noble-1/
│       ├── credentials.pkrvars.hcl.example  # 👈 Copy and customize
│       ├── config.pkr.hcl              # Variable definitions
│       ├── build.pkr.hcl               # Build specification
│       ├── files/
│       │   └── 99-pve.cfg              # Cloud-init config
│       └── http/
│           ├── user-data               # Ubuntu autoinstall
│           └── meta-data
├── terraform/                          # Infrastructure deployment
│   ├── credentials.tfvars.example      # 👈 Copy and customize
│   ├── provider.tf                     # Proxmox provider config
│   ├── valaskjalf-master-1.tf          # Master node 1
│   ├── valaskjalf-master-2.tf          # Master node 2
│   ├── valaskjalf-master-3.tf          # Master node 3
│   ├── valaskjalf-worker-1.tf          # Worker node 1
│   ├── valaskjalf-worker-2.tf          # Worker node 2
│   └── valaskjalf-worker-3.tf          # Worker node 3
└── ansible/                            # Kubernetes deployment automation
    ├── requirements.yml                # Ansible Galaxy dependencies
    ├── inventory.yml                   # Cluster node inventory
    └── install-rke2.yml                # RKE2 + Cilium playbook
```

## 🔧 Usage

### Build VM Template

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Initialize Packer plugins
packer init .

# Validate configuration
packer validate -var-file="credentials.pkrvars.hcl" .

# Build template (~10-15 minutes)
packer build -var-file="credentials.pkrvars.hcl" .
```

### Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file="credentials.tfvars"

# Deploy all VMs
terraform apply -var-file="credentials.tfvars"

# Or deploy selectively (masters first, then workers)
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1 \
  -target=proxmox_vm_qemu.valaskjalf_master_2 \
  -target=proxmox_vm_qemu.valaskjalf_master_3
```

### Connect to VMs

VMs are configured with:
- **SSH Port:** 2222 (not 22!)
- **User:** odin (or your customized username)
- **Auth:** SSH key only (no passwords)

```bash
# Direct connection
ssh -p 2222 odin@10.10.10.101

# Or configure ~/.ssh/config for easier access
cat >> ~/.ssh/config << EOF
Host homelab-*
    Port 2222
    User odin
    IdentityFile ~/.ssh/id_rsa

Host homelab-master-1
    HostName 10.10.10.101
EOF

# Then simply:
ssh homelab-master-1
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy -var-file="credentials.tfvars"
```

> ⚠️ **Warning:** This will permanently delete all VMs!

## 📚 Documentation

Comprehensive guides are available in the [`docs/`](./docs) directory:

| Document | Description |
|----------|-------------|
| [**Getting Started**](./GETTING-STARTED.md) | Complete setup walkthrough for beginners |
| [**Infrastructure**](./docs/infrastructure.md) | Architecture deep-dive, components, HA setup, hardware specs |
| [**Packer**](./docs/packer.md) | VM template creation, customization, troubleshooting |
| [**Terraform**](./docs/terraform.md) | Infrastructure deployment, state management, workflows |
| [**RKE2 Installation**](./docs/rke2-installation.md) | Complete guide for installing RKE2 with Cilium CNI using Ansible |
| [**Ingress Controller**](./docs/ingress-controller.md) | Traefik ingress with automatic TLS using cert-manager and OVH DNS |
| [**GPU Passthrough**](./docs/gpu-passthrough.md) | NVIDIA RTX 2080 PCIe passthrough configuration |
| [**Documentation Roadmap**](./docs/ROADMAP.md) | Planned documentation and future topics |

### Future Documentation Topics

As this homelab evolves, the following guides will be added:

- ✅ **RKE2 Deployment** - Step-by-step Kubernetes cluster setup with Cilium CNI
- ✅ **Ingress Controller** - Traefik with automatic TLS using cert-manager and OVH DNS
- 🔜 **Monitoring Stack** - Prometheus, Grafana, and alerting
- 🔜 **Storage Solutions** - Longhorn, NFS, and persistent volumes
- 🔜 **GitOps with ArgoCD** - Automated deployments
- 🔜 **Backup & Recovery** - Automated backup strategies
- 🔜 **Homelab Services** - Common self-hosted applications

See the [Documentation Roadmap](./docs/ROADMAP.md) for the complete list and status.

## 🤝 Contributing

This is a boilerplate/template project, but improvements are welcome!

### Ways to Contribute

- 🐛 **Report bugs** or issues you encounter
- 💡 **Suggest improvements** for better usability
- 📖 **Improve documentation** with clarifications or examples
- ⭐ **Star the repo** if you find it useful!
- 🔀 **Share your fork** and customizations with the community

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

### Sharing Your Setup

If you've customized this boilerplate for your homelab:

1. Fork this repository
2. Make your customizations
3. Document your changes in your fork's README
4. Share a link in the Discussions or Issues!

Others can learn from your configuration choices.

## 🎓 Project Inspiration

This project was inspired by excellent community projects like:

- [ChristianLempa/boilerplates](https://github.com/ChristianLempa/boilerplates) - Great collection of boilerplates for homelab
- Various homelab enthusiasts sharing their Infrastructure as Code setups

The goal is to provide not just working code, but comprehensive documentation that explains the "why" and "how" behind every decision, making it useful both as a template and as a learning resource.

## 📝 About This Project

This homelab project serves multiple purposes:

- **Personal Documentation** - A comprehensive record of my homelab setup and evolution
- **Boilerplate Template** - Ready-to-use infrastructure code for others
- **Learning Resource** - Detailed explanations for those new to homelabbing
- **Living Documentation** - Updated as the homelab grows with new services and capabilities

Whether you're here to fork the boilerplate, learn about homelab setups, or just exploring, welcome! The documentation is written to be helpful whether you're returning to this project after years or discovering it for the first time.

## 💭 Feedback & Support

- 🐛 **Found a bug?** [Open an issue](../../issues)
- 💡 **Have a suggestion?** [Start a discussion](../../discussions)
- ❓ **Need help?** Check the [Getting Started guide](./GETTING-STARTED.md) or open an issue


---

<div align="center">

**Ready to build your homelab?**

[🚀 Get Started](./GETTING-STARTED.md) • [📖 Read the Docs](./docs) • [⭐ Star this Repo](../../stargazers)

Made with ❤️ for the homelab community

</div>
