resource "proxmox_vm_qemu" "valaskjalf_worker_1" {
  # === Basic VM Configuration ===
  name        = "valaskjalf-worker-1"
  description = "Production rke2 worker 1, Worker Node, Ubuntu LTS"
  vmid        = 1011
  target_node = "asgard"

  # Clone from existing Ubuntu template for faster deployment
  clone      = "pkr-ubuntu-noble-1"
  full_clone = true

  # Enable QEMU Guest Agent for better VM management and monitoring
  agent = 1

  # === CPU Configuration ===
  cpu {
    cores   = 3
    sockets = 1
    # "host" type passes through all host CPU features to the guest
    # Provides best performance for virtualized workloads
    type = "host"
  }

  # Memory allocation: 12GB RAM
  memory = 12288

  # === Storage Configuration ===
  disks {
    virtio {
      virtio0 {
        disk {
          size    = 100 # 100GB root disk
          storage = "local-zfs"
          # iothread improves disk I/O performance by using dedicated threads
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
  scsihw = "virtio-scsi-pci"

  # SeaBIOS (legacy BIOS) for compatibility with the cloned template
  bios = "seabios"

  # === Boot Configuration ===
  # Auto-start VM when Proxmox node boots
  onboot = true

  # Automatically reboot VM when configuration changes require it
  automatic_reboot = true

  # Tags for organization and filtering in Proxmox
  tags = "rke2"

  # === Cloud-Init Configuration ===
  # Use cloud-init for automated VM provisioning
  os_type = "cloud-init"

  # Static IP configuration: 10.10.10.111/24 with gateway 10.10.10.1
  ipconfig0  = "ip=10.10.10.111/24,gw=10.10.10.1"
  nameserver = "10.10.10.1"

  # Default user credentials for SSH access
  ciuser     = "odin"
  cipassword = var.CI_ODIN_PASSWORD

  # SSH public keys for passwordless authentication
  sshkeys = var.PUBLIC_SSH_KEY
}
