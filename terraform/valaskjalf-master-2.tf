resource "proxmox_vm_qemu" "valaskjalf_master_2" {
  # === Basic VM Configuration ===
  name        = "valaskjalf-master-2"
  description = "Production rke2 master 2, Master Node, Ubuntu LTS"
  vmid        = 1002
  target_node = "asgard"

  # Clone from existing Ubuntu template for faster deployment
  clone      = "pkr-ubuntu-noble-1"
  full_clone = true

  # Enable QEMU Guest Agent for better VM management and monitoring
  agent = 1

  # === CPU Configuration ===
  cpu {
    cores   = 2 # Master nodes need less CPU than workers
    sockets = 1
    # "host" type passes through all host CPU features to the guest
    # Provides best performance for Kubernetes control plane components
    type = "host"
  }

  # Memory allocation: 4GB RAM
  # Master nodes run etcd, kube-apiserver, kube-scheduler, kube-controller-manager
  # 4GB is sufficient for small to medium clusters
  memory = 4096

  # === Storage Configuration ===
  disks {
    virtio {
      virtio0 {
        disk {
          size    = 50 # 50GB root disk - masters need less storage than workers
          storage = "local-zfs"
          # iothread improves disk I/O performance, critical for etcd
          iothread = true
        }
      }
    }
    # Cloud-init configuration disk on IDE bus
    ide {
      ide2 {
        cloudinit {
          storage = "local-zfs"
        }
      }
    }
  }

  # === Network Configuration ===
  network {
    id     = 0
    model  = "virtio" # VirtIO provides best network performance in VMs
    bridge = "vmbr0"  # Default Proxmox bridge
  }

  # === System Settings ===
  # VirtIO SCSI controller provides better performance than IDE
  # Important for etcd's disk I/O requirements
  scsihw = "virtio-scsi-pci"

  # SeaBIOS (legacy BIOS) for compatibility with the cloned template
  bios = "seabios"

  # === Boot Configuration ===
  # Auto-start VM when Proxmox node boots
  # Critical for master nodes to ensure cluster availability
  onboot = true

  # Automatically reboot VM when configuration changes require it
  automatic_reboot = true

  # Tags for organization and filtering in Proxmox
  tags = "rke2"

  # === Cloud-Init Configuration ===
  # Use cloud-init for automated VM provisioning
  os_type = "cloud-init"

  # Static IP configuration: 10.10.10.102/24 with gateway 10.10.10.1
  # Master nodes should always have static IPs for cluster stability
  ipconfig0  = "ip=10.10.10.102/24,gw=10.10.10.1"
  nameserver = "10.10.10.1"

  # Default user credentials for SSH access
  ciuser     = "odin"
  cipassword = var.CI_ODIN_PASSWORD

  # SSH public keys for passwordless authentication
  sshkeys = var.PUBLIC_SSH_KEY
}
