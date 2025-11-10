# Helm Charts Configuration

## Overview

This directory contains Helm chart configurations for deploying applications and services to your RKE2 Kubernetes cluster. All configurations use `values.yaml` files for customization while leveraging official Helm charts.

## Directory Structure

```
helm/
├── README.md                           # This file
├── traefik/                            # Traefik ingress controller
│   ├── README.md                       # Traefik setup guide
│   ├── values.yaml                     # Traefik configuration
│   └── nginx-test.yaml                 # Example application with TLS
├── cert-manager/                       # Certificate management
│   ├── README.md                       # cert-manager guide
│   └── values.yaml                     # cert-manager configuration
└── cert-manager-ovh-webhook/          # OVH DNS webhook for cert-manager
    ├── README.md                       # OVH webhook guide
    └── values.yaml                     # Webhook and ClusterIssuer config
```

## Installed Components

### Traefik Ingress Controller

**Purpose**: Routes external HTTP/HTTPS traffic to services in the cluster

**Features:**
- Automatic HTTP to HTTPS redirect
- Native Kubernetes integration with CRDs
- Dynamic service discovery
- Built-in dashboard (optional)
- Modern protocol support (HTTP/2, HTTP/3, gRPC)

**Quick Install:**
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -f traefik/values.yaml \
  -n traefik --create-namespace
```

📖 **Full guide**: [traefik/README.md](./traefik/README.md)

### cert-manager

**Purpose**: Automates TLS certificate issuance and renewal

**Features:**
- Let's Encrypt integration
- Automatic certificate renewal
- Multiple issuer support
- DNS-01 and HTTP-01 challenges
- Wildcard certificate support

**Quick Install:**
```bash
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f cert-manager/values.yaml
```

📖 **Full guide**: [cert-manager/README.md](./cert-manager/README.md)

### cert-manager OVH Webhook

**Purpose**: Enables DNS-01 challenges using OVH DNS for wildcard certificates

**Features:**
- Automatic DNS record creation
- Wildcard certificate support
- Works with private services (no public HTTP exposure needed)
- Automatic ClusterIssuer creation

**Prerequisites**: OVH API credentials (see [OVH webhook README](./cert-manager-ovh-webhook/README.md#getting-ovh-api-credentials))

**Quick Install:**
```bash
# IMPORTANT: Edit values.yaml first with your OVH credentials!
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/
helm repo update
helm upgrade --install \
  --namespace cert-manager \
  -f cert-manager-ovh-webhook/values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh
```

📖 **Full guide**: [cert-manager-ovh-webhook/README.md](./cert-manager-ovh-webhook/README.md)

## Complete Setup Guide

For a step-by-step walkthrough of the entire ingress stack, see:

📖 [**Complete Ingress Controller Documentation**](../docs/ingress-controller.md)

This comprehensive guide covers:
- Architecture and component interaction
- Installation in the correct order
- Configuration deep-dive
- Creating your first IngressRoute with TLS
- Troubleshooting common issues
- Advanced usage patterns

## Quick Start

### First Time Setup

1. **Install Traefik** (ingress controller):
   ```bash
   cd helm/traefik
   helm repo add traefik https://traefik.github.io/charts
   helm repo update
   helm install traefik traefik/traefik \
     -f values.yaml \
     -n traefik --create-namespace
   ```

2. **Install cert-manager** (certificate management):
   ```bash
   cd ../cert-manager
   helm install cert-manager \
     oci://quay.io/jetstack/charts/cert-manager \
     --version v1.19.1 \
     --namespace cert-manager \
     --create-namespace \
     -f values.yaml
   ```

3. **Configure OVH credentials** (for DNS-01 challenges):
   ```bash
   cd ../cert-manager-ovh-webhook
   # IMPORTANT: Edit values.yaml with your OVH API credentials
   vi values.yaml
   ```

4. **Install OVH webhook**:
   ```bash
   helm repo add cert-manager-webhook-ovh-charts \
     https://aureq.github.io/cert-manager-webhook-ovh/
   helm repo update
   helm upgrade --install \
     --namespace cert-manager \
     -f values.yaml \
     cm-webhook-ovh \
     cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh
   ```

5. **Verify everything is running**:
   ```bash
   # Check Traefik
   kubectl -n traefik get pods
   
   # Check cert-manager
   kubectl -n cert-manager get pods
   
   # Check ClusterIssuer is ready
   kubectl get clusterissuer
   ```

### Deploy a Test Application

Use the included nginx example:

```bash
# Edit to use your domain
cd helm/traefik
sed -i 's/your-domain.com/example.com/g' nginx-test.yaml

# Deploy
kubectl apply -f nginx-test.yaml

# Watch certificate creation (takes 1-3 minutes)
kubectl get certificate -w
```

Once the certificate is `Ready`, visit `https://nginx.example.com` in your browser!

## Configuration Workflow

### Adding a New Service with TLS

For any new service you want to expose with HTTPS:

1. **Create Kubernetes resources** (Deployment, Service)
2. **Create Certificate** resource:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: myapp-cert
   spec:
     secretName: myapp-tls
     issuerRef:
       name: ovh-cluster-issuer
       kind: ClusterIssuer
     dnsNames:
       - myapp.example.com
   ```

3. **Create IngressRoute**:
   ```yaml
   apiVersion: traefik.io/v1alpha1
   kind: IngressRoute
   metadata:
     name: myapp
   spec:
     entryPoints:
       - websecure
     routes:
       - match: Host(`myapp.example.com`)
         kind: Rule
         services:
           - name: myapp-service
             port: 80
     tls:
       secretName: myapp-tls
   ```

4. **Apply and verify**:
   ```bash
   kubectl apply -f myapp.yaml
   kubectl get certificate
   kubectl get ingressroute
   ```

## Customization

### Editing Helm Values

Each component has a `values.yaml` file you can customize:

**Traefik** (`traefik/values.yaml`):
- Port configurations
- HTTP to HTTPS redirect settings
- Dashboard enablement
- Resource limits

**cert-manager** (`cert-manager/values.yaml`):
- DNS resolvers for validation
- Resource limits
- Log levels

**OVH Webhook** (`cert-manager-ovh-webhook/values.yaml`):
- OVH API credentials
- ClusterIssuer configuration
- Email for Let's Encrypt
- Staging vs production

### Updating Components

```bash
# Update Traefik
helm repo update
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f traefik/values.yaml

# Update cert-manager
helm upgrade cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.XX.X \
  -n cert-manager \
  -f cert-manager/values.yaml

# Update OVH webhook
helm upgrade cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh \
  -n cert-manager \
  -f cert-manager-ovh-webhook/values.yaml
```

## Troubleshooting

### Common Issues

**Traefik pods not starting:**
```bash
kubectl -n traefik describe pods
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
```

**Certificate stuck in Pending:**
```bash
kubectl describe certificate <cert-name>
kubectl -n cert-manager logs -l app=cert-manager
```

**DNS record not created:**
```bash
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh
```

For detailed troubleshooting, see:
- [Traefik troubleshooting](./traefik/README.md#troubleshooting)
- [cert-manager troubleshooting](./cert-manager/README.md#troubleshooting)
- [OVH webhook troubleshooting](./cert-manager-ovh-webhook/README.md#troubleshooting)
- [Complete ingress guide](../docs/ingress-controller.md#troubleshooting)

## Best Practices

1. **Use staging issuer first**: Test with Let's Encrypt staging before production
2. **Wildcard certificates**: Use for multiple subdomains to reduce rate limits
3. **Resource limits**: Set appropriate limits for your cluster size
4. **Monitor certificates**: Alert on certificates expiring within 21 days
5. **Backup configurations**: Keep values.yaml in version control
6. **Secure credentials**: Never commit OVH API keys to Git

## Future Additions

This directory will grow as more services are added:

- 🔜 **Prometheus/Grafana**: Monitoring and observability
- 🔜 **ArgoCD**: GitOps continuous delivery
- 🔜 **Longhorn**: Distributed block storage
- 🔜 **External DNS**: Automatic DNS record management
- 🔜 **Sealed Secrets**: Encrypted secrets in Git

## References

- **Helm Documentation**: https://helm.sh/docs/
- **Traefik**: https://doc.traefik.io/traefik/
- **cert-manager**: https://cert-manager.io/docs/
- **OVH API**: https://docs.ovh.com/gb/en/customer/first-steps-with-ovh-api/

## Support

- **Component-specific issues**: See individual README files in each directory
- **General setup help**: See [Complete Ingress Controller Guide](../docs/ingress-controller.md)
- **Project issues**: [Open an issue](https://github.com/AyRickk/homelab/issues)
- **Questions**: [Start a discussion](https://github.com/AyRickk/homelab/discussions)
