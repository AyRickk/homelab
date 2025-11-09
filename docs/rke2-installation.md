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
ansible --version
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

### SSH Key Configuration for Ansible

**Important: Ansible Requires a Dedicated SSH Key**

Ansible needs to establish multiple SSH connections to all nodes simultaneously. **Even if you use YubiKey for manual SSH access**, you must create a separate SSH key for Ansible automation.

> 🔐 **Why?** YubiKey requires manual PIN entry and physical touch for each connection, which is incompatible with Ansible's automated workflow. The SSH agent approach doesn't work reliably with Ansible's parallel connections.

#### Create Dedicated Ansible SSH Key (Required)

Generate a standard SSH key specifically for Ansible automation:

```bash
# Generate a dedicated SSH key for Ansible
ssh-keygen -t ed25519 -f ~/.ssh/ansible_rke2 -C "ansible-automation"
```

**For YubiKey Users:** If your current SSH access uses YubiKey, configure `~/.ssh/config` with host aliases to simplify the key copying process:

```bash
# Add host entries to ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host homelab-master-1
    HostName 10.10.10.101
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib        # macOS
    PKCS11Provider /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so  # Linux

Host homelab-master-2
    HostName 10.10.10.102
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib

Host homelab-master-3
    HostName 10.10.10.103
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib

Host homelab-worker-1
    HostName 10.10.10.111
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib

Host homelab-worker-2
    HostName 10.10.10.112
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib

Host homelab-worker-3
    HostName 10.10.10.113
    Port 2222
    User odin
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
EOF

# Copy the Ansible SSH key to all nodes using YubiKey authentication
# You'll only need to enter PIN and touch YubiKey once per host
for host in homelab-master-{1..3} homelab-worker-{1..3}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub $host
done
```

**Without YubiKey:** Simply copy the key using IP addresses:

```bash
# Copy the public key to ALL nodes (masters + workers)
for ip in 10.10.10.{101..103} 10.10.10.{111..113}; do
  ssh-copy-id -i ~/.ssh/ansible_rke2.pub -p 2222 odin@$ip
done
```

The inventory is already configured to use this key (`~/.ssh/ansible_rke2`).

#### Verify SSH Access

Test that Ansible can connect to all nodes:

```bash
cd ansible

# Test connectivity to all nodes
ansible all -i inventory.yml -m ping

# You should see SUCCESS for all 6 nodes
```

#### Security Considerations

**Two keys approach (recommended):**
- **YubiKey**: Use for manual SSH access (maximum security)
- **Dedicated key**: Use only for Ansible automation (convenience)

This way you maintain strong security for interactive access while enabling automated deployments.

> 💡 **Tip:** You can restrict the dedicated Ansible key to only specific IP addresses or limit it to specific commands by configuring `authorized_keys` options on each node.

## Architecture

After installation, you'll have a **High Availability** RKE2 cluster with:

```
RKE2 HA Cluster with KubeVIP
├── Virtual IP (KubeVIP)
│   └── 10.10.10.100 - Floating IP for API access
│
├── Control Plane (3 Masters - HA)
│   ├── valaskjalf-master-1 (10.10.10.101)
│   ├── valaskjalf-master-2 (10.10.10.102)
│   └── valaskjalf-master-3 (10.10.10.103)
│       ├── etcd cluster (distributed, quorum-based)
│       ├── kube-apiserver (all respond via VIP)
│       ├── kube-scheduler (leader election)
│       ├── kube-controller-manager (leader election)
│       └── KubeVIP (manages Virtual IP failover)
│
└── Data Plane (3 Workers)
    ├── valaskjalf-worker-1 (10.10.10.111)
    ├── valaskjalf-worker-2 (10.10.10.112)
    └── valaskjalf-worker-3 (10.10.10.113)
        ├── kubelet (connects to VIP:6443)
        ├── Container runtime (containerd)
        └── Application pods

Network Layer (Cilium CNI)
├── eBPF-based networking (kube-proxy replacement)
├── Network policies (L3/L4/L7)
├── Service mesh capabilities
└── Hubble observability (network visualization)

High Availability Features
├── KubeVIP: Floating IP for API access (10.10.10.100)
├── etcd: 3-node quorum (tolerates 1 failure)
├── API Server: 3 instances (load-balanced via VIP)
└── Control Plane: Survives loss of any single master
```

**Key HA Concepts:**

- **Virtual IP (VIP)**: `10.10.10.100` floats between masters. All clients (workers, kubectl) connect to this IP.
- **Master Failure**: If one master fails, VIP automatically moves to another master. Cluster remains operational.
- **etcd Quorum**: With 3 masters, cluster tolerates 1 master failure. Need 2/3 for quorum.
- **No Single Point of Failure**: Every control plane component is redundant.

## Installation Steps

### 1. Ansible Setup

#### Create Ansible Project Directory

```bash
# Navigate to your homelab repository
cd /path/to/repository/homelab

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
    version: 1.49.0
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
# Ansible Inventory for RKE2 Cluster
# This inventory defines the structure of your Kubernetes cluster

all:
  vars:
    # Common variables for all nodes
    ansible_user: odin
    ansible_port: 2222
    
    # SSH Key Configuration
    # Use the dedicated Ansible key created earlier
    ansible_ssh_private_key_file: ~/.ssh/ansible_rke2
    
    # Disable host key checking for homelab (remove in production)
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"

  children:
    # Master nodes (Control Plane)
    # These nodes run the Kubernetes control plane components
    masters:
      hosts:
        valaskjalf-master-1:
          ansible_host: 10.10.10.101
          rke2_type: server  # IMPORTANT: Defines this as a master
        valaskjalf-master-2:
          ansible_host: 10.10.10.102
          rke2_type: server
        valaskjalf-master-3:
          ansible_host: 10.10.10.103
          rke2_type: server

    # Worker nodes
    # These nodes run application workloads
    workers:
      hosts:
        valaskjalf-worker-1:
          ansible_host: 10.10.10.111
          rke2_type: agent  # IMPORTANT: Defines this as a worker
        valaskjalf-worker-2:
          ansible_host: 10.10.10.112
          rke2_type: agent
        valaskjalf-worker-3:
          ansible_host: 10.10.10.113
          rke2_type: agent

    # Group all RKE2 nodes together
    k8s_cluster:
      children:
        masters:
        workers:
EOF
```

**Important Notes:**

- `rke2_type: server` - Marks a node as a master (control plane)
- `rke2_type: agent` - Marks a node as a worker
- `ansible_ssh_private_key_file` - Points to your dedicated Ansible key
- Group names changed from `rke2_servers/rke2_agents` to `masters/workers` for clarity

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

Create the main playbook and configure RKE2 with Cilium and KubeVIP for High Availability:

```bash
cat > install-rke2.yml << 'EOF'
---
# RKE2 Installation Playbook with Cilium CNI and KubeVIP
# This playbook installs and configures a production-ready RKE2 HA cluster

- name: Install RKE2 HA Cluster with Cilium CNI and KubeVIP
  hosts: k8s_cluster
  become: yes
  vars:
    # ===========================================
    # RKE2 Version Configuration
    # ===========================================
    rke2_version: v1.34.1+rke2r1  # Latest stable version
    
    # ===========================================
    # CNI Configuration
    # ===========================================
    rke2_cni: cilium
    
    # ===========================================
    # High Availability Configuration with KubeVIP
    # ===========================================
    rke2_ha_mode: true
    rke2_ha_mode_keepalived: false  # Disable Keepalived
    rke2_ha_mode_kubevip: true      # Enable KubeVIP
    
    # Virtual IP address for the cluster API
    # IMPORTANT: Must be an unused IP on your network
    rke2_api_ip: 10.10.10.100
    
    # KubeVIP as Cloud Provider for LoadBalancer services
    rke2_kubevip_cloud_provider_enable: true
    rke2_kubevip_svc_enable: true
    
    # IP range for LoadBalancer services (optional)
    rke2_loadbalancer_ip_range:
      range-global: 192.168.1.50-192.168.1.100
    
    # KubeVIP image version
    rke2_kubevip_image: ghcr.io/kube-vip/kube-vip:v1.0.1
    
    # Download kubeconfig to local machine
    rke2_download_kubeconf: true
    rke2_download_kubeconf_path: /tmp
    rke2_download_kubeconf_file_name: rke2-valaskjalf.yaml
    
    # ===========================================
    # RKE2 Server (Control Plane) Configuration
    # ===========================================
    rke2_server_config:
      # Network Configuration
      cluster-cidr: "10.42.0.0/16"
      service-cidr: "10.43.0.0/16"
      cluster-dns: "10.43.0.10"
      
      # Disabled Components
      disable:
        - rke2-canal
        - rke2-ingress-nginx
      
      # TLS Configuration - IMPORTANT: Include VIP
      tls-san:
        - 10.10.10.100  # Virtual IP (VIP)
        - 10.10.10.101  # Master 1
        - 10.10.10.102  # Master 2
        - 10.10.10.103  # Master 3
        - yggdrasil.dev # Optional domain
      
      # etcd Configuration
      etcd-expose-metrics: true
      
      # Security Configuration
      secrets-encryption: true
      
      # Kube API Server Arguments
      kube-apiserver-arg:
        - "anonymous-auth=false"
        - "audit-log-maxage=30"
        - "audit-log-maxbackup=10"
        - "audit-log-maxsize=100"
      
      # Kubeconfig Configuration
      write-kubeconfig-mode: "0644"
      
      # Taint masters (best practice for production)
      node-taint:
        - "node-role.kubernetes.io/control-plane=true:NoSchedule"
    
    # ===========================================
    # RKE2 Agent (Worker) Configuration
    # ===========================================
    rke2_agent_config:
      # Workers connect to VIP, not specific master
      server: "https://10.10.10.100:9345"
      
      # Labels for worker nodes
      node-label:
        - "node-type=worker"
    
    # ===========================================
    # Installation Configuration
    # ===========================================
    rke2_download_dir: /usr/local/bin
    rke2_start_on_boot: true
    rke2_data_path: /var/lib/rancher/rke2
    
  roles:
    - role: lablabs.rke2
  
  tasks:
    - name: Wait for RKE2 server to be ready
      wait_for:
        port: 6443
        host: 10.10.10.100  # Wait for VIP
        delay: 10
        timeout: 600        # KubeVIP takes longer to start
      when: inventory_hostname in groups['masters']
    
    - name: Create .kube directory for odin user
      file:
        path: /home/odin/.kube
        state: directory
        owner: odin
        group: odin
        mode: "0755"
      when: inventory_hostname == groups['masters'][0]
    
    - name: Copy kubeconfig to odin user
      copy:
        src: /etc/rancher/rke2/rke2.yaml
        dest: /home/odin/.kube/config
        owner: odin
        group: odin
        mode: "0600"
        remote_src: yes
      when: inventory_hostname == groups['masters'][0]
    
    - name: Replace localhost with VIP in kubeconfig
      replace:
        path: /home/odin/.kube/config
        regexp: "https://127.0.0.1:6443"
        replace: "https://10.10.10.100:6443"  # Use VIP
      when: inventory_hostname == groups['masters'][0]
    
    - name: Create kubectl symlink
      file:
        src: /var/lib/rancher/rke2/bin/kubectl
        dest: /usr/local/bin/kubectl
        state: link
      when: inventory_hostname == groups['masters'][0]

# ===========================================
# Cilium CNI Installation
# ===========================================
- name: Install Cilium CNI
  hosts: masters[0]
  become: yes
  vars:
    cilium_version: "1.18.3"
    cilium_cli_version: "v0.18.8"
  
  tasks:
    - name: Wait for RKE2 to be fully ready
      wait_for:
        port: 6443
        host: 10.10.10.100  # Wait for VIP
        delay: 60
        timeout: 600
    
    - name: Download Cilium CLI
      get_url:
        url: "https://github.com/cilium/cilium-cli/releases/download/{{ cilium_cli_version }}/cilium-linux-amd64.tar.gz"
        dest: /tmp/cilium-cli.tar.gz
        mode: "0644"
        timeout: 300
    
    - name: Extract Cilium CLI
      unarchive:
        src: /tmp/cilium-cli.tar.gz
        dest: /usr/local/bin
        remote_src: yes
        creates: /usr/local/bin/cilium
    
    - name: Make Cilium CLI executable
      file:
        path: /usr/local/bin/cilium
        mode: "0755"
    
    - name: Check if Cilium is already installed
      command: cilium status --wait=false
      environment:
        KUBECONFIG: /etc/rancher/rke2/rke2.yaml
      register: cilium_check
      failed_when: false
      changed_when: false
    
    - name: Install Cilium with HA and KubeVIP-compatible settings
      command: >
        cilium install
        --version {{ cilium_version }}
        --set kubeProxyReplacement=true
        --set k8sServiceHost=10.10.10.100
        --set k8sServicePort=6443
        --set operator.replicas=3
        --set ipam.mode=kubernetes
        --set tunnel=vxlan
        --set hubble.enabled=true
        --set hubble.relay.enabled=true
        --set hubble.ui.enabled=true
        --set prometheus.enabled=true
        --set operator.prometheus.enabled=true
      environment:
        KUBECONFIG: /etc/rancher/rke2/rke2.yaml
      when: cilium_check.rc != 0
    
    - name: Wait for Cilium to be ready
      command: cilium status --wait --wait-duration=10m
      environment:
        KUBECONFIG: /etc/rancher/rke2/rke2.yaml
      register: cilium_status
      retries: 5
      delay: 30
      until: cilium_status.rc == 0
    
    - name: Display cluster information
      debug:
        msg:
          - "=============================================="
          - "🎉 RKE2 HA Cluster Ready!"
          - "=============================================="
          - "Virtual IP: 10.10.10.100"
          - "Access: kubectl --server=https://10.10.10.100:6443"
          - "=============================================="
EOF
```

#### Configuration Breakdown

**High Availability (KubeVIP):**

1. **Virtual IP (VIP)**: `10.10.10.100` - Floating IP for API access
   - All clients connect to this IP
   - Automatically fails over if a master goes down
   - Must be an unused IP on your network

2. **HA Mode**: 
   - `rke2_ha_mode: true` - Enables HA
   - `rke2_ha_mode_kubevip: true` - Uses KubeVIP (not Keepalived)
   - `rke2_api_ip` - The VIP address

3. **TLS SANs**: Must include VIP + all master IPs

**CNI Configuration:**

- `rke2_cni: cilium` - Use Cilium instead of Canal
- Cilium configured to use VIP (`k8sServiceHost: 10.10.10.100`)
- eBPF-based networking with kube-proxy replacement
- Hubble for observability

**Worker Configuration:**

- `server: "https://10.10.10.100:9345"` - Workers connect to VIP
- This ensures workers stay connected even if a master fails

**Node Taints:**

- Masters are tainted with `NoSchedule`
- Prevents user pods from running on control plane
- Best practice for production

### 4. Deployment

Deploy RKE2 to your cluster:

```bash
# Run the playbook (this will take 15-20 minutes)
ansible-playbook -i inventory.yml install-rke2.yml

# With verbose output to see progress:
ansible-playbook -i inventory.yml install-rke2.yml -v
```

**Deployment Process:**

1. **First Master** (valaskjalf-master-1):
   - Installs RKE2 server
   - Initializes etcd cluster
   - Starts control plane components
   - Deploys KubeVIP (VIP: 10.10.10.100)

2. **Additional Masters** (valaskjalf-master-2, 3):
   - Join etcd cluster (quorum established with 3 nodes)
   - Start control plane components
   - KubeVIP monitors VIP on all masters

3. **Workers** (valaskjalf-worker-1, 2, 3):
   - Install RKE2 agent
   - Connect to cluster via VIP (10.10.10.100)
   - Start kubelet and container runtime

4. **Cilium CNI**:
   - Install Cilium CLI
   - Deploy Cilium to cluster (configured for VIP)
   - Enable Hubble observability
   - Wait for network to be ready

**Testing High Availability:**

After deployment, you can test HA:

```bash
# Check all nodes are ready
kubectl get nodes -o wide

# Test VIP failover:
# 1. Shut down master-1
# 2. Cluster should remain accessible via VIP
# 3. VIP automatically moves to another master
```

### 5. Verification

#### Access Cluster via Virtual IP

The cluster is now accessible via the Virtual IP (10.10.10.100). You can connect from any master node or your local machine.

**From a Master Node:**

```bash
# SSH to any master (they all have access)
ssh -p 2222 odin@10.10.10.101

# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Or create symlink for kubectl
sudo ln -sf /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
```

#### Check Cluster Status

```bash
# Check all nodes
kubectl get nodes -o wide

# Expected output:
# NAME                  STATUS   ROLES                       AGE   VERSION
# valaskjalf-master-1   Ready    control-plane,etcd,master   5m    v1.34.1+rke2r1
# valaskjalf-master-2   Ready    control-plane,etcd,master   4m    v1.34.1+rke2r1
# valaskjalf-master-3   Ready    control-plane,etcd,master   4m    v1.34.1+rke2r1
# valaskjalf-worker-1   Ready    <none>                      3m    v1.34.1+rke2r1
# valaskjalf-worker-2   Ready    <none>                      3m    v1.34.1+rke2r1
# valaskjalf-worker-3   Ready    <none>                      3m    v1.34.1+rke2r1

# Verify masters have the control-plane taint
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Check all system pods
kubectl get pods -A
```

#### Verify KubeVIP

```bash
# Check KubeVIP is running on all masters
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Verify the VIP is active
ping -c 3 10.10.10.100

# Check which master currently holds the VIP
ip addr show | grep 10.10.10.100  # Run on each master
```

#### Verify Cilium

```bash
# Check Cilium status
sudo cilium status

# Expected output:
#     /¯¯\
#  /¯¯\__/¯¯\    Cilium:             OK
#  \__/¯¯\__/    Operator:           OK
#  /¯¯\__/¯¯\    Hubble Relay:       OK
#  \__/¯¯\__/    ClusterMesh:        disabled
#     \__/

# Check Cilium pods (should have 1 per node)
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Expected: 6 Cilium pods (1 per node)

# Verify Cilium is using VIP for API access
kubectl get -n kube-system configmap cilium-config -o yaml | grep k8sServiceHost
# Should show: k8sServiceHost: "10.10.10.100"

# Run Cilium connectivity test (optional, takes 5-10 minutes)
sudo cilium connectivity test
```

#### Access Cluster from Local Machine

The playbook automatically downloaded a kubeconfig file to `/tmp/rke2-valaskjalf.yaml` on your local machine. Use this to access the cluster:

```bash
# Copy the downloaded kubeconfig to your kubectl config location
cp /tmp/rke2-valaskjalf.yaml ~/.kube/config-valaskjalf

# Or manually copy from first master
scp -P 2222 odin@10.10.10.101:/home/odin/.kube/config ~/.kube/config-valaskjalf

# Verify the server URL uses the VIP
grep server ~/.kube/config-valaskjalf
# Should show: server: https://10.10.10.100:6443

# Set KUBECONFIG to use this cluster
export KUBECONFIG=~/.kube/config-valaskjalf

# Or merge with your existing kubeconfig
export KUBECONFIG=~/.kube/config:~/.kube/config-valaskjalf
kubectl config get-contexts

# Switch to the cluster
kubectl config use-context default

# Test access via VIP
kubectl get nodes -o wide
```

**Testing HA from Local Machine:**

Your local kubectl is configured to use the VIP (10.10.10.100), so:

```bash
# This command uses the VIP
kubectl get nodes

# Even if master-1 goes down, this continues to work
# because the VIP fails over to another master automatically
```

> 🔒 **Security Note**: The kubeconfig contains admin credentials. Keep it secure!

## Cilium Configuration

### Enable Hubble UI (Observability)

Hubble is already enabled. Access the UI:

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
   - [ansible-role-rke2 Galaxy Documentation](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/documentation/)
   - [ansible-role-rke2 Installation Guide](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/install/)

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

- **ansible-role-rke2**: 
  - [GitHub Repository](https://github.com/lablabs/ansible-role-rke2)
  - [Ansible Galaxy Documentation](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/documentation/)
  - [Ansible Galaxy Install Guide](https://galaxy.ansible.com/ui/standalone/roles/lablabs/rke2/install/)
  - [Role README](https://github.com/lablabs/ansible-role-rke2/blob/main/README.md)
  - [Configuration Examples](https://github.com/lablabs/ansible-role-rke2/tree/main/examples)

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
