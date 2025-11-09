# 🚀 RKE2 Installation with Cilium CNI using Ansible

This comprehensive tutorial guides you through installing RKE2 (Rancher Kubernetes Engine 2) on your homelab cluster with Cilium as the Container Network Interface (CNI) using Ansible automation.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Installation Steps](#installation-steps)
  - [1. Ansible Setup](#1-ansible-setup)
  - [2. Inventory Configuration](#2-inventory-configuration)
  - [3. Role Configuration](#3-role-configuration)
  - [4. Deployment](#4-deployment)
  - [5. Verification](#5-verification)
- [Cilium Configuration](#cilium-configuration)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Overview

### What is RKE2?

RKE2 (Rancher Kubernetes Engine 2) is a fully conformant Kubernetes distribution focused on security and compliance. It's particularly suitable for:

- **Government and regulated environments** - FIPS 140-2 compliance
- **Production workloads** - Battle-tested and production-ready
- **Edge computing** - Lightweight and efficient
- **Homelab clusters** - Easy to manage and maintain

### Why Cilium as CNI?

Cilium is an advanced CNI that provides:

- **eBPF-based networking** - High performance with low overhead
- **Advanced network policies** - L3-L7 security policies
- **Service mesh capabilities** - Without sidecar proxies
- **Observability** - Built-in Hubble for network visibility
- **Multi-cluster networking** - ClusterMesh support

### About ansible-role-rke2

We'll use the [`lablabs/ansible-role-rke2`](https://github.com/lablabs/ansible-role-rke2) Ansible role, which provides:

- Automated RKE2 installation and configuration
- High availability support
- Multiple CNI options (including Cilium)
- Easy customization and maintenance
- Active community support

## Prerequisites

### Infrastructure Requirements

Before starting, ensure you have:

✅ **VMs deployed** from Terraform (see [Getting Started](../GETTING-STARTED.md))
- 3x Master nodes: `10.10.10.101-103`
- 3x Worker nodes: `10.10.10.111-113`

✅ **Network access** to all nodes via SSH (port 2222)

✅ **System requirements met**:
- Ubuntu 24.04 LTS (already configured via Packer)
- Minimum 2 vCPU and 4GB RAM per master node
- Minimum 3 vCPU and 12GB RAM per worker node
- Static IP addresses configured

### Local Tools

Install the following on your **local machine** (where you'll run Ansible):

```bash
# Ansible installation (Ubuntu/Debian)
sudo apt update
sudo apt install -y ansible

# Or using pip
pip3 install ansible

# Verify installation
ansible --version  # Should be 2.12 or newer
```

### SSH Access

Ensure you can SSH to all nodes:

```bash
# Test SSH access to masters
ssh -p 2222 odin@10.10.10.101 "echo 'Master 1 OK'"
ssh -p 2222 odin@10.10.10.102 "echo 'Master 2 OK'"
ssh -p 2222 odin@10.10.10.103 "echo 'Master 3 OK'"

# Test SSH access to workers
ssh -p 2222 odin@10.10.10.111 "echo 'Worker 1 OK'"
ssh -p 2222 odin@10.10.10.112 "echo 'Worker 2 OK'"
ssh -p 2222 odin@10.10.10.113 "echo 'Worker 3 OK'"
```

> 💡 **Tip:** Configure `~/.ssh/config` for easier access (see [README](../README.md#connect-to-vms))

## Architecture

After installation, you'll have:

```
RKE2 Cluster (High Availability)
├── Control Plane (Masters)
│   ├── valaskjalf-master-1 (10.10.10.101) - First server
│   ├── valaskjalf-master-2 (10.10.10.102) - Additional server
│   └── valaskjalf-master-3 (10.10.10.103) - Additional server
│       ├── etcd cluster (distributed key-value store)
│       ├── kube-apiserver (API endpoint)
│       ├── kube-scheduler (pod scheduling)
│       └── kube-controller-manager (cluster operations)
└── Data Plane (Workers)
    ├── valaskjalf-worker-1 (10.10.10.111) - Agent
    ├── valaskjalf-worker-2 (10.10.10.112) - Agent
    └── valaskjalf-worker-3 (10.10.10.113) - Agent
        ├── kubelet (node agent)
        ├── kube-proxy (network proxy)
        └── Container runtime (containerd)

Network Layer (Cilium CNI)
├── eBPF-based networking
├── Network policies (L3/L4/L7)
├── Service mesh (optional)
└── Hubble observability (optional)
```

## Installation Steps

### 1. Ansible Setup

#### Create Ansible Project Directory

```bash
# Navigate to your homelab repository
cd /home/runner/work/homelab/homelab

# Create Ansible directory structure
mkdir -p ansible
cd ansible
```

#### Install lablabs/ansible-role-rke2

Create a `requirements.yml` file:

```bash
cat > requirements.yml << 'EOF'
---
roles:
  - name: lablabs.rke2
    src: https://github.com/lablabs/ansible-role-rke2.git
    version: v3.0.0  # Use latest stable version
EOF
```

Install the role:

```bash
ansible-galaxy install -r requirements.yml
```

This installs the role to `~/.ansible/roles/lablabs.rke2` by default.

### 2. Inventory Configuration

Create an inventory file that defines your cluster nodes:

```bash
cat > inventory.yml << 'EOF'
---
all:
  vars:
    # Common variables for all nodes
    ansible_user: odin
    ansible_port: 2222
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    # Disable host key checking for homelab (optional)
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  children:
    # RKE2 Server nodes (Control Plane)
    rke2_servers:
      hosts:
        valaskjalf-master-1:
          ansible_host: 10.10.10.101
        valaskjalf-master-2:
          ansible_host: 10.10.10.102
        valaskjalf-master-3:
          ansible_host: 10.10.10.103

    # RKE2 Agent nodes (Workers)
    rke2_agents:
      hosts:
        valaskjalf-worker-1:
          ansible_host: 10.10.10.111
        valaskjalf-worker-2:
          ansible_host: 10.10.10.112
        valaskjalf-worker-3:
          ansible_host: 10.10.10.113

    # Group all RKE2 nodes together
    rke2_cluster:
      children:
        rke2_servers:
        rke2_agents:
EOF
```

#### Verify Inventory

Test connectivity to all nodes:

```bash
# Ping all nodes
ansible all -i inventory.yml -m ping

# You should see "SUCCESS" for all 6 nodes
```

If you encounter issues, verify:
- SSH keys are properly configured
- The ansible_user can access all nodes
- Firewall rules allow SSH on port 2222

### 3. Role Configuration

Create the main playbook and configure RKE2 with Cilium:

```bash
cat > install-rke2.yml << 'EOF'
---
- name: Install RKE2 with Cilium CNI
  hosts: rke2_cluster
  become: yes
  vars:
    # RKE2 version to install
    rke2_version: v1.28.5+rke2r1  # Use latest stable RKE2 version
    
    # Disable default Canal CNI (we'll use Cilium instead)
    rke2_cni: cilium
    
    # RKE2 server (control plane) configuration
    rke2_server_config:
      # Cluster settings
      cluster-cidr: "10.42.0.0/16"      # Pod network CIDR
      service-cidr: "10.43.0.0/16"      # Service network CIDR
      cluster-dns: "10.43.0.10"         # CoreDNS service IP
      
      # Disable built-in CNI components
      disable:
        - rke2-canal
        - rke2-ingress-nginx  # We'll install our own ingress later
      
      # TLS SAN for API server (add your domain/IP)
      tls-san:
        - 10.10.10.101  # First master IP
        - 10.10.10.102  # Second master IP  
        - 10.10.10.103  # Third master IP
        - valaskjalf.local  # Optional: cluster domain name
      
      # etcd configuration for HA
      etcd-expose-metrics: false
      
      # Security settings
      secrets-encryption: true
      
      # Kube API server settings
      kube-apiserver-arg:
        - "anonymous-auth=false"
        - "audit-log-maxage=30"
      
      # Write kubeconfig with external IP
      write-kubeconfig-mode: "0644"
    
    # RKE2 agent (worker) configuration  
    rke2_agent_config:
      node-label:
        - "node-type=worker"
      
    # Download configuration
    rke2_download_dir: /usr/local/bin
    
    # Service configuration
    rke2_start_on_boot: true
    
  roles:
    - role: lablabs.rke2

  tasks:
    # Post-installation tasks
    - name: Wait for RKE2 server to be ready
      wait_for:
        port: 6443
        delay: 10
        timeout: 300
      when: inventory_hostname in groups['rke2_servers']
      
    - name: Create .kube directory for odin user
      file:
        path: /home/odin/.kube
        state: directory
        owner: odin
        group: odin
        mode: '0755'
      when: inventory_hostname == groups['rke2_servers'][0]
      
    - name: Copy kubeconfig to odin user
      copy:
        src: /etc/rancher/rke2/rke2.yaml
        dest: /home/odin/.kube/config
        owner: odin
        group: odin
        mode: '0600'
        remote_src: yes
      when: inventory_hostname == groups['rke2_servers'][0]

- name: Install Cilium CNI
  hosts: rke2_servers[0]  # Run only on first master
  become: yes
  tasks:
    - name: Wait for RKE2 to be fully ready
      wait_for:
        port: 6443
        delay: 30
        timeout: 300
        
    - name: Download Cilium CLI
      get_url:
        url: https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
        dest: /tmp/cilium-cli.tar.gz
        mode: '0644'
    
    - name: Extract Cilium CLI
      unarchive:
        src: /tmp/cilium-cli.tar.gz
        dest: /usr/local/bin
        remote_src: yes
        creates: /usr/local/bin/cilium
        
    - name: Make Cilium CLI executable
      file:
        path: /usr/local/bin/cilium
        mode: '0755'
    
    - name: Install Cilium with recommended settings
      command: >
        cilium install
        --version 1.14.5
        --set kubeProxyReplacement=strict
        --set k8sServiceHost=10.10.10.101
        --set k8sServicePort=6443
        --set operator.replicas=3
        --set ipam.mode=kubernetes
        --set tunnel=vxlan
        --set hubble.enabled=true
        --set hubble.relay.enabled=true
        --set hubble.ui.enabled=true
      environment:
        KUBECONFIG: /etc/rancher/rke2/rke2.yaml
      register: cilium_install
      changed_when: "'✅ Cilium was successfully installed' in cilium_install.stdout"
      
    - name: Wait for Cilium to be ready
      command: cilium status --wait
      environment:
        KUBECONFIG: /etc/rancher/rke2/rke2.yaml
      register: cilium_status
      retries: 30
      delay: 10
      until: cilium_status.rc == 0
      
    - name: Display Cilium status
      debug:
        var: cilium_status.stdout_lines
EOF
```

#### Configuration Breakdown

**Key Configuration Options:**

1. **CNI Selection**: `rke2_cni: cilium` - Tells the role to prepare for Cilium
2. **Network CIDRs**: 
   - `cluster-cidr`: Pod IP range (10.42.0.0/16)
   - `service-cidr`: Service IP range (10.43.0.0/16)
3. **Disabled Components**: We disable Canal (default CNI) and built-in ingress
4. **TLS SANs**: API server certificates include all master IPs
5. **Security**: Enabled secrets encryption and anonymous auth disabled

**Cilium Configuration:**

- `kubeProxyReplacement=strict`: Cilium replaces kube-proxy entirely
- `operator.replicas=3`: HA configuration for Cilium operator
- `tunnel=vxlan`: Overlay network mode (alternatives: geneve, disabled)
- `hubble.enabled=true`: Enable observability features

### 4. Deployment

Now deploy RKE2 to your cluster:

```bash
# Run the playbook (this will take 10-15 minutes)
ansible-playbook -i inventory.yml install-rke2.yml

# If you want to see detailed output:
ansible-playbook -i inventory.yml install-rke2.yml -v
```

**Deployment Process:**

1. **First Master** (valaskjalf-master-1):
   - Installs RKE2 server
   - Initializes the cluster
   - Creates etcd database
   - Starts control plane components

2. **Additional Masters** (valaskjalf-master-2, 3):
   - Join the cluster
   - Join etcd cluster (HA)
   - Start control plane components

3. **Workers** (valaskjalf-worker-1, 2, 3):
   - Install RKE2 agent
   - Join the cluster
   - Start kubelet and container runtime

4. **Cilium CNI**:
   - Install Cilium CLI
   - Deploy Cilium to cluster
   - Enable Hubble observability

**Expected Output:**

```
PLAY [Install RKE2 with Cilium CNI] *******************************************

TASK [Gathering Facts] ********************************************************
ok: [valaskjalf-master-1]
ok: [valaskjalf-master-2]
...

PLAY RECAP ********************************************************************
valaskjalf-master-1    : ok=25   changed=12   unreachable=0    failed=0
valaskjalf-master-2    : ok=23   changed=10   unreachable=0    failed=0
valaskjalf-master-3    : ok=23   changed=10   unreachable=0    failed=0
valaskjalf-worker-1    : ok=20   changed=8    unreachable=0    failed=0
valaskjalf-worker-2    : ok=20   changed=8    unreachable=0    failed=0
valaskjalf-worker-3    : ok=20   changed=8    unreachable=0    failed=0
```

### 5. Verification

#### Access Cluster from First Master

SSH to the first master node:

```bash
ssh -p 2222 odin@10.10.10.101
```

Verify RKE2 is running:

```bash
# Check RKE2 service status
sudo systemctl status rke2-server

# View RKE2 logs
sudo journalctl -u rke2-server -f
```

#### Check Cluster Status

```bash
# Set KUBECONFIG (on master node)
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Or use kubectl directly
sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes

# Check nodes are Ready
kubectl get nodes

# Expected output:
# NAME                  STATUS   ROLES                       AGE     VERSION
# valaskjalf-master-1   Ready    control-plane,etcd,master   5m      v1.28.5+rke2r1
# valaskjalf-master-2   Ready    control-plane,etcd,master   4m      v1.28.5+rke2r1
# valaskjalf-master-3   Ready    control-plane,etcd,master   4m      v1.28.5+rke2r1
# valaskjalf-worker-1   Ready    <none>                      3m      v1.28.5+rke2r1
# valaskjalf-worker-2   Ready    <none>                      3m      v1.28.5+rke2r1
# valaskjalf-worker-3   Ready    <none>                      3m      v1.28.5+rke2r1
```

#### Verify Cilium

```bash
# Check Cilium status
sudo cilium status

# Expected output:
#     /¯¯\
#  /¯¯\__/¯¯\    Cilium:             OK
#  \__/¯¯\__/    Operator:           OK
#  /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
#  \__/¯¯\__/    Hubble Relay:       OK
#     \__/       ClusterMesh:        disabled

# Check Cilium pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Expected output:
# NAME           READY   STATUS    RESTARTS   AGE
# cilium-xxxxx   1/1     Running   0          5m
# cilium-yyyyy   1/1     Running   0          5m
# cilium-zzzzz   1/1     Running   0          5m
# ...

# Run Cilium connectivity test (optional, takes 5-10 minutes)
sudo cilium connectivity test
```

#### Verify All System Pods

```bash
kubectl get pods -A

# You should see pods in:
# - kube-system (Cilium, CoreDNS, metrics-server)
# All pods should be Running or Completed
```

#### Access Cluster from Local Machine

Copy kubeconfig from master to your local machine:

```bash
# On your local machine
scp -P 2222 odin@10.10.10.101:/home/odin/.kube/config ~/.kube/config-homelab

# Or merge with existing config
export KUBECONFIG=~/.kube/config:~/.kube/config-homelab
kubectl config get-contexts

# Switch to homelab cluster
kubectl config use-context default

# Test access
kubectl get nodes
```

> 🔒 **Security Note**: The kubeconfig contains admin credentials. Keep it secure!

## Cilium Configuration

### Enable Hubble UI (Observability)

Hubble provides deep network visibility. Access the UI:

```bash
# On first master
sudo cilium hubble ui

# This opens a port-forward to the Hubble UI
# Access at: http://localhost:12000
```

To access from your local machine:

```bash
# Install Cilium CLI on local machine
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz

# Port-forward Hubble UI
cilium hubble ui
```

### Advanced Cilium Features

#### Enable Network Policies

Cilium supports advanced L3/L4/L7 network policies:

```yaml
# Example: Allow only specific traffic to nginx
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

#### Enable Cluster Mesh (Multi-cluster)

For connecting multiple Kubernetes clusters:

```bash
cilium clustermesh enable --service-type LoadBalancer
```

#### Configure BGP (Advanced)

For on-premises load balancing without MetalLB:

```bash
cilium bgp peering add --peer-asn 64512 --local-asn 64513 --peer-address 10.10.10.1
```

## Troubleshooting

### Common Issues

#### 1. Nodes Not Ready

**Symptom**: `kubectl get nodes` shows NotReady status

**Solution**:
```bash
# Check node status details
kubectl describe node valaskjalf-worker-1

# Check kubelet logs on the affected node
sudo journalctl -u rke2-agent -n 100 --no-pager

# Check Cilium connectivity
sudo cilium connectivity test
```

#### 2. Cilium Pods Crashing

**Symptom**: Cilium pods in CrashLoopBackOff

**Solution**:
```bash
# Check Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium --tail=100

# Verify kernel version (should be 4.9+)
uname -r

# Reinstall Cilium with proper settings
cilium uninstall
cilium install --version 1.14.5 --set tunnel=vxlan
```

#### 3. Unable to Pull Images

**Symptom**: Pods stuck in ImagePullBackOff

**Solution**:
```bash
# Check containerd status
sudo systemctl status rke2-server  # or rke2-agent on workers

# Check containerd logs
sudo journalctl -u rke2-server -n 100

# Verify DNS is working
kubectl run test --image=busybox --restart=Never -- nslookup kubernetes.default
```

#### 4. etcd Issues

**Symptom**: Control plane instability

**Solution**:
```bash
# Check etcd health (on master node)
sudo /var/lib/rancher/rke2/bin/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  endpoint health

# Check etcd logs
sudo journalctl -u rke2-server | grep etcd
```

#### 5. SSH Connection Issues

**Symptom**: Ansible cannot connect to nodes

**Solution**:
```bash
# Verify SSH manually
ssh -p 2222 -vvv odin@10.10.10.101

# Check SSH keys
ls -la ~/.ssh/id_rsa*

# Add SSH key to agent
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Update inventory with correct ansible_user
vim inventory.yml
```

### Logs Locations

Important log files:

```bash
# RKE2 server logs (masters)
sudo journalctl -u rke2-server -f

# RKE2 agent logs (workers)
sudo journalctl -u rke2-agent -f

# Containerd logs
sudo journalctl -u rke2-server | grep containerd

# Kubelet logs
/var/lib/rancher/rke2/agent/logs/kubelet.log

# Audit logs (if enabled)
/var/lib/rancher/rke2/server/logs/audit.log
```

### Getting Help

If you're still stuck:

1. **Check official documentation**:
   - [RKE2 Docs](https://docs.rke2.io/)
   - [Cilium Docs](https://docs.cilium.io/)
   - [ansible-role-rke2 GitHub](https://github.com/lablabs/ansible-role-rke2)

2. **Community support**:
   - [Rancher Users Slack](https://slack.rancher.io/)
   - [Cilium Slack](https://cilium.herokuapp.com/)
   - [Kubernetes Slack](https://slack.k8s.io/)

3. **Open an issue**: [homelab/issues](https://github.com/AyRickk/homelab/issues)

## Next Steps

Now that you have a running RKE2 cluster with Cilium, consider:

### 1. Install Metrics Server

For `kubectl top` commands:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 2. Install Ingress Controller

Deploy Traefik or Nginx ingress:

```bash
# Traefik (recommended for homelab)
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -n kube-system
```

### 3. Setup Storage

Install Longhorn for persistent storage:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
```

### 4. Deploy Monitoring

Install Prometheus and Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 5. Setup GitOps

Deploy ArgoCD for GitOps workflows:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 6. Configure Backup

Setup Velero for cluster backups:

```bash
# Install Velero CLI and configure S3/Minio backup
velero install --provider aws --bucket k8s-backups --backup-location-config region=us-east-1
```

## Additional Resources

### Official Documentation

- **RKE2**: https://docs.rke2.io/
  - [Architecture](https://docs.rke2.io/architecture/architecture)
  - [Security](https://docs.rke2.io/security/hardening_guide)
  - [Advanced Configuration](https://docs.rke2.io/install/configuration)

- **Cilium**: https://docs.cilium.io/
  - [Getting Started](https://docs.cilium.io/en/stable/gettingstarted/)
  - [Network Policies](https://docs.cilium.io/en/stable/policy/)
  - [Hubble Observability](https://docs.cilium.io/en/stable/gettingstarted/hubble/)

- **ansible-role-rke2**: https://github.com/lablabs/ansible-role-rke2
  - [Role Documentation](https://github.com/lablabs/ansible-role-rke2/blob/main/README.md)
  - [Examples](https://github.com/lablabs/ansible-role-rke2/tree/main/examples)

### Learning Resources

- **Kubernetes**:
  - [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
  - [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

- **Ansible**:
  - [Ansible Documentation](https://docs.ansible.com/)
  - [Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

### Video Tutorials

- [RKE2 Deep Dive - Rancher](https://www.youtube.com/watch?v=XQ4T8PbPTz0)
- [Cilium Getting Started - Isovalent](https://www.youtube.com/watch?v=80OYrzS1dCA)
- [Ansible for Kubernetes - TechWorld with Nana](https://www.youtube.com/watch?v=X48VuDVv0do)

### Homelab Inspiration

- [awesome-home-kubernetes](https://github.com/k8s-at-home/awesome-home-kubernetes)
- [r/homelab](https://www.reddit.com/r/homelab/)
- [r/kubernetes](https://www.reddit.com/r/kubernetes/)

## Conclusion

Congratulations! 🎉 You now have a production-ready RKE2 Kubernetes cluster with Cilium CNI running in your homelab.

Your cluster features:
- ✅ High availability with 3 master nodes
- ✅ 3 worker nodes for application workloads
- ✅ Advanced networking with Cilium and eBPF
- ✅ Network observability with Hubble
- ✅ Infrastructure as Code with Ansible
- ✅ Secure by default configuration

You're now ready to deploy your applications and services!

---

**Questions or improvements?** Open an issue or PR on the [homelab repository](https://github.com/AyRickk/homelab).

**Found this helpful?** ⭐ Star the repo and share with the homelab community!
