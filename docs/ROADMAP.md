# 📚 Documentation Roadmap

This document tracks planned documentation additions and improvements as the homelab evolves.

## Current Status

✅ **Completed Documentation**:
- Infrastructure overview with hardware specifications
- Packer VM template creation
- Terraform infrastructure deployment
- Getting started guide
- YubiKey SSH authentication setup
- Contributing guidelines
- **GPU Passthrough configuration** (NVIDIA RTX 2080)
- **RKE2 Cluster Setup with Cilium CNI** - Complete Ansible-based installation guide

## Planned Documentation

### High Priority

#### 📊 Monitoring and Observability
**Status**: Planned  
**Topics to cover**:
- Prometheus deployment and configuration
- Grafana dashboards
- AlertManager setup
- Log aggregation (Loki or ELK)
- Node and pod metrics
- Custom alerts and notifications

### Medium Priority

#### 📦 Storage Solutions
**Status**: Planned  
**Topics to cover**:
- Longhorn distributed storage setup
- NFS persistent volumes
- Storage classes configuration
- Backup strategies for persistent data
- Performance optimization

#### 🔄 GitOps with ArgoCD
**Status**: Planned  
**Topics to cover**:
- ArgoCD installation
- Repository structure
- Application deployment patterns
- Auto-sync vs manual sync
- Secrets management in GitOps
- Multi-environment setup

#### 🌐 Ingress and Load Balancing
**Status**: Planned  
**Topics to cover**:
- MetalLB for LoadBalancer services
- Traefik or Nginx Ingress Controller
- TLS/SSL certificate automation
- External DNS integration
- Custom domain configuration

### Lower Priority

#### 🤖 CI/CD Pipelines
**Status**: Planned  
**Topics to cover**:
- GitLab Runner or GitHub Actions setup
- Container building and pushing
- Automated testing
- Deployment automation
- Infrastructure validation

#### 🌊 Service Mesh (Optional)
**Status**: Planned  
**Topics to cover**:
- Istio or Linkerd installation
- Traffic management
- Service-to-service security
- Observability improvements
- When to use vs when to skip

#### 🏠 Homelab Services
**Status**: Planned  
**Individual guides for**:
- Media server (Plex/Jellyfin with GPU transcoding)
- Home automation (Home Assistant)
- Network services (Pi-hole, DNS)
- File sharing (Nextcloud, Syncthing)
- Reverse proxy (Traefik, Nginx Proxy Manager)
- VPN (WireGuard, Tailscale)
- Password manager (Vaultwarden)
- And more...

#### 🔧 Advanced Topics
**Status**: Planned  
**Topics to cover**:
- Multi-cluster federation
- Disaster recovery procedures
- Infrastructure cost optimization
- Performance benchmarking
- Migration strategies
- Upgrading major versions

## Community Requests

This section will track documentation requested by the community via Issues or Discussions.

_No requests yet - open an issue to suggest topics!_

## Contributing to Documentation

Want to help write documentation? See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

Priority topics to contribute:
- Service-specific guides
- Troubleshooting sections
- Performance optimization tips

## Documentation Standards

All documentation should:
- Be written in English
- Include practical examples
- Provide step-by-step instructions
- Explain the "why" not just the "how"
- Include troubleshooting sections
- Be tested before publishing
- Include references/links to official docs

## Updates

This roadmap will be updated as:
- New documentation is published
- Priorities change based on project needs
- Community requests are received
- New technologies are adopted

---

**Last Updated**: 2025-11-09  
**Current Documentation Status**: Foundation complete, actively expanding
