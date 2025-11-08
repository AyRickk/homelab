source "proxmox-iso" "pkr-ubuntu-noble-1" {
  proxmox_url               = "${var.proxmox_api_url}"
  username                  = "${var.proxmox_api_token_id}"
  token                     = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify  = true

  node                      = "asgard"
  vm_id                     = "90001"
  vm_name                   = "pkr-ubuntu-noble-1"
  template_description      = "Ubuntu 24.04 LTS"

  boot_iso {
    type                    = "scsi"
    iso_file                = "local:iso/ubuntu-24.04.3-live-server-amd64.iso"
    iso_storage_pool        = "local"
    unmount                 = true
  }

  qemu_agent                = true
  scsi_controller           = "virtio-scsi-pci"
  cores                     = "1"
  sockets                   = "1"
  memory                    = "2048"

  cloud_init                = true
  cloud_init_storage_pool   = "local-zfs"

  vga {
    type                    = "virtio"
  }

  disks {
    disk_size               = "20G"
    format                  = "raw"
    storage_pool            = "local-zfs"
    type                    = "virtio"
  }

  network_adapters {
    model                   = "virtio"
    bridge                  = "vmbr0"
    firewall                = "false"
  }

  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  
  boot                      = "c"
  boot_wait                 = "6s"
  communicator              = "ssh"
  http_directory            = "http"
  ssh_username              = "${var.ssh_username}"
  ssh_password              = "${var.ssh_password}"
  ssh_timeout               = "30m"
  ssh_pty                   = true
  ssh_handshake_attempts    = 15
}

build {

  name    = "pkr-ubuntu-noble-1"
  sources = [
      "proxmox-iso.pkr-ubuntu-noble-1"
  ]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
  provisioner "shell" {
      inline = [
          "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
          "sudo rm /etc/ssh/ssh_host_*",
          "sudo truncate -s 0 /etc/machine-id",
          "sudo apt -y autoremove --purge",
          "sudo apt -y clean",
          "sudo apt -y autoclean",
          "sudo cloud-init clean",
          "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
          "sudo rm -f /etc/netplan/00-installer-config.yaml",
          "sudo sync"
      ]
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }
  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }

  provisioner "shell" {
    inline = [
      
      "# Replace all keys by public_key",
      "echo '${var.public_key}' > ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys",
      
      "# Verify that key is here",
      "echo 'Key installed :'",
      "cat ~/.ssh/authorized_keys",
      
      "# SSH Hardening",
      "sudo tee /etc/ssh/sshd_config.d/99-security.conf > /dev/null <<'EOF'",
      "# SSH Security - PublicKey authentication only",
      "Port 2222",
      "PasswordAuthentication no",
      "PubkeyAuthentication yes",
      "PermitRootLogin no",
      "ChallengeResponseAuthentication no",
      "KbdInteractiveAuthentication no",
      "UsePAM yes",
      "AuthenticationMethods publickey",
      "EOF",
      
      "# Test configuration",
      "sudo sshd -t && echo 'Valid SSH configuration !' || echo 'SSH config error'",
      
      "echo '=== Configuration over ==='"
    ]
  }
}
