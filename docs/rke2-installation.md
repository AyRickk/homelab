# 🚀 RKE2 - Kubernetes Cluster Deployment

## Introduction

This document describes how to deploy a High Availability RKE2 cluster with Cilium CNI and KubeVIP using Ansible automation.

## Overview

RKE2 (Rancher Kubernetes Engine 2) is a CNCF-certified Kubernetes distribution focused on security and compliance. Combined with Cilium's eBPF networking and KubeVIP's HA capabilities, it provides a production-ready platform for your homelab.

**Key Features:**
- **High Availability**: 3 master nodes with Virtual IP (10.10.10.100)
- **Cilium CNI**: eBPF-based networking with kube-proxy replacement
- **KubeVIP**: Automatic failover for API server access
- **Security**: Secrets encryption, audit logging, master node taints

## File Structure

```
ansible/
├── requirements.yml      # Ansible Galaxy dependencies
├── inventory.yml         # Cluster node inventory
├── install-rke2.yml      # Main deployment playbook
└── README.md            # Quick start guide
```

## Prerequisites

✅ **Infrastructure deployed** (see [Terraform](terraform.md))
- 3x Master nodes: 10.10.10.101-103 (2 vCPU, 4GB RAM each)
- 3x Worker nodes: 10.10.10.111-113 (3 vCPU, 12GB RAM each)
- Ubuntu 24.04 LTS with cloud-init

✅ **Ansible installed** on your local machine:
```bash
sudo apt install -y ansible  # Or: pip3 install ansible
```

✅ **SSH access** to all nodes on port 2222

## SSH Key Setup

### For Ansible Automation

Ansible requires a dedicated SSH key (YubiKey won't work with parallel connections):

```bash
# Generate dedicated key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_rke2 -C "ansible-automation"
```

### For YubiKey Users

If you use YubiKey for manual SSH access, configure `~/.ssh/config` for easier key distribution:

```bash
# Add host entries with PKCS11Provider
cat >> ~/.ssh/config << 'EOF'
Host homelab-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so  # Linux
    # PKCS11Provider /opt/homebrew/lib/libykcs11.dylib        # macOS

# Repeat for master-2, master-3, worker-1, worker-2, worker-3...
EOF

# Copy Ansible key using YubiKey auth (PIN/touch once per host)
for host in homelab-master-{1..3} homelab-worker-{1..3}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub $host
done
```

### For Non-YubiKey Users

```bash
# Copy key directly to all nodes
for ip in 10.10.10.{101..103} 10.10.10.{111..113}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub -p 2222 odin@$ip
done
```

## Ansible Configuration

### Requirements (requirements.yml)

```yaml
roles:
  - name: lablabs.rke2
    src: https://github.com/lablabs/ansible-role-rke2.git
    version: 1.49.0
```

**Role**: [lablabs/ansible-role-rke2](https://github.com/lablabs/ansible-role-rke2)  
**Documentation**: [Ansible Galaxy](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/documentation/)

### Inventory (inventory.yml)

**Key Configuration:**

| Variable | Value | Description |
|----------|-------|-------------|
| `ansible_user` | odin | SSH username |
| `ansible_port` | 2222 | SSH port |
| `ansible_ssh_private_key_file` | ~/.ssh/ansible_rke2 | Dedicated Ansible key |

**Node Groups:**
- `masters`: 3 nodes with `rke2_type: server`
- `workers`: 3 nodes with `rke2_type: agent`
- `k8s_cluster`: Combined group of all nodes

> 📁 **See**: [`ansible/inventory.yml`](../ansible/inventory.yml) for complete configuration

### Playbook (install-rke2.yml)

**Architecture:**
```
Virtual IP (10.10.10.100)
├── Masters (Control Plane)
│   ├── valaskjalf-master-1 (10.10.10.101)
│   ├── valaskjalf-master-2 (10.10.10.102)
│   └── valaskjalf-master-3 (10.10.10.103)
│       ├── etcd (3-node quorum)
│       ├── kube-apiserver (HA via VIP)
│       └── KubeVIP (manages VIP)
└── Workers
    ├── valaskjalf-worker-1 (10.10.10.111)
    ├── valaskjalf-worker-2 (10.10.10.112)
    └── valaskjalf-worker-3 (10.10.10.113)
        └── Connect to VIP (automatic failover)
```

**Key Variables:**

| Variable | Value | Description |
|----------|-------|-------------|
| `rke2_version` | v1.34.1+rke2r1 | RKE2 version |
| `rke2_cni` | cilium | CNI plugin |
| `rke2_ha_mode` | true | Enable HA mode |
| `rke2_ha_mode_kubevip` | true | Use KubeVIP for HA |
| `rke2_api_ip` | 10.10.10.100 | Virtual IP (VIP) |
| `cilium_version` | 1.18.3 | Cilium version |

**HA Configuration:**
- **Virtual IP**: 10.10.10.100 floats between masters
- **etcd Quorum**: Tolerates 1 master failure (2/3 required)
- **TLS SANs**: Includes VIP + all master IPs
- **Worker Connection**: `server: https://10.10.10.100:9345`

**Security Features:**
- Secrets encryption enabled
- Anonymous auth disabled
- Audit logging configured
- Master node taints (`NoSchedule`)

> 📁 **See**: [`ansible/install-rke2.yml`](../ansible/install-rke2.yml) for complete playbook

## Deployment

### Install Dependencies

```bash
cd ansible
ansible-galaxy install -r requirements.yml
```

### Verify Connectivity

```bash
ansible all -i inventory.yml -m ping
# Should see SUCCESS for all 6 nodes
```

### Deploy Cluster

```bash
ansible-playbook -i inventory.yml install-rke2.yml
# Takes 15-20 minutes
```

**Deployment Process:**

1. **First Master** (10.10.10.101)
   - Initialize etcd cluster
   - Deploy control plane
   - Configure KubeVIP with VIP
   
2. **Additional Masters** (10.10.10.102-103)
   - Join etcd cluster (quorum established)
   - Deploy control plane
   - KubeVIP monitors VIP

3. **Workers** (10.10.10.111-113)
   - Connect to cluster via VIP
   - Deploy kubelet and containerd

4. **Cilium CNI**
   - Install Cilium CLI
   - Deploy Cilium with VIP configuration
   - Enable Hubble observability

## Verification

### Access Cluster

```bash
# SSH to any master
ssh -p 2222 odin@10.10.10.101

# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
```

### Check Cluster Status

```bash
# Verify all nodes are Ready
kubectl get nodes -o wide

# Expected: 3 masters (control-plane,etcd,master) + 3 workers
```

### Verify KubeVIP

```bash
# Check VIP is responding
ping -c 3 10.10.10.100

# Check KubeVIP pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Test which master holds VIP
ip addr show | grep 10.10.10.100  # Run on each master
```

### Verify Cilium

```bash
# Check Cilium status
sudo cilium status

# Verify Cilium uses VIP for API
kubectl get -n kube-system configmap cilium-config -o yaml | grep k8sServiceHost
# Should show: k8sServiceHost: "10.10.10.100"

# Check Cilium pods (1 per node = 6 total)
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Optional: Run connectivity test (5-10 minutes)
sudo cilium connectivity test
```

### Test High Availability

```bash
# From local machine, configure kubectl
scp -P 2222 odin@10.10.10.101:/home/odin/.kube/config ~/.kube/config-homelab
export KUBECONFIG=~/.kube/config-homelab

# Verify server uses VIP
kubectl cluster-info
# Should show: https://10.10.10.100:6443

# Test failover:
# 1. Shut down master-1
# 2. Cluster should remain accessible via VIP
# 3. VIP automatically moves to master-2 or master-3
```

## Cilium Features

### Hubble UI (Network Observability)

```bash
# Install Cilium CLI locally
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

# Access Hubble UI
cilium hubble ui
# Opens at http://localhost:12000
```

### Network Policies

Cilium supports L3/L4/L7 policies. Example:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-to-nginx
spec:
  endpointSelector:
    matchLabels:
      app: nginx
  ingress:
    - fromEndpoints:
      - matchLabels:
          app: frontend
      toPorts:
      - ports:
        - port: "80"
          protocol: TCP
```

## Troubleshooting

### Ansible Connection Failed

```bash
# Test SSH manually
ssh -i ~/.ssh/ansible_rke2 -p 2222 odin@10.10.10.101

# Verify key is copied
ssh -i ~/.ssh/ansible_rke2 -p 2222 odin@10.10.10.101 "echo 'OK'"
```

### KubeVIP Not Working

```bash
# Check VIP assignment
for ip in 10.10.10.{101..103}; do
  echo "Master at $ip:"
  ssh -p 2222 odin@$ip "ip addr show | grep 10.10.10.100 || echo 'VIP not here'"
done

# Check KubeVIP logs
kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip
```

### Cilium Issues

```bash
# Check Cilium pods status
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# View logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium --tail=50

# Check Cilium connectivity
sudo cilium connectivity test
```

### RKE2 Service Issues

```bash
# On masters
sudo journalctl -u rke2-server -f

# On workers
sudo journalctl -u rke2-agent -f

# Check RKE2 status
sudo systemctl status rke2-server  # or rke2-agent on workers
```

## Next Steps

### 1. Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 2. Deploy Ingress Controller

```bash
# Traefik (recommended)
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n kube-system
```

### 3. Setup Storage (Longhorn)

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
```

### 4. Monitoring Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 5. GitOps with ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 6. Backup Solution (Velero)

```bash
velero install --provider aws --bucket k8s-backups --backup-location-config region=us-east-1
```

## Additional Resources

### Official Documentation

- **RKE2**: https://docs.rke2.io/
  - [Architecture](https://docs.rke2.io/architecture/architecture)
  - [Security](https://docs.rke2.io/security/hardening_guide)
  - [Configuration](https://docs.rke2.io/install/configuration)

- **Cilium**: https://docs.cilium.io/
  - [Getting Started](https://docs.cilium.io/en/stable/gettingstarted/)
  - [Network Policies](https://docs.cilium.io/en/stable/policy/)
  - [Hubble](https://docs.cilium.io/en/stable/gettingstarted/hubble/)

- **KubeVIP**: https://kube-vip.io/
  - [Documentation](https://kube-vip.io/docs/)
  - [Hybrid Mode](https://kube-vip.io/docs/about/architecture/)

- **ansible-role-rke2**:
  - [GitHub](https://github.com/lablabs/ansible-role-rke2)
  - [Ansible Galaxy](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/documentation/)

### Community

- [Rancher Users Slack](https://slack.rancher.io/)
- [Cilium Slack](https://cilium.herokuapp.com/)
- [Kubernetes Slack](https://slack.k8s.io/)
- [r/homelab](https://www.reddit.com/r/homelab/)
- [r/kubernetes](https://www.reddit.com/r/kubernetes/)

## Summary

You now have a production-ready RKE2 cluster featuring:

✅ **High Availability**: 3-master setup with Virtual IP  
✅ **Advanced Networking**: Cilium with eBPF and Hubble  
✅ **Automatic Failover**: KubeVIP manages VIP  
✅ **Security Hardening**: Encryption, taints, audit logs  
✅ **Infrastructure as Code**: Ansible automation

Ready to deploy your applications! 🎉
