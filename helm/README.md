# Helm Templates

## Overview

This directory contains the Helm configurations for the ingress stack. Each subdirectory has a `values.yaml` file that configures an official Helm chart.

**What's here:**
- `traefik/` - Ingress controller configuration and test example
- `cert-manager/` - Certificate automation configuration
- `cert-manager-ovh-webhook/` - OVH DNS integration for wildcard certificates

## Quick Start

Install in this order:

```bash
# 1. Traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -f traefik/values.yaml \
  -n traefik --create-namespace

# 2. cert-manager
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f cert-manager/values.yaml

# 3. OVH webhook (edit values.yaml with your OVH API credentials first!)
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/
helm repo update
helm upgrade --install \
  --namespace cert-manager \
  -f cert-manager-ovh-webhook/values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh
```

## Using the Templates

### Test Application

Try the included example:

```bash
# Edit for your domain
sed -i 's/your-domain.com/example.com/g' traefik/nginx-test.yaml

# Deploy
kubectl apply -f traefik/nginx-test.yaml

# Watch certificate creation
kubectl get certificate -w
```

### Your Own Applications

Use this pattern from `traefik/nginx-test.yaml`:

1. **Deployment** - Your application
2. **Service** - ClusterIP service
3. **Certificate** - cert-manager requests TLS cert via OVH DNS
4. **IngressRoute** - Traefik routes traffic with TLS

The templates handle:
- Automatic DNS record creation/deletion
- Let's Encrypt certificate issuance
- Certificate renewal (30 days before expiry)
- HTTP to HTTPS redirect
- TLS termination

## Configuration Files

### traefik/values.yaml

Configures HTTP to HTTPS redirect:
```yaml
ports:
  web:
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
```

### cert-manager/values.yaml

Sets DNS resolvers for validation:
```yaml
extraArgs:
  - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

### cert-manager-ovh-webhook/values.yaml

**Edit this file** with your:
- Domain (`groupName`)
- Email
- OVH API credentials (applicationKey, applicationSecret, applicationConsumerKey)

Get OVH credentials at: https://eu.api.ovh.com/createToken/

## Complete Documentation

See [../docs/ingress-controller.md](../docs/ingress-controller.md) for:
- Why these technologies
- Architecture explanation
- Detailed installation steps
- Troubleshooting guide

