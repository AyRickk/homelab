# Traefik Ingress Controller

## Overview

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. This directory contains the Helm values configuration for deploying Traefik v3 in your RKE2 cluster.

## Why Traefik?

- **Kubernetes-native**: Built-in support for Kubernetes Ingress and CRDs
- **Automatic service discovery**: Detects new services automatically
- **Dynamic configuration**: No need to restart on config changes
- **Modern protocols**: HTTP/2, HTTP/3, gRPC, WebSocket support
- **Built-in dashboard**: Web UI for monitoring and debugging
- **Let's Encrypt integration**: Works seamlessly with cert-manager

## Files in This Directory

### `values.yaml`

Core Traefik configuration:

```yaml
ports:
  web:
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
```

**What this does:**
- Redirects all HTTP (port 80) traffic to HTTPS (port 443)
- Uses permanent redirect (301) for better SEO and browser caching
- Ensures all traffic is encrypted

### `nginx-test.yaml`

Complete example application showing:
- Deployment (nginx web server)
- Service (ClusterIP)
- IngressRoute (Traefik routing with TLS)
- Certificate (cert-manager automatic TLS)

**Usage:**
```bash
# Edit to use your domain
sed -i 's/your-domain.com/example.com/g' nginx-test.yaml

# Deploy
kubectl apply -f nginx-test.yaml

# Watch certificate creation
kubectl get certificate -w
```

## Installation

### Prerequisites

- RKE2 cluster running
- kubectl configured
- Helm 3 installed

### Quick Install

```bash
# Add Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik
helm install traefik traefik/traefik \
  -f values.yaml \
  -n traefik --create-namespace
```

### Verify Installation

```bash
# Check pods
kubectl -n traefik get pods

# Check service
kubectl -n traefik get svc

# View logs
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
```

## Configuration Options

### Enable Dashboard

Uncomment in `values.yaml`:

```yaml
ingressRoute:
  dashboard:
    enabled: true
    entryPoints:
      - websecure
    matchRule: Host(`traefik.your-domain.com`)
    tls:
      secretName: traefik-your-domain-com-tls
```

> ⚠️ **Security**: The dashboard exposes all routes. Use authentication or IP restrictions in production.

### Additional Entry Points

Add custom ports in `values.yaml`:

```yaml
ports:
  web:
    port: 80
  websecure:
    port: 443
  ssh:
    port: 2222
    expose: true
```

### Middleware Examples

Create a middleware file:

```yaml
# security-headers.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: default
spec:
  headers:
    sslRedirect: true
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
```

Apply to an IngressRoute:

```yaml
routes:
  - match: Host(`app.example.com`)
    kind: Rule
    middlewares:
      - name: security-headers
    services:
      - name: my-service
        port: 80
```

## Creating IngressRoutes

### Basic HTTP → HTTPS

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      services:
        - name: my-app-service
          port: 80
  tls:
    secretName: my-app-tls
```

### With Path Prefix

```yaml
routes:
  - match: Host(`example.com`) && PathPrefix(`/api`)
    kind: Rule
    services:
      - name: api-service
        port: 8080
```

### Multiple Services (Weighted)

```yaml
routes:
  - match: Host(`app.example.com`)
    kind: Rule
    services:
      - name: app-v1
        port: 80
        weight: 90
      - name: app-v2
        port: 80
        weight: 10
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl -n traefik describe pod <pod-name>

# Check events
kubectl -n traefik get events --sort-by='.lastTimestamp'

# Check resource limits
kubectl -n traefik top pods
```

### Service Not Reachable

```bash
# Test from inside cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- sh
curl http://traefik.traefik.svc.cluster.local:80

# Check service endpoints
kubectl -n traefik get endpoints
```

### IngressRoute Not Working

```bash
# List all IngressRoutes
kubectl get ingressroute -A

# Describe specific route
kubectl describe ingressroute <name>

# Check Traefik logs for routing errors
kubectl -n traefik logs -l app.kubernetes.io/name=traefik | grep -i error
```

### Enable Debug Logging

```bash
# Upgrade with debug logging
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f values.yaml \
  --set logs.general.level=DEBUG
```

## Updating Traefik

```bash
# Check current version
helm list -n traefik

# Update repo
helm repo update

# Upgrade to latest
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f values.yaml

# Rollback if needed
helm rollback traefik -n traefik
```

## Uninstalling

```bash
# Remove Traefik
helm uninstall traefik -n traefik

# Clean up CRDs (optional, but removes all IngressRoutes)
kubectl delete crd ingressroutes.traefik.io
kubectl delete crd middlewares.traefik.io
kubectl delete crd ingressroutetcps.traefik.io
kubectl delete crd ingressrouteudps.traefik.io
```

> ⚠️ **Warning**: Deleting CRDs removes all IngressRoute configurations!

## Next Steps

1. **Set up cert-manager**: See [cert-manager README](../cert-manager/README.md)
2. **Deploy applications**: Use `nginx-test.yaml` as a template
3. **Configure monitoring**: Enable Prometheus metrics
4. **Add authentication**: OAuth2 proxy or basic auth

## References

- **Traefik Documentation**: https://doc.traefik.io/traefik/
- **Kubernetes Ingress**: https://doc.traefik.io/traefik/providers/kubernetes-ingress/
- **IngressRoute CRD**: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/
- **Complete Setup Guide**: [../../docs/ingress-controller.md](../../docs/ingress-controller.md)

## Support

For issues specific to this homelab setup, see the main [ingress controller documentation](../../docs/ingress-controller.md#troubleshooting).
