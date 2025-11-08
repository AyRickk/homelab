# 🌐 Configuration Réseau

## Vue d'ensemble

Ce document détaille la configuration réseau du homelab, incluant l'adressage IP, la configuration Proxmox, et le setup réseau des VMs via cloud-init.

## Topologie réseau

```
                    Internet
                        │
                        │
                   ┌────▼────┐
                   │ Gateway │
                   │10.10.10.1│
                   └────┬────┘
                        │
        ┌───────────────┴───────────────┐
        │      Bridge vmbr0              │
        │      Proxmox Node (asgard)     │
        └───────────────┬───────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                                │
    ┌───▼───┐                       ┌───▼───┐
    │Masters│                       │Workers│
    │       │                       │       │
    │ .101  │                       │ .111  │
    │ .102  │                       │ .112  │
    │ .103  │                       │ .113  │
    └───────┘                       └───────┘
```

## Plan d'adressage IP

### Réseau principal

- **Réseau** : 10.10.10.0/24
- **Masque** : 255.255.255.0 (/24)
- **Passerelle** : 10.10.10.1
- **DNS** : 10.10.10.1
- **Plage utilisable** : 10.10.10.1 - 10.10.10.254

### Attribution des adresses

| Plage | Type | Usage | Quantité |
|-------|------|-------|----------|
| 10.10.10.1 | Statique | Gateway/DNS | 1 |
| 10.10.10.2-99 | Statique | Infrastructure | Réservé |
| 10.10.10.100-109 | Statique | RKE2 Masters | 3 utilisées |
| 10.10.10.110-119 | Statique | RKE2 Workers | 3 utilisées |
| 10.10.10.120-199 | Statique | Autres services | Disponible |
| 10.10.10.200-254 | DHCP/Dynamique | Temporaire | Disponible |

### Adresses RKE2

#### Masters (Control Plane)

| Hostname | IP | VMID | Usage |
|----------|-----|------|-------|
| valaskjalf-master-1 | 10.10.10.101 | 1001 | Control Plane + etcd |
| valaskjalf-master-2 | 10.10.10.102 | 1002 | Control Plane + etcd |
| valaskjalf-master-3 | 10.10.10.103 | 1003 | Control Plane + etcd |

#### Workers

| Hostname | IP | VMID | Usage |
|----------|-----|------|-------|
| valaskjalf-worker-1 | 10.10.10.111 | 1011 | Workloads |
| valaskjalf-worker-2 | 10.10.10.112 | 1012 | Workloads |
| valaskjalf-worker-3 | 10.10.10.113 | 1013 | Workloads |

## Configuration Proxmox

### Bridge réseau

**Nom** : vmbr0

Configuration typique dans `/etc/network/interfaces` :

```
auto vmbr0
iface vmbr0 inet static
    address 10.10.10.x/24
    gateway 10.10.10.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

**Paramètres** :
- **bridge-ports** : Interface physique (ex: eno1, eth0)
- **bridge-stp** : Spanning Tree Protocol (off pour simple setup)
- **bridge-fd** : Forward delay (0 pour performance)

### Firewall Proxmox

Par défaut, le firewall Proxmox peut être configuré pour :
- Autoriser SSH (port 2222) vers les VMs
- Autoriser l'API Kubernetes (6443) entre les masters
- Autoriser etcd (2379-2380) entre les masters
- Autoriser les communications inter-pods

Dans notre setup homelab :
- Firewall généralement désactivé sur vmbr0 (`firewall: false`)
- Sécurité gérée au niveau des VMs et des services

## Configuration VM (cloud-init)

### Cloud-init dans Terraform

Chaque VM est configurée avec des IP statiques via cloud-init :

```hcl
# Master 1
os_type    = "cloud-init"
ipconfig0  = "ip=10.10.10.101/24,gw=10.10.10.1"
nameserver = "10.10.10.1"
```

**Paramètres** :
- `ip=10.10.10.101/24` : IP statique avec masque /24
- `gw=10.10.10.1` : Passerelle par défaut
- `nameserver` : Serveur DNS

### Datasources cloud-init

Configuration dans le template (99-pve.cfg) :

```yaml
datasource_list: [ConfigDrive, NoCloud]
```

**Datasources** :
- **ConfigDrive** : Utilisé par Proxmox pour injecter la config
- **NoCloud** : Fallback pour cloud-init générique

### Configuration réseau appliquée

Cloud-init génère automatiquement la configuration netplan :

```yaml
# /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 10.10.10.101/24
      gateway4: 10.10.10.1
      nameservers:
        addresses:
          - 10.10.10.1
```

**Interface** : Généralement `ens18` ou `ens19` avec VirtIO sur Proxmox

### Appliquer les changements réseau

```bash
# Afficher la config
sudo netplan get

# Générer la configuration
sudo netplan generate

# Appliquer
sudo netplan apply

# Vérifier
ip addr show
ip route show
```

## DNS

### Configuration DNS

**Serveur DNS** : 10.10.10.1 (typiquement votre box/routeur ou serveur DNS local)

Dans les VMs :
```bash
# Vérifier la config DNS
cat /etc/resolv.conf

# Devrait contenir :
nameserver 10.10.10.1
```

### Résolution de noms

Pour RKE2, la résolution DNS intra-cluster est gérée par CoreDNS (déployé automatiquement).

**Noms de domaine** :
- Services Kubernetes : `<service>.<namespace>.svc.cluster.local`
- Pods : `<pod-ip>.<namespace>.pod.cluster.local`

### DNS externe (optionnel)

Pour accéder aux nœuds par nom d'hôte en dehors du cluster :

1. **Ajouter des entrées DNS** dans votre serveur DNS :
   ```
   valaskjalf-master-1.home.lab    A    10.10.10.101
   valaskjalf-master-2.home.lab    A    10.10.10.102
   valaskjalf-master-3.home.lab    A    10.10.10.103
   valaskjalf-worker-1.home.lab    A    10.10.10.111
   valaskjalf-worker-2.home.lab    A    10.10.10.112
   valaskjalf-worker-3.home.lab    A    10.10.10.113
   ```

2. **Ou utiliser /etc/hosts** localement :
   ```bash
   # Sur votre machine locale
   sudo tee -a /etc/hosts << EOF
   10.10.10.101 valaskjalf-master-1
   10.10.10.102 valaskjalf-master-2
   10.10.10.103 valaskjalf-master-3
   10.10.10.111 valaskjalf-worker-1
   10.10.10.112 valaskjalf-worker-2
   10.10.10.113 valaskjalf-worker-3
   EOF
   ```

## SSH

### Configuration SSH

**Port** : 2222 (personnalisé pour sécurité)

Configuration dans `/etc/ssh/sshd_config.d/99-security.conf` :

```
Port 2222
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AuthenticationMethods publickey
```

### Connexion SSH

```bash
# Connexion standard
ssh -p 2222 odin@10.10.10.101

# Avec clé spécifique
ssh -p 2222 -i ~/.ssh/homelab_key odin@10.10.10.101

# Configuration SSH locale (~/.ssh/config)
Host valaskjalf-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

# Puis simplement :
ssh valaskjalf-master-1
```

### SSH Config complet

```
# ~/.ssh/config

# Masters
Host valaskjalf-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

Host valaskjalf-master-2
    HostName 10.10.10.102
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

Host valaskjalf-master-3
    HostName 10.10.10.103
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

# Workers
Host valaskjalf-worker-1
    HostName 10.10.10.111
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

Host valaskjalf-worker-2
    HostName 10.10.10.112
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

Host valaskjalf-worker-3
    HostName 10.10.10.113
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key

# Wildcard pour tous les nœuds
Host valaskjalf-*
    Port 2222
    User odin
    IdentityFile ~/.ssh/homelab_key
    StrictHostKeyChecking accept-new
```

## Ports réseau

### Ports système

| Port | Protocole | Service | Usage |
|------|-----------|---------|-------|
| 2222 | TCP | SSH | Administration |
| 8006 | TCP | Proxmox API | Gestion Proxmox |

### Ports RKE2

#### Control Plane (Masters)

| Port | Protocole | Service | Direction |
|------|-----------|---------|-----------|
| 6443 | TCP | Kubernetes API | Externe → Masters |
| 9345 | TCP | RKE2 Supervisor | Workers → Masters |
| 2379 | TCP | etcd client | Masters ↔ Masters |
| 2380 | TCP | etcd peer | Masters ↔ Masters |
| 10250 | TCP | Kubelet metrics | Interne |
| 10259 | TCP | kube-scheduler | Interne |
| 10257 | TCP | kube-controller | Interne |

#### Workers

| Port | Protocole | Service | Direction |
|------|-----------|---------|-----------|
| 10250 | TCP | Kubelet metrics | Interne |
| 30000-32767 | TCP/UDP | NodePort Services | Externe → Workers |

#### CNI (Flannel/Calico)

| Port | Protocole | Service | Direction |
|------|-----------|---------|-----------|
| 4789 | UDP | VXLAN | All nodes |
| 8472 | UDP | Flannel VXLAN | All nodes |
| 179 | TCP | BGP (Calico) | All nodes |

## Firewall (si activé)

### UFW - Example Masters

```bash
# SSH
sudo ufw allow 2222/tcp

# Kubernetes API
sudo ufw allow from 10.10.10.0/24 to any port 6443 proto tcp

# RKE2 Supervisor
sudo ufw allow from 10.10.10.0/24 to any port 9345 proto tcp

# etcd
sudo ufw allow from 10.10.10.101 to any port 2379:2380 proto tcp
sudo ufw allow from 10.10.10.102 to any port 2379:2380 proto tcp
sudo ufw allow from 10.10.10.103 to any port 2379:2380 proto tcp

# Kubelet
sudo ufw allow from 10.10.10.0/24 to any port 10250 proto tcp

# CNI (Flannel VXLAN)
sudo ufw allow from 10.10.10.0/24 to any port 8472 proto udp

# Activer
sudo ufw enable
```

### UFW - Example Workers

```bash
# SSH
sudo ufw allow 2222/tcp

# RKE2 Supervisor (vers masters)
sudo ufw allow to 10.10.10.101 port 9345 proto tcp
sudo ufw allow to 10.10.10.102 port 9345 proto tcp
sudo ufw allow to 10.10.10.103 port 9345 proto tcp

# Kubelet
sudo ufw allow from 10.10.10.0/24 to any port 10250 proto tcp

# NodePort Services
sudo ufw allow 30000:32767/tcp
sudo ufw allow 30000:32767/udp

# CNI (Flannel VXLAN)
sudo ufw allow from 10.10.10.0/24 to any port 8472 proto udp

# Activer
sudo ufw enable
```

## Troubleshooting

### Vérifier la connectivité

```bash
# Ping gateway
ping -c 3 10.10.10.1

# Ping autre nœud
ping -c 3 10.10.10.102

# Traceroute
traceroute 10.10.10.1

# Test DNS
nslookup google.com
dig google.com

# Vérifier les routes
ip route show

# Vérifier les interfaces
ip addr show

# Statistiques réseau
ip -s link show
```

### Problèmes communs

#### Pas d'accès réseau

```bash
# Vérifier interface
ip link show

# Vérifier IP
ip addr show

# Réappliquer netplan
sudo netplan apply

# Redémarrer networking
sudo systemctl restart systemd-networkd
```

#### DNS ne fonctionne pas

```bash
# Vérifier resolv.conf
cat /etc/resolv.conf

# Tester DNS directement
nslookup google.com 8.8.8.8

# Vérifier systemd-resolved
sudo systemctl status systemd-resolved

# Logs cloud-init
sudo cat /var/log/cloud-init.log | grep -i network
```

#### SSH impossible

```bash
# Vérifier que SSH écoute
sudo ss -tlnp | grep 2222

# Vérifier le service
sudo systemctl status ssh

# Logs SSH
sudo tail -f /var/log/auth.log

# Tester depuis Proxmox console
# Ouvrir la console VM dans Proxmox et tester localement
```

#### Changement d'IP

Si vous devez changer l'IP d'une VM :

1. **Modifier dans Terraform** :
   ```hcl
   ipconfig0 = "ip=10.10.10.XXX/24,gw=10.10.10.1"
   ```

2. **Appliquer** :
   ```bash
   terraform apply -var-file="credentials.tfvars"
   ```

3. **Ou manuellement dans la VM** :
   ```bash
   sudo nano /etc/netplan/50-cloud-init.yaml
   # Modifier l'IP
   sudo netplan apply
   ```

## Monitoring réseau

### Outils utiles

```bash
# Installation
sudo apt install -y net-tools iftop nethogs iperf3

# Monitoring en temps réel
sudo iftop -i ens18

# Bande passante par processus
sudo nethogs ens18

# Test de performance
# Sur le serveur
iperf3 -s

# Sur le client
iperf3 -c 10.10.10.101
```

### Statistiques

```bash
# Statistiques globales
netstat -s

# Connexions actives
ss -tuna

# Table de routage
ip route show table all

# Statistiques interfaces
ip -s -s link show ens18
```

## Sécurité réseau

### Bonnes pratiques

1. **Firewall** : Activer et configurer UFW ou iptables
2. **SSH** : Port non-standard (2222), clés uniquement
3. **Fail2ban** : Protection contre brute-force SSH
4. **VPN** : Accès via VPN pour l'administration
5. **Segmentation** : VLAN pour séparer les environnements (prod/dev)
6. **Monitoring** : Surveiller le trafic réseau

### Fail2ban pour SSH

```bash
# Installation
sudo apt install -y fail2ban

# Configuration
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# Activer
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Statut
sudo fail2ban-client status sshd
```

## Références

- [Proxmox Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration)
- [Cloud-init Network Config](https://cloudinit.readthedocs.io/en/latest/topics/network-config.html)
- [Netplan Documentation](https://netplan.io/)
- [RKE2 Network Requirements](https://docs.rke2.io/install/requirements#networking)
- [Ubuntu Server Network](https://ubuntu.com/server/docs/network-configuration)
