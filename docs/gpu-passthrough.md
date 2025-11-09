# 🎮 GPU Passthrough Configuration Guide

This guide covers the complete setup of GPU passthrough for the NVIDIA GeForce RTX 2080 on Proxmox VE. This configuration allows virtual machines to directly access the physical GPU for compute workloads, gaming, media transcoding, and more.

## 📋 Prerequisites

Before starting, ensure you have:

- **Hardware Requirements**:
  - Intel CPU with VT-x and VT-d support (tested with Intel Core i9-9900K)
  - NVIDIA GPU (tested with RTX 2080)
  - Motherboard with IOMMU/VT-d support
  
- **Software Requirements**:
  - Proxmox VE installed and functional (tested on version 8.x+)
  - Root access to Proxmox server
  - Ubuntu VM template created (see [Packer documentation](./packer.md))

- **Knowledge**:
  - Basic Linux command line
  - Understanding of BIOS/UEFI settings
  - Basic Terraform usage (for VM deployment)

## 🎯 Use Cases

GPU passthrough enables:

- 🤖 **AI/ML Workloads** - TensorFlow, PyTorch training with CUDA acceleration
- 🎮 **Gaming VMs** - Windows gaming VM with near-native performance (~95-99%)
- 🎬 **Media Transcoding** - Hardware-accelerated Plex, Jellyfin, Emby
- 🖥️ **Virtual Workstations** - CAD, 3D rendering (Blender, Maya), video editing
- 🔬 **CUDA Development** - GPU computing and parallel processing workloads

---

## 🔧 Part 1: BIOS Configuration

### Step 1: Access BIOS/UEFI

1. Reboot your Proxmox server
2. Press the appropriate key during boot (typically `DEL`, `F2`, or `F12`)
3. Navigate to Advanced or Virtualization settings

### Step 2: Enable Virtualization Features

Enable the following options:

- ✅ **Intel VT-x** (Intel Virtualization Technology)
- ✅ **Intel VT-d** (Intel Virtualization Technology for Directed I/O - required for IOMMU)

### Step 3: Optional but Recommended Settings

- ⚠️ **Disable CSM / Legacy Boot** - Use UEFI mode for better compatibility
- ⚠️ **Disable Resizable BAR** - Can cause issues with GPU passthrough on some systems

### Step 4: Save and Reboot

Save BIOS settings and let the system boot into Proxmox.

---

## 🐧 Part 2: Proxmox Host Configuration

### Step 1: Enable IOMMU in GRUB

Edit the GRUB configuration file:

```bash
nano /etc/default/grub
```

Modify the `GRUB_CMDLINE_LINUX_DEFAULT` line:

**For Intel CPUs (standard configuration):**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**If Proxmox is using the GPU (no integrated graphics):**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt video=efifb:off video=vesafb:off"
```

**If you have IOMMU grouping issues:**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"
```

> ⚠️ **Warning**: `pcie_acs_override` has security implications. Only use if you have IOMMU grouping problems.

Update GRUB to apply changes:

```bash
update-grub
```

### Step 2: Load VFIO Kernel Modules

Edit the modules configuration file:

```bash
nano /etc/modules
```

Add these lines:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

### Step 3: Identify Your GPU

Find the PCI address of your GPU:

```bash
lspci | grep -i nvidia
```

**Example output:**

```
01:00.0 VGA compatible controller: NVIDIA Corporation TU104 [GeForce RTX 2080] (rev a1)
01:00.1 Audio device: NVIDIA Corporation TU104 HD Audio Controller (rev a1)
01:00.2 USB controller: NVIDIA Corporation TU104 USB 3.1 Host Controller (rev a1)
01:00.3 Serial bus controller: NVIDIA Corporation TU104 USB Type-C UCSI Controller (rev a1)
```

📝 **Note the address**: `01:00` (this will be used as `0000:01:00` in Terraform)

Find the vendor:device IDs:

```bash
lspci -n -s 01:00
```

**Example output:**

```
01:00.0 0300: 10de:1e82 (rev a1)
01:00.1 0403: 10de:10f8 (rev a1)
01:00.2 0c03: 10de:1ad8 (rev a1)
01:00.3 0c80: 10de:1ad9 (rev a1)
```

📝 **Note the IDs**: `10de:1e82`, `10de:10f8`, `10de:1ad8`, `10de:1ad9`

### Step 4: Configure VFIO Driver Binding

Create the VFIO configuration file:

```bash
nano /etc/modprobe.d/vfio.conf
```

Add these lines (replace with **YOUR** IDs from the previous step):

```bash
options vfio-pci ids=10de:1e82,10de:10f8,10de:1ad8,10de:1ad9
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
softdep nvidia_drm pre: vfio-pci
softdep nvidia_modeset pre: vfio-pci
```

**Explanation:**
- `options vfio-pci ids=...` - Forces VFIO to claim these devices
- `softdep ... pre: vfio-pci` - Ensures VFIO loads before NVIDIA drivers

### Step 5: Blacklist NVIDIA Drivers (Alternative Method)

If the softdep method doesn't work, blacklist the drivers:

```bash
nano /etc/modprobe.d/blacklist.conf
```

Add:

```bash
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist nvidia_modeset
```

### Step 6: Update Initramfs and Reboot

```bash
update-initramfs -u -k all
reboot
```

---

## ✅ Part 3: Post-Reboot Verification

### Verification 1: Check IOMMU is Active

```bash
dmesg | grep -e DMAR -e IOMMU
```

**Expected output:**

```
[    0.291759] DMAR-IR: Enabled IRQ remapping in x2apic mode
[    0.621170] DMAR: Intel(R) Virtualization Technology for Directed I/O
```

✅ Look for "IOMMU enabled" or "DMAR" messages

### Verification 2: Confirm VFIO Controls the GPU

```bash
lspci -k -s 01:00
```

**Expected output:**

```
01:00.0 VGA compatible controller: NVIDIA Corporation TU104 [GeForce RTX 2080] (rev a1)
    Subsystem: NVIDIA Corporation Device 12b0
    Kernel driver in use: vfio-pci
    Kernel modules: nvidiafb, nouveau
```

✅ `Kernel driver in use: vfio-pci` should appear for all GPU components

### Verification 3: Check VFIO Modules are Loaded

```bash
lsmod | grep vfio
```

**Expected output:**

```
vfio_pci               16384  4
vfio_pci_core          86016  1 vfio_pci
vfio_iommu_type1       49152  1
vfio                   65536  11 vfio_pci_core,vfio_iommu_type1,vfio_pci
```

✅ VFIO modules should be loaded

### Verification 4: Check IOMMU Groups

Create a verification script:

```bash
nano /root/check-iommu.sh
```

Paste this content:

```bash
#!/bin/bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

Make it executable and run:

```bash
chmod +x /root/check-iommu.sh
/root/check-iommu.sh | grep -A 10 "01:00"
```

**Expected output:**

```
IOMMU Group 2:
    01:00.0 0300: 10de:1e82 [NVIDIA Corporation TU104 [GeForce RTX 2080]]
    01:00.1 0403: 10de:10f8 [NVIDIA Corporation TU104 HD Audio Controller]
    01:00.2 0c03: 10de:1ad8 [NVIDIA Corporation TU104 USB 3.1 Host Controller]
    01:00.3 0c80: 10de:1ad9 [NVIDIA Corporation TU104 USB Type-C UCSI Controller]
```

✅ Your GPU should be in its own IOMMU group (or only with its own components)

---

## 🎮 Part 4: VM Configuration with Terraform

Once the Proxmox host is configured, you can deploy a VM with GPU passthrough using Terraform.

### Example Configuration

This homelab uses **valaskjalf-worker-3** as the GPU-enabled worker node. The configuration is located in `terraform/valaskjalf-worker-3.tf`.

**Key configuration elements:**

```hcl
resource "proxmox_vm_qemu" "valaskjalf_worker_3" {
  name        = "valaskjalf-worker-3"
  vmid        = 1013
  target_node = "asgard"

  # Q35 machine type is REQUIRED for PCIe passthrough
  machine = "q35"
  
  # SeaBIOS is more stable than OVMF for GPU passthrough
  bios = "seabios"

  cpu {
    cores   = 3
    sockets = 1
    type    = "host"  # CPU passthrough for best performance
  }

  memory = 12288  # 12GB RAM

  # GPU Passthrough configuration
  pci {
    id          = 0
    raw_id      = "0000:01:00"  # Replace with YOUR PCI address
    pcie        = true
    primary_gpu = false  # Avoids x-vga errors
    rombar      = true
  }

  # Keep virtual VGA for console access
  vga {
    type = "std"
  }

  # ... rest of configuration
}
```

> 📝 **Note**: Replace `0000:01:00` with your actual GPU PCI address found in Step 3 of Part 2.

### Deploy the VM

```bash
cd terraform
terraform apply -var-file="credentials.tfvars" \
  -target=proxmox_vm_qemu.valaskjalf_worker_3
```

See the complete configuration in [`terraform/valaskjalf-worker-3.tf`](../terraform/valaskjalf-worker-3.tf) for all settings and detailed comments.

---

## 🔧 Part 5: Guest OS Configuration

### For Ubuntu/Linux VMs

After the VM boots, SSH into it:

```bash
ssh -p 2222 odin@10.10.10.113
```

#### 1. Verify GPU is Visible

```bash
lspci | grep -i nvidia
```

You should see your NVIDIA GPU listed.

#### 2. Install NVIDIA Drivers

```bash
# Update package lists
sudo apt update

# Install NVIDIA drivers automatically
sudo ubuntu-drivers install

# Reboot to load drivers
sudo reboot
```

#### 3. Verify GPU Functionality

After reboot:

```bash
# Check GPU status
nvidia-smi
```

**Expected output:**

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 535.xx.xx    Driver Version: 535.xx.xx    CUDA Version: 12.x   |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
|   0  GeForce RTX 2080    Off  | 00000000:06:00.0 Off |                  N/A |
+-----------------------------------------------------------------------------+
```

#### 4. Install CUDA Toolkit (Optional, for ML/AI workloads)

```bash
# Install CUDA toolkit
sudo apt install nvidia-cuda-toolkit

# Verify installation
nvcc --version
```

### For Windows VMs

1. Boot the Windows VM
2. Download NVIDIA drivers from [nvidia.com](https://www.nvidia.com/Download/index.aspx)
3. Install drivers and reboot
4. Verify in Device Manager that GPU is recognized

---

## 🔍 Part 6: Troubleshooting

### Problem: IOMMU Not Enabled

**Symptom:** `dmesg | grep IOMMU` returns nothing

**Solutions:**
1. Verify VT-d is enabled in BIOS
2. Check GRUB configuration: `cat /proc/cmdline`
3. Try forcing with `intel_iommu=on,igfx_off`
4. Some motherboards require specific BIOS versions for proper IOMMU support

### Problem: GPU Still Used by Proxmox

**Symptom:** `lspci -k` shows `nouveau` or `nvidia` instead of `vfio-pci`

**Solutions:**
1. Verify `/etc/modprobe.d/vfio.conf` has correct IDs
2. Ensure IDs match your GPU: `lspci -n -s 01:00`
3. Re-run: `update-initramfs -u -k all && reboot`
4. Try blacklisting drivers in `/etc/modprobe.d/blacklist.conf`
5. Check module load order: `dmesg | grep -i vfio`

### Problem: VM Won't Start - x-vga Error

**Symptom:**

```
vfio 0000:01:00.0: failed getting region info for VGA region index 8
device does not support requested feature x-vga
```

**Solution:** In Terraform configuration, ensure `primary_gpu = false`

This is the correct setting for compute workloads and is already configured in `valaskjalf-worker-3.tf`.

### Problem: IOMMU Grouping Issues

**Symptom:** GPU is grouped with other critical devices (SATA controllers, USB hubs)

**Solutions:**
1. Add `pcie_acs_override=downstream,multifunction` to GRUB (see Part 2, Step 1)
2. Check if BIOS has ACS (Access Control Services) settings
3. Consider using a different PCIe slot

⚠️ **Security Warning**: `pcie_acs_override` bypasses IOMMU isolation. Use only as last resort in homelab environments.

### Problem: Poor Performance

**Symptom:** GPU performance is significantly lower than bare metal

**Solutions:**
1. Verify CPU pinning is configured (use `type = "host"` in Terraform)
2. Ensure `machine = "q35"` is set (not i440fx)
3. Check for CPU governor: `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor`
4. Consider enabling huge pages for better memory performance
5. Verify `iothread = true` is set for storage

### Problem: Code 43 on Windows

**Symptom:** Windows shows "Code 43" error in Device Manager

**Solutions:**
1. Hide KVM from NVIDIA driver:
   ```hcl
   args = "-cpu host,kvm=off"
   ```
2. Use SeaBIOS instead of OVMF
3. Update NVIDIA drivers to latest version
4. Add GPU BIOS ROM file if needed

---

## 🎯 Pre-Deployment Checklist

Before creating a VM with GPU passthrough, verify:

- [ ] VT-d enabled in BIOS
- [ ] `dmesg | grep IOMMU` shows "IOMMU enabled"
- [ ] `lspci -k -s 01:00` shows "vfio-pci" for all GPU components
- [ ] `lsmod | grep vfio` shows VFIO modules loaded
- [ ] GPU is in an isolated IOMMU group
- [ ] You have the correct PCI address (e.g., `0000:01:00`)
- [ ] Terraform configuration uses `machine = "q35"`
- [ ] Terraform configuration uses `primary_gpu = false`
- [ ] Network connectivity to VM IP address is working

---

## 📊 Performance Expectations

With proper configuration, GPU passthrough provides:

- **Compute Performance**: 95-99% of bare-metal performance
- **Gaming Performance**: 90-95% of bare-metal performance
- **Memory Bandwidth**: Near-native (within 5%)
- **Latency**: Slightly higher than bare-metal (~1-5ms additional)

Performance loss is typically due to:
- PCIe lane configuration
- Memory management overhead
- CPU scheduling

---

## 📝 Technical Notes

### SeaBIOS vs OVMF

- **SeaBIOS (Legacy BIOS)**: More stable and simpler for GPU passthrough. Recommended for most use cases.
- **OVMF (UEFI)**: Required for Secure Boot or specific Windows features. Can have compatibility issues with some GPUs.

This homelab uses SeaBIOS for stability.

### primary_gpu Setting

- `primary_gpu = false`: Recommended setting. VM boots with virtual VGA, GPU available for compute.
  - ✅ Keeps Proxmox VNC console working
  - ✅ No x-vga errors
  - ✅ Perfect for CUDA/ML workloads
  - ❌ Physical display outputs won't work

- `primary_gpu = true`: VM uses GPU for display output.
  - ✅ Physical monitor output works
  - ❌ May cause x-vga errors on some GPUs
  - ❌ Loses Proxmox VNC console access

### VNC Console Access

With `primary_gpu = false` and `vga.type = "std"`, you maintain VNC console access through Proxmox web interface. This is valuable for:
- Initial OS installation
- Troubleshooting boot issues
- Emergency access when SSH fails

---

## 📚 References

- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Proxmox PCI(e) Passthrough Wiki](https://pve.proxmox.com/wiki/PCI(e)_Passthrough)
- [Arch Linux PCI Passthrough Guide](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Reddit r/homelab GPU Passthrough Discussions](https://www.reddit.com/r/homelab/comments/b5xpua/the_ultimate_beginners_guide_to_gpu_passthrough/)

---

## 🤝 Contributing

Have experience with GPU passthrough on similar hardware? Contributions are welcome! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

## 📌 Related Documentation

- [Infrastructure Overview](./infrastructure.md) - Hardware specifications and architecture
- [Terraform Guide](./terraform.md) - VM deployment and management
- [Getting Started](../GETTING-STARTED.md) - Initial homelab setup

---

**Last Updated**: 2025-11-09  
**Tested Configuration**: Intel i9-9900K + NVIDIA RTX 2080 + Proxmox VE 8.x + Ubuntu 24.04 LTS
