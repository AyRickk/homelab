# 🌐 Ingress Controller - Traefik with TLS Automation

## Overview

This is the ingress stack for the homelab RKE2 cluster: Traefik v3 handles incoming traffic, cert-manager automates TLS certificates from Let's Encrypt, and OVH DNS webhook enables wildcard certificates.

**What this provides:**
- Automatic HTTPS for all services with Let's Encrypt
- HTTP to HTTPS redirect (configured in `helm/traefik/values.yaml`)
- Wildcard certificates using DNS-01 validation
- No need to expose services publicly for certificate validation

## Why These Technologies?

**Traefik**: Kubernetes-native with automatic service discovery and CRDs (IngressRoute). Simpler than Nginx Ingress for homelab use.

**cert-manager**: Industry standard for Kubernetes certificate automation. Set it once and forget about certificate renewals.

**OVH DNS + DNS-01**: I use OVH for domain hosting. DNS-01 validation allows wildcard certificates and works for internal services without exposing them to the internet - perfect for a homelab behind NAT.

## Prerequisites

Before starting, you need:

✅ **RKE2 cluster running** (see [RKE2 Installation](./rke2-installation.md))

✅ **Domain managed by OVH DNS** - I use OVH for domain hosting

✅ **OVH API credentials** - Get these from [OVH API Token Creation](https://eu.api.ovh.com/createToken/):
   - Application Key
   - Application Secret  
   - Consumer Key

✅ **kubectl access** to your cluster:
```bash
# Copy kubeconfig from master node
scp -P 2222 odin@10.10.10.101:/etc/rancher/rke2/rke2.yaml ~/.kube/config

# Update server address (10.10.10.100 is the KubeVIP address)
sed -i 's/127.0.0.1/10.10.10.100/g' ~/.kube/config

kubectl get nodes
```

## How This Was Implemented

This setup uses three Helm charts with custom configuration files in the `helm/` directory.

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet / Local Network                 │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │   Traefik        │ ← LoadBalancer/NodePort
                   │   Ingress        │    (Ports 80/443)
                   └──────────┬───────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    ┌──────────┐        ┌──────────┐       ┌──────────┐
    │ Service  │        │ Service  │       │ Service  │
    │    A     │        │    B     │       │    C     │
    └──────────┘        └──────────┘       └──────────┘

┌────────────────────────────────────────────────────────────┐
│               TLS Certificate Management                    │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  cert-manager  ←→  Let's Encrypt  ←→  OVH DNS (DNS-01)    │
│                                                             │
│  1. Creates Certificate resource                           │
│  2. Requests cert from Let's Encrypt                       │
│  3. Creates DNS TXT record via OVH webhook                 │
│  4. Let's Encrypt validates domain ownership               │
│  5. Certificate stored as Kubernetes Secret                │
│  6. Auto-renewal 30 days before expiry                     │
└────────────────────────────────────────────────────────────┘
```

### Traffic Flow

1. **Client** connects to `https://app.example.com`
2. **DNS** resolves to your cluster (external IP or local IP)
3. **Traefik** receives the request on port 443
4. **TLS termination** using cert-manager managed certificate
5. **Route matching** based on Host header and path
6. **Backend service** receives decrypted HTTP traffic
7. **Response** flows back through Traefik to client

## File Structure

```
helm/
├── traefik/
│   ├── values.yaml           # Traefik configuration
│   └── nginx-test.yaml       # Example IngressRoute with TLS
├── cert-manager/
│   └── values.yaml           # cert-manager configuration
└── cert-manager-ovh-webhook/
    └── values.yaml           # OVH DNS webhook configuration
```

## Quick Start

**Want to deploy fast?** Follow these steps:

```bash
# 1. Install Traefik
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -f helm/traefik/values.yaml \
  -n traefik --create-namespace

# 2. Install cert-manager
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f helm/cert-manager/values.yaml

# 3. Configure OVH webhook with your credentials
# Edit helm/cert-manager-ovh-webhook/values.yaml first!

# 4. Install OVH webhook
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/
helm repo update
helm upgrade --install \
  --namespace cert-manager \
  -f helm/cert-manager-ovh-webhook/values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh

# 5. Verify installation
kubectl -n traefik get pods
kubectl -n cert-manager get pods
kubectl -n cert-manager get clusterissuer
```

**⚠️ First time?** Continue reading for detailed explanations!

## Configuration Files

### 1. Traefik (`helm/traefik/values.yaml`)

This configures Traefik to automatically redirect HTTP to HTTPS:

```yaml
ports:
  web:
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
```

**Why this matters**: Every service automatically gets HTTPS. No need to configure redirects per service.

**Optional Dashboard**: Uncomment the `ingressRoute.dashboard` section to enable Traefik's web UI at `traefik.your-domain.com`.

### 2. cert-manager (`helm/cert-manager/values.yaml`)

```yaml
namespace: "cert-manager"
crds:
  enabled: true
extraArgs:
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

**What this does**: 
- Installs cert-manager CRDs (Certificate, Issuer, ClusterIssuer)
- Uses Cloudflare (1.1.1.1) and Google (8.8.8.8) DNS for validation checks
- Avoids local DNS caches that might have stale records

### 3. OVH Webhook (`helm/cert-manager-ovh-webhook/values.yaml`)

This is where you configure your OVH credentials and domain:

```yaml
groupName: "acme.your-domain.com"  # Change to your domain

issuers:
  - name: ovh-cluster-issuer
    email: your-email@example.com   # Your email
    ovhEndpointName: ovh-eu          # OVH region
    ovhAuthentication:
      applicationKey: "YOUR_KEY"
      applicationSecret: "YOUR_SECRET"
      applicationConsumerKey: "YOUR_CONSUMER_KEY"
```

**Before installing**: Edit this file with your OVH API credentials and domain.

## Installation Steps

### Step 1: Install Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -f helm/traefik/values.yaml \
  -n traefik --create-namespace

# Verify
kubectl -n traefik get pods
```

### Step 2: Install cert-manager

```bash
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f helm/cert-manager/values.yaml

# Verify all three pods are running
kubectl -n cert-manager get pods
```

### Step 3: Configure and Install OVH Webhook

**First, get OVH API credentials**:
1. Go to https://eu.api.ovh.com/createToken/
2. Application name: `cert-manager-homelab`
3. Rights: `GET /domain/zone/*`, `POST /domain/zone/*`, `DELETE /domain/zone/*`
4. Save the three keys you receive

**Then, edit the values file**:
```bash
vi helm/cert-manager-ovh-webhook/values.yaml
# Update: groupName, email, and the three API keys
```

**Install**:
```bash
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/
helm repo update
helm upgrade --install \
  --namespace cert-manager \
  -f helm/cert-manager-ovh-webhook/values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh

# Verify ClusterIssuer is ready
kubectl get clusterissuer
# Should show: ovh-cluster-issuer   True
```

## Using the Templates - Example Application

The repository includes `helm/traefik/nginx-test.yaml` - this is a complete working example showing how to deploy an application with automatic TLS.

### What's in the Example

This file contains four Kubernetes resources that work together:

1. **Deployment**: Runs nginx
2. **Service**: Exposes nginx internally (ClusterIP)
3. **Certificate**: Requests TLS certificate from Let's Encrypt via OVH DNS
4. **IngressRoute**: Traefik routing with TLS termination

### Deploy the Example

```bash
# Edit the file to use your domain
sed -i 's/your-domain.com/example.com/g' helm/traefik/nginx-test.yaml

# Deploy
kubectl apply -f helm/traefik/nginx-test.yaml

# Watch certificate creation (takes 1-3 minutes)
kubectl get certificate -w
```

**What happens:**
1. nginx deployment starts
2. cert-manager creates a TXT record in your OVH DNS: `_acme-challenge.nginx.example.com`
3. Let's Encrypt validates domain ownership via DNS
4. Certificate is issued and stored as a Secret
5. Traefik uses the certificate for TLS termination
6. Visit `https://nginx.example.com` - you'll see nginx with a valid Let's Encrypt certificate

### Template Pattern for Your Own Services

Use this pattern for any service you want to expose:

```yaml
# 1. Your application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  # ... your app config ...

---
# 2. Service
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
    - port: 80

---
# 3. Certificate (cert-manager creates this automatically)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
spec:
  secretName: myapp-tls
  issuerRef:
    name: ovh-cluster-issuer  # The ClusterIssuer from our values.yaml
    kind: ClusterIssuer
  dnsNames:
    - myapp.example.com

---
# 4. IngressRoute (Traefik routing)
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
spec:
  entryPoints:
    - websecure  # HTTPS only
  routes:
    - match: Host(`myapp.example.com`)
      kind: Rule
      services:
        - name: myapp-service
          port: 80
  tls:
    secretName: myapp-tls  # Links to the Certificate above
```

**That's it!** The template automatically handles:
- DNS record creation/deletion
- Certificate issuance from Let's Encrypt
- Certificate renewal (30 days before expiry)
- HTTP to HTTPS redirect (from `helm/traefik/values.yaml`)
- TLS termination at Traefik

### Wildcard Certificates

For multiple subdomains, use a wildcard certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-cert
spec:
  secretName: wildcard-example-com-tls
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - example.com
    - "*.example.com"  # All subdomains
```

Then reuse this certificate across multiple IngressRoutes:

```yaml
# App 1
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: app1
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app1.example.com`)
      kind: Rule
      services:
        - name: app1-service
          port: 80
  tls:
    secretName: wildcard-example-com-tls  # Reuse wildcard cert

---
# App 2
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: app2
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app2.example.com`)
      kind: Rule
      services:
        - name: app2-service
          port: 80
  tls:
    secretName: wildcard-example-com-tls  # Same wildcard cert
```

**Why wildcard?** One certificate for all subdomains. Reduces Let's Encrypt rate limits and simplifies management.

## Troubleshooting

### Certificate Stuck in "Pending"

```bash
# Check what's happening
kubectl describe certificate <cert-name>
kubectl get challenge
kubectl -n cert-manager logs -l app=cert-manager --tail=50
```

**Common causes:**
- DNS propagation delay (wait 2-5 minutes)
- Wrong OVH credentials in `helm/cert-manager-ovh-webhook/values.yaml`
- OVH API permissions not set correctly

### Service Not Accessible

```bash
# Check Traefik is running
kubectl -n traefik get pods

# Check IngressRoute was created
kubectl get ingressroute
```

**Common causes:**
- DNS not pointing to cluster IP
- IngressRoute Host doesn't match your domain
- Certificate not ready yet

### DNS Record Not Created

```bash
# Check webhook logs
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh
```

**Common causes:**
- Invalid OVH credentials
- Wrong `ovhEndpointName` (should be `ovh-eu` for Europe)
- DNS zone doesn't exist at OVH

## References

- **Traefik Documentation**: https://doc.traefik.io/traefik/
- **cert-manager Documentation**: https://cert-manager.io/docs/
- **OVH API Guide**: https://docs.ovh.com/gb/en/customer/first-steps-with-ovh-api/
- **Let's Encrypt**: https://letsencrypt.org/docs/

**Related Documentation:**
- [RKE2 Installation](./rke2-installation.md) - How the cluster was deployed
- [Infrastructure](./infrastructure.md) - Overall architecture
- [Helm README](../helm/README.md) - More examples and patterns
