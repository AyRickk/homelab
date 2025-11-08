# 📦 Packer - Création de templates VM

## Introduction

Ce document décrit l'utilisation de Packer pour créer des templates de machines virtuelles Ubuntu sur Proxmox.

## Vue d'ensemble

Packer permet de créer des templates VM reproductibles et automatisés. Le template créé sert de base pour tous les nœuds du cluster RKE2.

## Template Ubuntu Noble

**Emplacement** : `packer/90001-pkr-ubuntu-noble-1/`

Ce template crée une VM Ubuntu 24.04 LTS (Noble Numbat) optimisée pour Proxmox et cloud-init.

### Fichiers

```
90001-pkr-ubuntu-noble-1/
├── config.pkr.hcl       # Variables et configuration
├── build.pkr.hcl        # Build specification et provisioning
├── files/
│   └── 99-pve.cfg       # Configuration cloud-init pour Proxmox
└── http/
    ├── user-data        # Configuration autoinstall Ubuntu
    └── meta-data        # Métadonnées (vide)
```

## Configuration (config.pkr.hcl)

### Plugin Proxmox

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

| Variable | Type | Description | Sensible |
|----------|------|-------------|----------|
| `proxmox_api_url` | string | URL de l'API Proxmox | Non |
| `proxmox_api_token_id` | string | ID du token API | Non |
| `proxmox_api_token_secret` | string | Secret du token | Oui |
| `ssh_username` | string | Utilisateur SSH (odin) | Non |
| `ssh_password` | string | Mot de passe temporaire | Oui |
| `public_key` | string | Clé SSH publique | Oui |

## Build specification (build.pkr.hcl)

### Source proxmox-iso

Configuration de la VM template :

#### Proxmox
- **Node** : `asgard`
- **VMID** : `90001`
- **Nom** : `pkr-ubuntu-noble-1`
- **Description** : "Ubuntu 24.04 LTS"

#### ISO
- **Source** : `local:iso/ubuntu-24.04.3-live-server-amd64.iso`
- **Type** : SCSI
- **Storage** : local

#### Matériel
- **CPU** : 1 core, 1 socket
- **RAM** : 2048 MB
- **Disque** : 20 GB (raw format sur local-zfs)
- **Network** : VirtIO sur vmbr0
- **SCSI Controller** : virtio-scsi-pci
- **VGA** : VirtIO
- **QEMU Agent** : Activé
- **Cloud-init** : Activé (storage: local-zfs)

#### Boot

**Boot command** pour Ubuntu autoinstall :
```
<esc><wait>
e<wait>
<down><down><down><end>
<bs><bs><bs><bs><wait>
autoinstall ds=nocloud-net\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>
<f10><wait>
```

- **Boot wait** : 6 secondes
- **HTTP directory** : `http/` (sert user-data et meta-data)

#### SSH
- **Communicator** : SSH
- **Username** : valeur de `var.ssh_username`
- **Password** : valeur de `var.ssh_password`
- **Timeout** : 30 minutes
- **PTY** : Activé
- **Handshake attempts** : 15

### Provisioning

Le build exécute plusieurs étapes de provisioning :

#### 1. Nettoyage cloud-init

```bash
# Attendre la fin de cloud-init
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do 
    echo 'Waiting for cloud-init...'; 
    sleep 1; 
done

# Supprimer les host keys SSH (seront régénérés)
sudo rm /etc/ssh/ssh_host_*

# Réinitialiser machine-id
sudo truncate -s 0 /etc/machine-id

# Nettoyage APT
sudo apt -y autoremove --purge
sudo apt -y clean
sudo apt -y autoclean

# Réinitialiser cloud-init
sudo cloud-init clean

# Supprimer la config réseau de l'installeur
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo rm -f /etc/netplan/00-installer-config.yaml

sudo sync
```

#### 2. Configuration cloud-init pour Proxmox

Copie le fichier `files/99-pve.cfg` vers `/etc/cloud/cloud.cfg.d/99-pve.cfg`.

**Contenu de 99-pve.cfg** :
```yaml
datasource_list: [ConfigDrive, NoCloud]
```

Configure cloud-init pour utiliser les datasources Proxmox (ConfigDrive) et NoCloud.

#### 3. Installation de la clé SSH et sécurisation

```bash
# Installation de la clé SSH publique
echo 'ssh-rsa AAAA...' > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Configuration SSH sécurisée
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

# Test de la configuration
sudo sshd -t
```

**Sécurisation SSH** :
- Port personnalisé : 2222
- Authentification par clé uniquement
- Pas de login root
- Pas d'authentification par mot de passe

## Autoinstall (http/user-data)

Configuration Ubuntu autoinstall (cloud-config format) :

```yaml
#cloud-config
autoinstall:
  version: 1
  locale: fr_FR
  keyboard:
    layout: fr
  ssh:
    install-server: true
    allow-pw: false          # Pas d'auth par mot de passe
    disable_root: true       # Root désactivé
  storage:
    layout:
      name: direct
    swap:
      size: 0                # Pas de swap (recommandé pour K8s)
  user-data:
    package_upgrade: true    # Mise à jour des packages
    timezone: Europe/Paris
    ssh_pwauth: true         # Temporaire pour le build Packer
    users:
      - name: odin
        groups: [adm, sudo]
        lock-passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        passwd: $6$...       # Hash du mot de passe
  packages:
    - qemu-guest-agent       # Agent QEMU pour Proxmox
    - sudo
    - vim
    - zip
    - unzip
```

### Paramètres importants

- **Locale** : fr_FR (français)
- **Clavier** : fr (AZERTY)
- **Timezone** : Europe/Paris
- **Swap** : 0 (désactivé, recommandé pour Kubernetes)
- **Utilisateur** : odin avec sudo sans mot de passe
- **Packages** : qemu-guest-agent + outils de base

## Utilisation

### Prérequis

1. **ISO Ubuntu** dans Proxmox :
   ```bash
   # Sur le serveur Proxmox
   cd /var/lib/vz/template/iso
   wget https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso
   ```

2. **Packer installé** :
   ```bash
   # macOS
   brew install packer
   
   # Linux
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/
   ```

### Créer le fichier credentials

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

### Créer un token API Proxmox

```bash
# Sur le serveur Proxmox (ou via l'interface web)
pveum user add packer@pve
pveum aclmod / -user packer@pve -role PVEVMAdmin
pveum user token add packer@pve packer-token --privsep=0
```

### Construire le template

```bash
cd packer/90001-pkr-ubuntu-noble-1

# Initialiser les plugins
packer init .

# Valider la configuration
packer validate -var-file="credentials.pkrvars.hcl" .

# Construire le template
packer build -var-file="credentials.pkrvars.hcl" .
```

### Suivi du build

Le build prend environ 10-15 minutes :

1. **Création de la VM** (VMID 90001)
2. **Boot sur l'ISO Ubuntu**
3. **Autoinstall** via cloud-init
4. **Provisioning** (nettoyage, config SSH, etc.)
5. **Conversion en template**

Surveillez :
- Console Proxmox pour l'installation
- Sortie Packer pour le provisioning
- Logs dans `/tmp/packer-*` sur le serveur Proxmox

### Vérification

Après le build, dans Proxmox :

1. Template visible : `pkr-ubuntu-noble-1` (VMID 90001)
2. Type : Template (non démarrable)
3. Cloud-init configuré
4. QEMU Agent détecté

## Troubleshooting

### Erreur de connexion SSH

- Vérifier que le mot de passe temporaire est correct
- Augmenter `ssh_timeout` si nécessaire
- Vérifier que l'autoinstall est terminé

### Timeout pendant l'autoinstall

- Vérifier que l'ISO Ubuntu est bien présente
- Vérifier la boot command
- Vérifier que le serveur HTTP Packer est accessible

### Erreur API Proxmox

- Vérifier l'URL et le token
- Vérifier les permissions du token
- Vérifier le certificat SSL (insecure_skip_tls_verify)

### Cloud-init ne démarre pas

- Vérifier que le package cloud-init est installé
- Vérifier les datasources dans 99-pve.cfg
- Vérifier les logs : `sudo cloud-init status --long`

## Modifications

### Changer la configuration Ubuntu

Modifier `http/user-data` :
- Locale et timezone
- Packages à installer
- Configuration utilisateur
- Paramètres réseau

### Ajouter des provisioners

Dans `build.pkr.hcl`, ajouter après les provisioners existants :

```hcl
provisioner "shell" {
  inline = [
    "# Vos commandes ici",
  ]
}
```

### Créer un nouveau template

1. Copier le dossier `90001-pkr-ubuntu-noble-1`
2. Renommer (ex: `90002-pkr-debian-12`)
3. Modifier config.pkr.hcl et build.pkr.hcl
4. Adapter user-data pour la distribution
5. Build avec Packer

## Bonnes pratiques

1. **Versioning** : Inclure la version dans le nom (ex: ubuntu-24.04-v1)
2. **Minimal** : Installer uniquement le nécessaire
3. **Cloud-init** : Toujours utiliser cloud-init pour Proxmox
4. **Sécurité** : Pas de credentials hardcodés
5. **Nettoyage** : Toujours nettoyer les artefacts (logs, cache, etc.)
6. **Testing** : Tester le template avant de l'utiliser en production

## Références

- [Packer Proxmox Builder](https://www.packer.io/plugins/builders/proxmox)
- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Proxmox Cloud-init](https://pve.proxmox.com/wiki/Cloud-Init_Support)
