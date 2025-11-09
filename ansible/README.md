# Ansible Configuration for RKE2

This directory contains Ansible automation for deploying a High Availability RKE2 cluster with Cilium CNI and KubeVIP to your homelab.

## 📋 Files

- **`requirements.yml`** - Ansible Galaxy dependencies (lablabs/ansible-role-rke2 v1.49.0)
- **`inventory.yml`** - Cluster node inventory (3 masters + 3 workers)
- **`install-rke2.yml`** - Main playbook for RKE2 + Cilium + KubeVIP installation

## 🚀 Quick Start

### 1. Create Dedicated SSH Key for Ansible

**Important:** Even if you use YubiKey for manual SSH, you need a dedicated key for Ansible automation.

```bash
# Generate dedicated Ansible SSH key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_rke2 -C "ansible-automation"
```

**For YubiKey Users:** If your current SSH access uses YubiKey, configure `~/.ssh/config` with host aliases to simplify the key copying process:

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host homelab-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so  # Linux
    # PKCS11Provider /opt/homebrew/lib/libykcs11.dylib        # macOS

Host homelab-master-2
    HostName 10.10.10.102
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

Host homelab-master-3
    HostName 10.10.10.103
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

Host homelab-worker-1
    HostName 10.10.10.111
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

Host homelab-worker-2
    HostName 10.10.10.112
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

Host homelab-worker-3
    HostName 10.10.10.113
    Port 2222
    User odin
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
EOF

# Now copy the Ansible SSH key to all nodes using YubiKey authentication
# You'll only need to enter PIN and touch YubiKey once per host
for host in homelab-master-{1..3} homelab-worker-{1..3}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub $host
done
```

**Without YubiKey:** Simply copy the key using IP addresses:

```bash
# Copy to all nodes directly
for ip in 10.10.10.{101..103} 10.10.10.{111..113}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub -p 2222 odin@$ip
done
```

### 2. Install Ansible

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Or using pip
pip3 install ansible
```

### 3. Install Required Roles

```bash
cd ansible
ansible-galaxy install -r requirements.yml
```

### 4. Verify Connectivity

```bash
# Test SSH access to all nodes
ansible all -i inventory.yml -m ping

# You should see SUCCESS for all 6 nodes
```

### 5. Deploy RKE2 HA Cluster

```bash
# Run the playbook (takes 15-20 minutes)
ansible-playbook -i inventory.yml install-rke2.yml

# With verbose output
ansible-playbook -i inventory.yml install-rke2.yml -v
```

## 📖 Full Documentation

For complete setup instructions, configuration options, and troubleshooting:

👉 **[docs/rke2-installation.md](../docs/rke2-installation.md)**

## ⚙️ Key Features

### High Availability with KubeVIP

- **Virtual IP (VIP)**: 10.10.10.100 - Floating IP for API access
- **3 Master Nodes**: Quorum-based etcd cluster
- **Automatic Failover**: VIP moves to healthy master if one fails
- **Zero Downtime**: Cluster survives loss of any single master

### Advanced Networking with Cilium

- **eBPF-based**: High-performance networking
- **kube-proxy Replacement**: Cilium handles all networking
- **Hubble Observability**: Network visualization and monitoring
- **3 Operator Replicas**: HA Cilium operator

### Production-Ready Configuration

- **Master Taints**: Prevents user pods on control plane
- **etcd Metrics**: Enabled for monitoring
- **Secrets Encryption**: At-rest encryption enabled
- **Security Hardening**: Anonymous auth disabled, audit logs enabled

## ⚙️ Customization

### Change Virtual IP (VIP)

Edit `install-rke2.yml`:

```yaml
rke2_api_ip: 10.10.10.100  # Change to an unused IP on your network
```

Also update in `tls-san` and `server` sections.

### Change Network Configuration

Edit `inventory.yml` to match your network:

```yaml
masters:
  hosts:
    valaskjalf-master-1:
      ansible_host: YOUR_IP_HERE  # Change to your IP
      rke2_type: server
```

### Modify RKE2 Configuration

Edit `install-rke2.yml` to customize:

- RKE2 version (`rke2_version`)
- Cilium version (`cilium_version`)
- Network CIDRs (pod/service networks)
- LoadBalancer IP range
- Security settings

### Add More Nodes

Add nodes to `inventory.yml`:

```yaml
workers:
  hosts:
    valaskjalf-worker-4:
      ansible_host: 10.10.10.114
      rke2_type: agent
```

Then re-run the playbook.

## 🔍 Verification

After deployment, verify your cluster:

```bash
# SSH to any master
ssh -p 2222 odin@10.10.10.101

# Check cluster status (via VIP)
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes -o wide

# Check KubeVIP
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Check Cilium status
sudo cilium status

# Test VIP failover
ping 10.10.10.100  # Should always respond
# Shutdown master-1, VIP should move to another master
```

## 🛠️ Troubleshooting

### SSH Key Issues

```bash
# Verify dedicated Ansible key exists
ls -la ~/.ssh/ansible_rke2*

# Test manual SSH with the key
ssh -i ~/.ssh/ansible_rke2 -p 2222 odin@10.10.10.101

# Re-copy key if needed
ssh-copy-id -i ~/.ssh/ansible_rke2.pub -p 2222 odin@10.10.10.101
```

### Ansible Connection Fails

```bash
# Test connectivity
ansible all -i inventory.yml -m ping

# Check inventory file has correct SSH key path
grep ansible_ssh_private_key_file inventory.yml
```

### RKE2 Installation Fails

```bash
# Check logs on affected node
sudo journalctl -u rke2-server -f  # or rke2-agent on workers
```

### KubeVIP Not Working

```bash
# Check VIP is assigned
ip addr show | grep 10.10.10.100  # Run on each master

# Check KubeVIP pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# View KubeVIP logs
kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip
```

### Cilium Not Working

```bash
# Check Cilium pods (should be 6 total)
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# View Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium --tail=50

# Verify Cilium is using VIP
kubectl get -n kube-system configmap cilium-config -o yaml | grep k8sServiceHost
```

See [full troubleshooting guide](../docs/rke2-installation.md#troubleshooting) for more solutions.

## 📚 Additional Resources

- [RKE2 Documentation](https://docs.rke2.io/)
- [Cilium Documentation](https://docs.cilium.io/)
- [KubeVIP Documentation](https://kube-vip.io/)
- [ansible-role-rke2 GitHub](https://github.com/lablabs/ansible-role-rke2)
- [Ansible Documentation](https://docs.ansible.com/)

## 🤝 Contributing

Found an issue or have an improvement? Open an issue or PR!

---

**Next Steps**: After installation, check out:
- [Deploying applications](../docs/rke2-installation.md#next-steps)
- [Setting up monitoring](../docs/rke2-installation.md#4-deploy-monitoring)
- [Configuring storage](../docs/rke2-installation.md#3-setup-storage)
