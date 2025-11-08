resource "proxmox_vm_qemu" "valaskjalf_worker_3" {
  # === Basic VM Configuration ===
  name        = "valaskjalf-worker-3"
  description = "Production rke2 worker 3, Worker Node with GPU Passthrough, Ubuntu LTS"
  vmid        = 1013
  target_node = "asgard"

  # Clone from existing template for faster deployment
  clone      = "pkr-ubuntu-noble-1"
  full_clone = true

  # === GPU Passthrough Configuration ===
  # Q35 machine type is REQUIRED for modern PCIe passthrough
  # It provides PCIe bus support instead of legacy PCI
  machine = "q35"

  # SeaBIOS (legacy BIOS) is more stable for GPU passthrough than OVMF (UEFI)
  # OVMF can cause boot issues with certain GPU configurations
  bios = "seabios"

  # Enable QEMU Guest Agent for better VM management and monitoring
  agent = 1

  # === CPU Configuration ===
  cpu {
    cores   = 3
    sockets = 1
    # "host" type passes through all host CPU features to the guest
    # This provides best performance and is required for optimal GPU usage
    type = "host"
  }

  # 12GB RAM allocation for GPU workloads
  memory = 12288

  # === Storage Configuration ===
  disks {
    virtio {
      virtio0 {
        disk {
          size    = 100
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
    bridge = "vmbr0"
  }

  # === GPU Passthrough Configuration ===
  # This passes the NVIDIA RTX 2080 GPU directly to the VM
  # Prerequisites on Proxmox host:
  # 1. IOMMU enabled in BIOS (Intel VT-d)
  # 2. GRUB configured with: intel_iommu=on iommu=pt
  # 3. VFIO modules loaded
  # 4. GPU bound to vfio-pci driver
  pci {
    id = 0
    # GPU PCI address - find with: lspci | grep -i nvidia
    # Format: 0000:01:00 will pass all functions (.0, .1, .2, .3)
    # This includes GPU, Audio, USB controllers
    raw_id = "0000:01:00"

    # Enable PCIe mode (required with q35 machine type)
    pcie = true

    # primary_gpu = false to avoid x-vga errors
    # Some modern GPUs don't support VGA arbitration in passthrough mode
    # Setting to false allows the VM to boot normally with virtual VGA for console
    # The GPU will still be fully accessible for compute workloads (CUDA, ML, etc.)
    primary_gpu = false

    # Enable ROM BAR - allows the VM to read the GPU's option ROM
    rombar = true
  }

  # Keep virtual VGA for console access
  # This allows VNC access through Proxmox web interface for debugging
  # The passed-through GPU will still be available for compute tasks
  vga {
    type = "std" # Standard VGA, can also use "virtio" for better performance
  }

  # === Additional VM Settings ===
  # VirtIO SCSI provides better performance than IDE
  scsihw = "virtio-scsi-pci"

  # Auto-start VM when Proxmox node boots
  onboot = true

  # Automatically reboot VM when configuration changes require it
  automatic_reboot = true

  # Tags for organization and filtering
  tags = "rke2,gpu"

  # === Cloud-Init Configuration ===
  os_type = "cloud-init"
  # Static IP configuration
  ipconfig0  = "ip=10.10.10.113/24,gw=10.10.10.1"
  nameserver = "10.10.10.1"

  # Default user credentials
  ciuser     = "odin"
  cipassword = var.CI_ODIN_PASSWORD
  sshkeys    = var.PUBLIC_SSH_KEY

  # Skip IPv6 if not used in your network
  skip_ipv6 = true
}

# === Post-Deployment Steps ===
# After VM is created and started:
#
# 1. SSH into the VM:
#    ssh odin@10.10.10.113
#
# 2. Verify GPU is visible:
#    lspci | grep -i nvidia
#
# 3. Install NVIDIA drivers:
#    sudo apt update
#    sudo ubuntu-drivers install
#    sudo reboot
#
# 4. Test GPU:
#    nvidia-smi
