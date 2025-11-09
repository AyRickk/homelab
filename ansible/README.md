# Ansible Configuration for RKE2

This directory contains Ansible automation for deploying RKE2 with Cilium CNI to your homelab cluster.

## 📋 Files

- **`requirements.yml`** - Ansible Galaxy dependencies (lablabs/ansible-role-rke2)
- **`inventory.yml`** - Cluster node inventory (masters and workers)
- **`install-rke2.yml`** - Main playbook for RKE2 + Cilium installation

## 🚀 Quick Start

### 1. Install Ansible

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Or using pip
pip3 install ansible
```

### 2. Install Required Roles

```bash
cd ansible
ansible-galaxy install -r requirements.yml
```

### 3. Verify Connectivity

```bash
# Test SSH access to all nodes
ansible all -i inventory.yml -m ping
```

**Note for YubiKey Users:** If you use YubiKey for SSH authentication, see the [YubiKey and Ansible Compatibility](../docs/rke2-installation.md#yubikey-and-ansible-compatibility) section in the full documentation for two approaches to handle PIN/touch requirements during Ansible automation.

### 4. Deploy RKE2

```bash
# Run the playbook
ansible-playbook -i inventory.yml install-rke2.yml

# With verbose output
ansible-playbook -i inventory.yml install-rke2.yml -v
```

## 📖 Full Documentation

For complete setup instructions, configuration options, and troubleshooting:

👉 **[docs/rke2-installation.md](../docs/rke2-installation.md)**

## ⚙️ Customization

### Change Network Configuration

Edit `inventory.yml` to match your network:

```yaml
rke2_servers:
  hosts:
    valaskjalf-master-1:
      ansible_host: YOUR_IP_HERE  # Change to your IP
```

### Modify RKE2 Configuration

Edit `install-rke2.yml` to customize:

- RKE2 version
- Network CIDRs (pod/service networks)
- Cilium features (Hubble, monitoring, etc.)
- Security settings
- Resource allocations

### Add More Nodes

Add nodes to `inventory.yml`:

```yaml
rke2_agents:
  hosts:
    valaskjalf-worker-4:
      ansible_host: 10.10.10.114
```

Then re-run the playbook.

## 🔍 Verification

After deployment, verify your cluster:

```bash
# SSH to first master
ssh -p 2222 odin@10.10.10.101

# Check cluster status
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes

# Check Cilium status
sudo cilium status

# Run connectivity test
sudo cilium connectivity test
```

## 🛠️ Troubleshooting

### Common Issues

**Ansible connection fails:**
```bash
# Test SSH manually
ssh -p 2222 odin@10.10.10.101

# Check SSH keys
ls -la ~/.ssh/id_rsa*
```

**RKE2 installation fails:**
```bash
# Check logs on affected node
sudo journalctl -u rke2-server -f  # or rke2-agent
```

**Cilium not working:**
```bash
# Check Cilium pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# View Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium --tail=50
```

See [full troubleshooting guide](../docs/rke2-installation.md#troubleshooting) for more solutions.

## 📚 Additional Resources

- [RKE2 Documentation](https://docs.rke2.io/)
- [Cilium Documentation](https://docs.cilium.io/)
- [ansible-role-rke2 GitHub](https://github.com/lablabs/ansible-role-rke2)
- [Ansible Documentation](https://docs.ansible.com/)

## 🤝 Contributing

Found an issue or have an improvement? Open an issue or PR!

---

**Next Steps**: After installation, check out:
- [Deploying applications](../docs/rke2-installation.md#next-steps)
- [Setting up monitoring](../docs/rke2-installation.md#2-deploy-monitoring)
- [Configuring storage](../docs/rke2-installation.md#3-setup-storage)
