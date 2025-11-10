# cert-manager

## Overview

cert-manager automates the management and issuance of TLS certificates from various issuing sources, including Let's Encrypt. This directory contains the Helm values configuration for cert-manager in your RKE2 cluster.

## Why cert-manager?

- **Automatic certificate issuance**: Request certificates declaratively via Kubernetes resources
- **Automatic renewal**: Certificates are renewed automatically before expiration
- **Multiple issuers**: Let's Encrypt, self-signed, Vault, and more
- **DNS-01 challenges**: Enables wildcard certificates and internal services
- **Industry standard**: De-facto solution for certificate management in Kubernetes

## Files in This Directory

### `values.yaml`

Core cert-manager configuration:

```yaml
namespace: "cert-manager"
crds:
  enabled: true
extraArgs:
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

**What this does:**
- **CRDs enabled**: Installs Certificate, Issuer, and ClusterIssuer Custom Resource Definitions
- **DNS-01 nameservers**: Uses Cloudflare (1.1.1.1) and Google (8.8.8.8) for DNS validation
- **Recursive only**: Ensures proper DNS propagation checking

**Why these DNS servers?**
- Fast and reliable for DNS propagation checks
- Avoids local DNS caches that might have stale records
- Provides redundancy if one is temporarily unavailable

## Installation

### Prerequisites

- RKE2 cluster running
- kubectl configured
- Helm 3 installed
- Traefik installed (for TLS termination)

### Quick Install

```bash
# Install cert-manager with CRDs
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f values.yaml
```

> 📦 **Note**: This uses OCI registry from Quay.io, which is the official distribution method as of cert-manager v1.8+

### Verify Installation

```bash
# Check all components are running
kubectl -n cert-manager get pods

# Expected pods:
# - cert-manager-xxxxxxxxxx-xxxxx
# - cert-manager-webhook-xxxxxxxxxx-xxxxx
# - cert-manager-cainjector-xxxxxxxxxx-xxxxx

# Verify CRDs are installed
kubectl get crd | grep cert-manager

# Check logs
kubectl -n cert-manager logs -l app=cert-manager
```

## Components Explained

### cert-manager Controller

The main controller that:
- Watches Certificate resources
- Requests certificates from issuers
- Manages certificate lifecycle and renewal
- Stores certificates as Kubernetes Secrets

### Webhook

Validates cert-manager resources:
- Ensures proper resource configuration
- Prevents invalid certificates from being created
- Validates webhook configurations for DNS-01 challenges

### CA Injector

Injects CA bundles:
- Adds CA certificates to webhooks
- Enables validation of custom CAs
- Required for some issuers and webhooks

## Configuration Options

### Custom DNS Resolvers

To use different DNS servers:

```yaml
extraArgs:
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=9.9.9.9:53,149.112.112.112:53  # Quad9
```

### Resource Limits

For larger clusters:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

### Multiple Replicas

For high availability:

```yaml
replicaCount: 3
```

> ⚠️ **Note**: Only the controller should be scaled. Webhook and cainjector use leader election.

### Custom Installation Namespace

```yaml
namespace: "certificates"
installCRDs: true
```

## Creating Issuers

cert-manager uses Issuers and ClusterIssuers to obtain certificates.

### ClusterIssuer vs Issuer

- **ClusterIssuer**: Cluster-wide, can be used by any namespace
- **Issuer**: Namespace-scoped, only usable within its namespace

**Best practice**: Use ClusterIssuers for shared infrastructure.

### Example: Let's Encrypt Staging

For testing (issues untrusted certificates but has higher rate limits):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
```

### Example: Let's Encrypt Production

For production (issues trusted certificates):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

> 📧 **Email**: Used by Let's Encrypt for certificate expiration warnings (you should never see these with auto-renewal!)

### Example: Self-Signed

For internal testing:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
```

## Creating Certificates

### Automatic via Ingress Annotations

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: my-app-tls  # cert-manager creates this
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

### Manual Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
    - www.app.example.com
  duration: 2160h  # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
```

**Certificate lifecycle:**
1. You create Certificate resource
2. cert-manager requests certificate from issuer
3. Issuer validates domain ownership
4. Certificate stored in Secret
5. Auto-renewed before expiration

## DNS-01 Challenge Setup

For wildcard certificates or services without public HTTP access, use DNS-01 challenges.

**You need:**
- A DNS provider webhook (e.g., OVH, Cloudflare, Route53)
- API credentials for your DNS provider

See the [OVH webhook documentation](../cert-manager-ovh-webhook/README.md) for complete DNS-01 setup.

## Troubleshooting

### Pods Not Ready

```bash
# Check pod status
kubectl -n cert-manager get pods

# Describe problematic pod
kubectl -n cert-manager describe pod <pod-name>

# Check logs
kubectl -n cert-manager logs <pod-name>
```

**Common issues:**
- CRDs not installed: Reinstall with `crds.enabled: true`
- Resource limits too low: Increase in values.yaml
- Webhook validation errors: Check webhook pod logs

### Certificate Not Issuing

```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>

# Check challenge status
kubectl get challenge
kubectl describe challenge <challenge-name>
```

**Common issues:**
- Invalid issuer: Check ClusterIssuer exists and is ready
- HTTP-01 validation failed: Ensure ingress is accessible
- DNS-01 validation failed: Check DNS webhook logs
- Rate limiting: Use staging issuer for testing

### Webhook Issues

```bash
# Test webhook
kubectl -n cert-manager get validatingwebhookconfigurations

# Check webhook logs
kubectl -n cert-manager logs -l app=webhook

# Test API server can reach webhook
kubectl -n cert-manager port-forward svc/cert-manager-webhook 10250:10250
curl -k https://localhost:10250/healthz
```

### Debug Mode

Enable verbose logging:

```bash
helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager \
  -f values.yaml \
  --set logLevel=6  # 0-6, where 6 is most verbose
```

## Monitoring

### Check Certificate Status

```bash
# List all certificates
kubectl get certificate -A

# Check expiry dates
kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.notAfter}{"\n"}{end}'

# Watch certificate renewal
kubectl get certificate -w
```

### Prometheus Metrics

cert-manager exposes Prometheus metrics on port 9402:

```bash
# Port forward to access metrics
kubectl -n cert-manager port-forward svc/cert-manager 9402:9402

# View metrics
curl http://localhost:9402/metrics
```

**Key metrics:**
- `certmanager_certificate_expiration_timestamp_seconds` - Certificate expiry time
- `certmanager_certificate_ready_status` - Certificate readiness
- `certmanager_http_acme_client_request_duration_seconds` - ACME request duration

## Updating cert-manager

```bash
# Check current version
helm list -n cert-manager

# Update to newer version
helm upgrade cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.XX.X \
  --namespace cert-manager \
  -f values.yaml
```

> ⚠️ **Breaking changes**: Always check the [upgrade notes](https://cert-manager.io/docs/installation/upgrade/) before upgrading major versions.

## Uninstalling

```bash
# Delete all certificates first (optional)
kubectl delete certificate --all -A

# Uninstall cert-manager
helm uninstall cert-manager -n cert-manager

# Delete CRDs (removes all cert-manager resources)
kubectl delete crd \
  certificates.cert-manager.io \
  certificaterequests.cert-manager.io \
  challenges.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io \
  orders.cert-manager.io

# Delete namespace
kubectl delete namespace cert-manager
```

> ⚠️ **Warning**: Deleting CRDs removes all certificates, issuers, and related resources!

## Best Practices

1. **Use ClusterIssuers**: Share issuers across namespaces
2. **Start with staging**: Test with Let's Encrypt staging before production
3. **Set email**: Configure email for certificate expiration warnings
4. **Monitor expiry**: Set up alerts for certificates expiring soon
5. **Backup certificates**: Export important certificates regularly
6. **Resource limits**: Set appropriate limits for your cluster size
7. **High availability**: Run multiple replicas in production

## Next Steps

1. **Set up DNS-01**: Install [OVH webhook](../cert-manager-ovh-webhook/README.md) for wildcard certificates
2. **Create issuers**: Configure Let's Encrypt staging and production
3. **Test certificate**: Create a test certificate to verify setup
4. **Deploy apps**: Use certificates in your IngressRoutes
5. **Monitor**: Set up Prometheus alerts for certificate expiry

## References

- **cert-manager Documentation**: https://cert-manager.io/docs/
- **Installation Guide**: https://cert-manager.io/docs/installation/
- **Configuration Options**: https://cert-manager.io/docs/configuration/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **Complete Setup Guide**: [../../docs/ingress-controller.md](../../docs/ingress-controller.md)

## Support

For issues specific to this homelab setup, see the main [ingress controller documentation](../../docs/ingress-controller.md#troubleshooting).
