# 🏠 Homelab - Infrastructure as Code

<div align="center">

![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Kubernetes](https://img.shields.io/badge/RKE2-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

**Infrastructure as Code pour cluster RKE2 sur Proxmox**

[Documentation](./docs) • [Configuration](#-configuration) • [Démarrage rapide](#-démarrage-rapide)

</div>

---

## 📋 Table des matières

- [À propos](#-à-propos)
- [Architecture](#-architecture)
- [Prérequis](#-prérequis)
- [Structure du projet](#-structure-du-projet)
- [Démarrage rapide](#-démarrage-rapide)
- [Configuration](#-configuration)
- [Utilisation](#-utilisation)
- [Documentation](#-documentation)
- [Licence](#-licence)

## 🎯 À propos

Ce projet implémente une infrastructure complète de homelab basée sur **Proxmox**, entièrement gérée en tant que code (Infrastructure as Code). L'objectif est de déployer et maintenir un cluster **RKE2** (Rancher Kubernetes Engine 2) de manière reproductible et automatisée.

### Fonctionnalités principales

- ✅ **Templates VM automatisés** avec Packer (Ubuntu 24.04 LTS)
- ✅ **Déploiement d'infrastructure** avec Terraform
- ✅ **Cluster RKE2 haute disponibilité** (3 masters + 3 workers)
- ✅ **Configuration réseau statique** avec cloud-init
- ✅ **Sécurisation SSH** (authentification par clé uniquement, port personnalisé)
- ✅ **Optimisations de performance** (VirtIO, iothread, CPU host passthrough)

## 🏗️ Architecture

L'infrastructure est composée de :

### Nœud Proxmox
- **Nom** : `asgard`
- **Hyperviseur** : Proxmox VE
- **Storage** : local-zfs

### Cluster RKE2

#### Masters Nodes (Control Plane)
| Nom | VMID | IP | vCPU | RAM | Disque |
|-----|------|-----|------|-----|--------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | 2 | 4 GB | 50 GB |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | 2 | 4 GB | 50 GB |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | 2 | 4 GB | 50 GB |

#### Worker Nodes
| Nom | VMID | IP | vCPU | RAM | Disque |
|-----|------|-----|------|-----|--------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | 3 | 12 GB | 100 GB |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | 3 | 12 GB | 100 GB |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | 3 | 12 GB | 100 GB |

**Réseau** : 10.10.10.0/24 avec passerelle 10.10.10.1

## 📦 Prérequis

### Logiciels requis

- [Proxmox VE](https://www.proxmox.com/) (installé sur le serveur)
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Packer](https://www.packer.io/downloads) >= 1.9
- ISO Ubuntu 24.04 LTS dans Proxmox (`local:iso/ubuntu-24.04.3-live-server-amd64.iso`)

### Accès Proxmox

- Accès API Proxmox avec credentials appropriés
- Token API ou compte root pour l'authentification
- Réseau configuré sur `vmbr0`
- Storage pool `local-zfs` disponible

### Connaissances recommandées

- Infrastructure as Code (IaC)
- Virtualisation avec Proxmox
- Bases de Kubernetes/RKE2
- Linux système (Ubuntu)

## 📁 Structure du projet

```
.
├── README.md                    # Ce fichier
├── docs/                        # Documentation détaillée
│   ├── infrastructure.md        # Vue d'ensemble de l'infrastructure
│   ├── packer.md               # Documentation Packer (templates VM)
│   ├── terraform.md            # Documentation Terraform (déploiement)
│   └── network.md              # Configuration réseau
├── packer/                      # Templates Packer
│   └── 90001-pkr-ubuntu-noble-1/
│       ├── config.pkr.hcl      # Configuration variables
│       ├── build.pkr.hcl       # Build specification
│       ├── files/              # Fichiers à copier dans le template
│       │   └── 99-pve.cfg      # Config cloud-init pour Proxmox
│       └── http/               # Fichiers servis via HTTP pour autoinstall
│           ├── user-data       # Configuration cloud-init
│           └── meta-data       # Métadonnées cloud-init
└── terraform/                   # Configuration Terraform
    ├── provider.tf             # Configuration du provider Proxmox
    ├── valaskjalf-master-*.tf  # Définitions des masters
    └── valaskjalf-worker-*.tf  # Définitions des workers
```

## 🚀 Démarrage rapide

### 1. Cloner le repository

```bash
git clone <repository-url>
cd homelab
```

### 2. Créer le template Packer

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Créer un fichier credentials.pkrvars.hcl avec vos identifiants
cat > credentials.pkrvars.hcl << EOF
proxmox_api_url          = "https://your-proxmox:8006/api2/json"
proxmox_api_token_id     = "your-token-id"
proxmox_api_token_secret = "your-token-secret"
ssh_username             = "odin"
ssh_password             = "your-temp-password"
public_key               = "ssh-rsa AAAA... your-public-key"
EOF

# Initialiser et construire le template
packer init .
packer build -var-file="credentials.pkrvars.hcl" .
```

### 3. Déployer l'infrastructure avec Terraform

```bash
cd terraform

# Créer un fichier credentials.tfvars avec vos identifiants
cat > credentials.tfvars << EOF
PROXMOX_API_URL       = "https://your-proxmox:8006/api2/json"
PROXMOX_ROOT_USER     = "root@pam"
PROXMOX_ROOT_PASSWORD = "your-password"
PUBLIC_SSH_KEY        = "ssh-rsa AAAA... your-public-key"
CI_ODIN_PASSWORD      = "hashed-password"
EOF

# Initialiser et déployer
terraform init
terraform plan -var-file="credentials.tfvars"
terraform apply -var-file="credentials.tfvars"
```

## ⚙️ Configuration

### Variables Packer

Créez un fichier `credentials.pkrvars.hcl` dans le dossier packer avec :

| Variable | Description |
|----------|-------------|
| `proxmox_api_url` | URL de l'API Proxmox |
| `proxmox_api_token_id` | ID du token API |
| `proxmox_api_token_secret` | Secret du token API |
| `ssh_username` | Nom d'utilisateur SSH (défaut: odin) |
| `ssh_password` | Mot de passe temporaire pour le build |
| `public_key` | Clé SSH publique à installer |

### Variables Terraform

Créez un fichier `credentials.tfvars` dans le dossier terraform avec :

| Variable | Description |
|----------|-------------|
| `PROXMOX_API_URL` | URL de l'API Proxmox |
| `PROXMOX_ROOT_USER` | Utilisateur Proxmox (ex: root@pam) |
| `PROXMOX_ROOT_PASSWORD` | Mot de passe Proxmox |
| `PUBLIC_SSH_KEY` | Clé SSH publique pour les VMs |
| `CI_ODIN_PASSWORD` | Mot de passe hashé pour cloud-init |

> ⚠️ **Important** : Ne commitez jamais vos fichiers credentials ! Ils sont déjà dans `.gitignore`.

## 🔧 Utilisation

### Construire un nouveau template

```bash
cd packer/90001-pkr-ubuntu-noble-1
packer build -var-file="credentials.pkrvars.hcl" .
```

### Gérer l'infrastructure

```bash
cd terraform

# Voir les changements prévus
terraform plan -var-file="credentials.tfvars"

# Appliquer les changements
terraform apply -var-file="credentials.tfvars"

# Détruire l'infrastructure
terraform destroy -var-file="credentials.tfvars"
```

### Se connecter aux VMs

Les VMs sont configurées avec :
- **Port SSH** : 2222
- **Utilisateur** : odin
- **Authentification** : Clé SSH uniquement

```bash
# Exemple de connexion
ssh -p 2222 odin@10.10.10.101
```

## 📚 Documentation

Documentation détaillée disponible dans le dossier [`docs/`](./docs) :

- **[Infrastructure](./docs/infrastructure.md)** - Vue d'ensemble et architecture
- **[Packer](./docs/packer.md)** - Création de templates VM
- **[Terraform](./docs/terraform.md)** - Déploiement d'infrastructure
- **[Réseau](./docs/network.md)** - Configuration réseau

## 📝 Licence

Ce projet est un homelab personnel. Utilisez-le comme référence ou base pour votre propre infrastructure.

---

<div align="center">
  Fait avec ❤️ pour l'apprentissage et l'automatisation
</div>