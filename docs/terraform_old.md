# 🔧 Terraform - Déploiement d'infrastructure

## Introduction

Ce document décrit l'utilisation de Terraform pour déployer et gérer l'infrastructure du cluster RKE2 sur Proxmox.

## Vue d'ensemble

Terraform permet de définir l'infrastructure en tant que code et de la gérer de manière déclarative. Toutes les VMs du cluster sont définies dans des fichiers `.tf` et déployées automatiquement.

## Structure des fichiers

```
terraform/
├── provider.tf              # Configuration du provider Proxmox
├── valaskjalf-master-1.tf   # Master node 1
├── valaskjalf-master-2.tf   # Master node 2
├── valaskjalf-master-3.tf   # Master node 3
├── valaskjalf-worker-1.tf   # Worker node 1
├── valaskjalf-worker-2.tf   # Worker node 2
└── valaskjalf-worker-3.tf   # Worker node 3
```

## Configuration du Provider (provider.tf)

### Provider Proxmox

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

**Provider** : [Telmate/proxmox](https://registry.terraform.io/providers/Telmate/proxmox)  
**Version** : 3.0.2-rc05 (release candidate avec support amélioré)

### Variables

| Variable | Type | Description | Sensible |
|----------|------|-------------|----------|
| `PROXMOX_API_URL` | string | URL de l'API Proxmox | Non |
| `PROXMOX_ROOT_USER` | string | Utilisateur Proxmox (ex: root@pam) | Oui |
| `PROXMOX_ROOT_PASSWORD` | string | Mot de passe Proxmox | Oui |
| `PUBLIC_SSH_KEY` | string | Clé SSH publique pour les VMs | Oui |
| `CI_ODIN_PASSWORD` | string | Mot de passe hashé pour cloud-init | Oui |

### Configuration Provider

```hcl
provider "proxmox" {
  pm_api_url      = var.PROXMOX_API_URL
  pm_user         = var.PROXMOX_ROOT_USER
  pm_password     = var.PROXMOX_ROOT_PASSWORD
  pm_tls_insecure = true  # Ignorer les erreurs SSL (homelab)
}
```

## Ressources VM

Chaque VM est définie par une ressource `proxmox_vm_qemu` avec des paramètres spécifiques.

### Structure d'une ressource Master

```hcl
resource "proxmox_vm_qemu" "valaskjalf_master_1" {
  # Configuration de base
  name        = "valaskjalf-master-1"
  description = "Production rke2 master 1, Master Node, Ubuntu LTS"
  vmid        = 1001
  target_node = "asgard"
  
  # Clonage depuis template
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
  
  # Mémoire
  memory = 4096  # 4 GB
  
  # Stockage
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
  
  # Réseau
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  # Paramètres système
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

### Structure d'une ressource Worker

Les workers ont plus de ressources que les masters :

```hcl
resource "proxmox_vm_qemu" "valaskjalf_worker_1" {
  # ... configuration similaire aux masters ...
  
  # CPU - Plus de cores pour les workloads
  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }
  
  # Mémoire - Plus de RAM pour les applications
  memory = 12288  # 12 GB
  
  # Stockage - Plus d'espace disque
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
  
  # IP différente
  ipconfig0 = "ip=10.10.10.111/24,gw=10.10.10.1"
}
```

## Configuration détaillée

### Clonage

```hcl
clone      = "pkr-ubuntu-noble-1"  # Template source
full_clone = true                   # Clone complet (pas linked)
```

**Full clone** : Copie complète et indépendante du template. Recommandé pour la production.

### CPU

```hcl
cpu {
  cores   = 2       # Nombre de cores
  sockets = 1       # Nombre de sockets
  type    = "host"  # CPU passthrough
}
```

**Type "host"** : Passe toutes les fonctionnalités CPU de l'hôte à la VM. Meilleure performance.

### Mémoire

- **Masters** : 4096 MB (4 GB) - Suffisant pour etcd + control plane
- **Workers** : 12288 MB (12 GB) - Nécessaire pour les workloads applicatifs

### Disques

```hcl
disks {
  virtio {
    virtio0 {
      disk {
        size     = 50           # Taille en GB
        storage  = "local-zfs"  # Storage pool Proxmox
        iothread = true         # Thread I/O dédié
      }
    }
  }
  ide {
    ide2 {
      cloudinit {
        storage = "local-zfs"   # Disque cloud-init
      }
    }
  }
}
```

**iothread** : Améliore les performances I/O, important pour etcd sur les masters.

### Réseau

```hcl
network {
  id     = 0         # Interface réseau 0
  model  = "virtio"  # Paravirtualization
  bridge = "vmbr0"   # Bridge Proxmox
}
```

**VirtIO** : Meilleure performance réseau que E1000 émulé.

### Cloud-init

```hcl
os_type    = "cloud-init"
ipconfig0  = "ip=10.10.10.101/24,gw=10.10.10.1"
nameserver = "10.10.10.1"
ciuser     = "odin"
cipassword = var.CI_ODIN_PASSWORD
sshkeys    = var.PUBLIC_SSH_KEY
```

**ipconfig0** : Configuration réseau statique  
**sshkeys** : Clés SSH publiques (séparées par `\n` si plusieurs)

## Inventaire des VMs

### Masters (Control Plane)

| Nom | VMID | IP | CPU | RAM | Disque | Fichier |
|-----|------|-----|-----|-----|--------|---------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-1.tf |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-2.tf |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | 2 cores | 4 GB | 50 GB | valaskjalf-master-3.tf |

**Total Masters** : 6 cores, 12 GB RAM, 150 GB disque

### Workers

| Nom | VMID | IP | CPU | RAM | Disque | Fichier |
|-----|------|-----|-----|-----|--------|---------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-1.tf |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-2.tf |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | 3 cores | 12 GB | 100 GB | valaskjalf-worker-3.tf |

**Total Workers** : 9 cores, 36 GB RAM, 300 GB disque

### Totaux Cluster

- **CPUs** : 15 cores (6 masters + 9 workers)
- **RAM** : 48 GB (12 GB masters + 36 GB workers)
- **Disque** : 450 GB (150 GB masters + 300 GB workers)

## Utilisation

### Prérequis

1. **Terraform installé** :
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Template Packer créé** : Le template `pkr-ubuntu-noble-1` doit exister dans Proxmox

3. **Accès réseau** : La machine exécutant Terraform doit pouvoir accéder à l'API Proxmox

### Configuration des credentials

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

### Générer un mot de passe hashé

Pour `CI_ODIN_PASSWORD` :

```bash
# Python
python3 -c 'import crypt; print(crypt.crypt("password", crypt.mksalt(crypt.METHOD_SHA512)))'

# OpenSSL
openssl passwd -6 -salt "yoursalt" "password"

# mkpasswd (si disponible)
mkpasswd -m sha-512
```

### Workflow Terraform

#### 1. Initialisation

```bash
cd terraform
terraform init
```

Télécharge le provider Proxmox et initialise le backend.

#### 2. Validation

```bash
terraform validate
```

Vérifie la syntaxe des fichiers `.tf`.

#### 3. Plan

```bash
terraform plan -var-file="credentials.tfvars"
```

Affiche les changements qui seront appliqués :
- Ressources à créer (+)
- Ressources à modifier (~)
- Ressources à détruire (-)

#### 4. Application

```bash
terraform apply -var-file="credentials.tfvars"
```

Applique les changements. Demande confirmation avant d'exécuter.

**Avec auto-approve** (attention !) :
```bash
terraform apply -var-file="credentials.tfvars" -auto-approve
```

#### 5. Vérification

```bash
# État Terraform
terraform state list

# Détails d'une ressource
terraform state show proxmox_vm_qemu.valaskjalf_master_1

# Afficher les outputs (si définis)
terraform output
```

#### 6. Destruction

```bash
terraform destroy -var-file="credentials.tfvars"
```

Détruit toutes les ressources gérées par Terraform. Demande confirmation.

### Déploiement sélectif

#### Créer uniquement un master

```bash
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1
```

#### Créer tous les masters

```bash
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_master_1 \
  -target=proxmox_vm_qemu.valaskjalf_master_2 \
  -target=proxmox_vm_qemu.valaskjalf_master_3
```

#### Recréer un worker

```bash
# Marquer pour recréation
terraform taint proxmox_vm_qemu.valaskjalf_worker_1

# Appliquer
terraform apply -var-file="credentials.tfvars"
```

## Modifications

### Ajouter un nœud

1. **Copier un fichier existant** :
   ```bash
   cp valaskjalf-worker-3.tf valaskjalf-worker-4.tf
   ```

2. **Modifier les paramètres** :
   ```hcl
   resource "proxmox_vm_qemu" "valaskjalf_worker_4" {
     name      = "valaskjalf-worker-4"
     vmid      = 1014
     ipconfig0 = "ip=10.10.10.114/24,gw=10.10.10.1"
     # ... reste identique ...
   }
   ```

3. **Appliquer** :
   ```bash
   terraform apply -var-file="credentials.tfvars"
   ```

### Modifier les ressources

**CPU** :
```hcl
cpu {
  cores   = 4  # Au lieu de 2 ou 3
  sockets = 1
  type    = "host"
}
```

**RAM** :
```hcl
memory = 16384  # 16 GB au lieu de 4 ou 12
```

**Disque** :
```hcl
disk {
  size     = 200  # 200 GB au lieu de 50 ou 100
  storage  = "local-zfs"
  iothread = true
}
```

Après modification :
```bash
terraform apply -var-file="credentials.tfvars"
```

### Supprimer un nœud

1. **Supprimer le fichier** ou commenter la ressource
2. **Appliquer** :
   ```bash
   terraform apply -var-file="credentials.tfvars"
   ```

## Troubleshooting

### Erreur de connexion à Proxmox

```
Error: error creating VM: error calling post https://...
```

**Solutions** :
- Vérifier l'URL de l'API
- Vérifier les credentials
- Vérifier la connectivité réseau
- Vérifier les permissions de l'utilisateur

### Erreur "Template not found"

```
Error: template 'pkr-ubuntu-noble-1' not found
```

**Solution** : Créer le template avec Packer d'abord.

### Erreur d'IP en conflit

```
Error: IP address already in use
```

**Solution** : Vérifier que l'IP n'est pas déjà utilisée. Modifier `ipconfig0`.

### Timeout lors de la création

```
Error: timeout while waiting for VM to become ready
```

**Solutions** :
- Vérifier que QEMU Guest Agent est installé dans le template
- Augmenter les timeouts dans le provider
- Vérifier les logs Proxmox

### État Terraform corrompu

```bash
# Backup du state
cp terraform.tfstate terraform.tfstate.backup

# Réinitialiser une ressource
terraform state rm proxmox_vm_qemu.valaskjalf_worker_1

# Réimporter depuis Proxmox
terraform import proxmox_vm_qemu.valaskjalf_worker_1 asgard/qemu/1011
```

## État Terraform

### Fichier terraform.tfstate

**Contient** :
- État actuel de toutes les ressources
- Métadonnées et IDs Proxmox
- Mappings entre ressources Terraform et VMs Proxmox

**Important** :
- Ne pas éditer manuellement
- Sauvegarder régulièrement
- Ne pas committer (déjà dans .gitignore)

### Backend distant (optionnel)

Pour un usage en équipe ou backup automatique :

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Ou autres backends : Consul, etcd, HTTP, etc.

## Bonnes pratiques

1. **Variables** : Utiliser des fichiers `.tfvars` pour les credentials
2. **Modules** : Pour réutiliser du code (optionnel ici)
3. **State** : Sauvegarder `terraform.tfstate` régulièrement
4. **Plan** : Toujours faire un `plan` avant `apply`
5. **Commentaires** : Documenter les configurations complexes
6. **Tags** : Utiliser des tags pour organiser les ressources
7. **Validation** : Tester sur un nœud avant de déployer tout le cluster

## Automatisation

### Script de déploiement

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

### CI/CD (exemple GitLab CI)

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

## Références

- [Terraform Documentation](https://www.terraform.io/docs)
- [Telmate Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Proxmox API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
