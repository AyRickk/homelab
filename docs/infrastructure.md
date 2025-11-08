# 🏗️ Infrastructure Overview

## Vue d'ensemble

Ce document décrit l'architecture de l'infrastructure homelab basée sur Proxmox et RKE2.

## Architecture globale

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

## Composants

### Proxmox VE

**Nœud** : `asgard`

Proxmox Virtual Environment est l'hyperviseur de base qui héberge toutes les machines virtuelles. Il fournit :

- Virtualisation KVM/QEMU
- Gestion centralisée via API REST
- Storage ZFS pour les performances et la fiabilité
- Réseau virtuel via bridge Linux

**Configuration** :
- Storage principal : `local-zfs`
- Bridge réseau : `vmbr0`
- ISO storage : `local`

### Template VM Ubuntu

**Template** : `pkr-ubuntu-noble-1` (VMID 90001)

Template de machine virtuelle créé avec Packer, basé sur Ubuntu 24.04 LTS (Noble Numbat). Ce template sert de base pour tous les nœuds du cluster.

**Caractéristiques** :
- OS : Ubuntu 24.04.3 LTS Server
- Cloud-init activé pour la personnalisation automatique
- QEMU Guest Agent installé
- SSH sécurisé (port 2222, authentification par clé uniquement)
- Packages de base : vim, zip, unzip
- Locale : fr_FR
- Timezone : Europe/Paris

### Cluster RKE2

**Nom du cluster** : `valaskjalf`

RKE2 (Rancher Kubernetes Engine 2) est une distribution Kubernetes certifiée, optimisée pour la sécurité et la conformité.

#### Control Plane (Masters)

Les nœuds masters exécutent les composants du plan de contrôle Kubernetes :
- **etcd** : base de données distribuée du cluster
- **kube-apiserver** : point d'entrée de l'API Kubernetes
- **kube-scheduler** : planification des pods
- **kube-controller-manager** : contrôleurs de ressources

**Configuration par master** :
- vCPU : 2 cores (type host)
- RAM : 4 GB
- Disque : 50 GB (local-zfs, iothread activé)
- Network : VirtIO sur vmbr0
- SCSI : virtio-scsi-pci
- Auto-boot : activé

| Hostname | VMID | IP Address | Rôle |
|----------|------|------------|------|
| valaskjalf-master-1 | 1001 | 10.10.10.101/24 | Control Plane |
| valaskjalf-master-2 | 1002 | 10.10.10.102/24 | Control Plane |
| valaskjalf-master-3 | 1003 | 10.10.10.103/24 | Control Plane |

#### Worker Nodes

Les nœuds workers exécutent les charges de travail applicatives (pods, conteneurs).

**Configuration par worker** :
- vCPU : 3 cores (type host)
- RAM : 12 GB
- Disque : 100 GB (local-zfs, iothread activé)
- Network : VirtIO sur vmbr0
- SCSI : virtio-scsi-pci
- Auto-boot : activé

| Hostname | VMID | IP Address | Rôle |
|----------|------|------------|------|
| valaskjalf-worker-1 | 1011 | 10.10.10.111/24 | Worker |
| valaskjalf-worker-2 | 1012 | 10.10.10.112/24 | Worker |
| valaskjalf-worker-3 | 1013 | 10.10.10.113/24 | Worker |

## Réseau

### Configuration IP

- **Réseau** : 10.10.10.0/24
- **Passerelle** : 10.10.10.1
- **DNS** : 10.10.10.1
- **Attribution** : IP statiques via cloud-init

### Plan d'adressage

| Plage | Usage |
|-------|-------|
| 10.10.10.1 | Gateway/DNS |
| 10.10.10.101-103 | Masters RKE2 |
| 10.10.10.111-113 | Workers RKE2 |

## Sécurité

### SSH

- **Port** : 2222 (non-standard pour réduire les scans automatiques)
- **Authentification** : Clé publique uniquement
- **Root login** : Désactivé
- **Password authentication** : Désactivé
- **Utilisateur** : `odin` avec privilèges sudo

### Cloud-init

- Datasources : ConfigDrive, NoCloud
- Configuration réseau via cloud-init (pas de netplan persistant)
- SSH keys injectées au démarrage
- Mot de passe hashé pour accès console si nécessaire

## Storage

### Proxmox Storage

- **Type** : ZFS
- **Pool** : `local-zfs`
- **Fonctionnalités** :
  - Snapshots
  - Compression
  - Checksums
  - Copy-on-write

### VM Disks

- **Format** : Raw (meilleure performance)
- **Bus** : VirtIO (performance optimale)
- **iothread** : Activé (améliore les performances I/O)

## Performance

### Optimisations CPU

- **Type** : `host` (CPU passthrough)
- Toutes les fonctionnalités CPU de l'hôte sont passées aux VMs
- Meilleure performance pour les charges de travail Kubernetes

### Optimisations réseau

- **Modèle** : VirtIO (paravirtualization)
- Meilleure performance réseau que E1000 émulé
- Support des fonctionnalités avancées (multiqueue, etc.)

### Optimisations disque

- **iothread** : Un thread dédié pour les opérations I/O
- **VirtIO SCSI** : Meilleure performance que IDE
- **ZFS** : Compression et checksums transparents

## Haute disponibilité

### Masters

- **3 nœuds masters** pour le quorum etcd (tolérance : 1 panne)
- Distribution sur le même hôte Proxmox (single node homelab)
- Auto-boot activé pour redémarrage automatique

### Workers

- **3 nœuds workers** pour la distribution des charges
- Capacité à gérer la panne d'un worker
- Auto-boot activé

## Monitoring et gestion

### QEMU Guest Agent

Installé sur toutes les VMs pour :
- Informations système détaillées
- Shutdown/reboot propres
- Snapshot avec freeze du filesystem
- Injection de mots de passe

### Tags Proxmox

- Tag `rke2` appliqué à toutes les VMs du cluster
- Facilite le filtrage et l'organisation dans l'interface Proxmox

## Évolutivité

### Ajouter un master

1. Copier et adapter un fichier `valaskjalf-master-X.tf`
2. Modifier : name, vmid, IP
3. Appliquer avec Terraform

### Ajouter un worker

1. Copier et adapter un fichier `valaskjalf-worker-X.tf`
2. Modifier : name, vmid, IP
3. Appliquer avec Terraform

### Ressources

Ajuster dans les fichiers Terraform :
- `cpu.cores` : nombre de vCPUs
- `memory` : RAM en MB
- `disks.virtio.virtio0.disk.size` : taille disque en GB

## Maintenance

### Backup

Utiliser les fonctionnalités de backup Proxmox :
- Backup planifié des VMs
- Snapshots ZFS
- Export de la configuration Terraform

### Mises à jour

- OS : `apt update && apt upgrade` sur chaque VM
- RKE2 : via les mécanismes de mise à jour RKE2
- Template : Reconstruire avec Packer et redéployer

### Destruction

```bash
cd terraform
terraform destroy -var-file="credentials.tfvars"
```

> ⚠️ **Attention** : Cela supprimera toutes les VMs définies dans Terraform !
