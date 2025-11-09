# 🎮 GPU Passthrough Guide

> 🚧 **Work in Progress**: This documentation is planned for future release.

## Overview

This guide will cover how to configure GPU passthrough for the NVIDIA GeForce RTX 2080 on the Proxmox homelab setup.

## Hardware

- **GPU**: NVIDIA GeForce RTX 2080
- **CPU**: Intel Core i9-9900K (supports VT-d for IOMMU)
- **Motherboard**: Must support IOMMU/VT-d

## Use Cases

GPU passthrough enables:

- 🤖 **AI/ML Workloads** - TensorFlow, PyTorch training in VMs
- 🎮 **Gaming VMs** - Windows gaming VM with near-native performance
- 🎬 **Media Transcoding** - Hardware-accelerated Plex, Jellyfin
- 🖥️ **Virtual Workstations** - CAD, 3D rendering, video editing
- 🔬 **CUDA Development** - GPU computing and parallel processing

## Prerequisites

- Proxmox VE 8.x or newer
- CPU with IOMMU support (Intel VT-d or AMD-Vi)
- IOMMU enabled in BIOS
- GPU in appropriate PCIe slot
- Dedicated GPU for Proxmox host (or use integrated graphics)

## Topics to be Covered

### 1. BIOS Configuration
- Enable Intel VT-d (IOMMU)
- Configure PCIe settings
- Primary display adapter selection

### 2. Proxmox Host Configuration
- Enable IOMMU in GRUB
- Load VFIO modules
- Blacklist nouveau driver
- Verify IOMMU groups

### 3. VM Configuration
- PCIe passthrough setup
- ROM file configuration (if needed)
- CPU pinning for performance
- Huge pages configuration

### 4. Guest OS Setup
- **Windows**: NVIDIA driver installation
- **Linux**: Driver installation and configuration
- Performance tuning

### 5. Troubleshooting
- Common issues and solutions
- Error code reference
- Performance optimization

## Coming Soon

Detailed step-by-step instructions will be added as this homelab setup evolves. Check back for updates!

## References

- [Proxmox GPU Passthrough Documentation](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [NVIDIA GPU Passthrough Guide](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Reddit r/homelab GPU Passthrough Discussions](https://www.reddit.com/r/homelab/)

## Contributing

If you have experience with GPU passthrough on similar hardware, contributions to this guide are welcome!
