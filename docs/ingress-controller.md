# 🌐 Ingress Controller - Traefik with TLS Automation

## Overview

This guide covers the complete setup of Traefik as an ingress controller in your RKE2 cluster, with automatic TLS certificate management using cert-manager and OVH DNS validation.

**What you get:**
- **Traefik v3**: Modern, cloud-native ingress controller and reverse proxy
- **Automatic HTTPS**: Let's Encrypt certificates with automatic renewal
- **DNS-01 Validation**: Using OVH DNS for wildcard certificates and private services
- **Production-ready**: HTTP to HTTPS redirect, secure defaults

## Why This Choice?

### Why Traefik?

- **Cloud-native design**: Built specifically for Kubernetes with CRDs
- **Automatic discovery**: Detects services and routes automatically
- **Modern protocol support**: HTTP/2, HTTP/3, gRPC, WebSocket
- **Excellent documentation**: Clear guides and active community
- **Performance**: Lightweight and fast, perfect for homelab
- **Dashboard**: Built-in web UI for monitoring and debugging

**Alternatives considered:**
- **Nginx Ingress**: More traditional, but requires more manual configuration
- **Kong**: More enterprise-focused with complex setup
- **HAProxy**: Great for load balancing but less Kubernetes-native

### Why cert-manager?

- **Industry standard**: The de-facto solution for certificate management in Kubernetes
- **Automatic renewal**: No more expired certificates
- **Multiple issuers**: Let's Encrypt, custom CA, and more
- **DNS-01 support**: Enables wildcard certificates and validation for internal services

### Why OVH DNS?

- **European provider**: GDPR-compliant DNS hosting
- **Affordable**: Free DNS hosting for domains registered with OVH
- **API access**: Full automation support for DNS-01 challenges
- **Reliable**: Robust infrastructure with good uptime

**Alternatives:**
- **Cloudflare**: Excellent but US-based
- **Route53**: AWS service, good integration but costly
- **HTTP-01**: Simpler but requires public exposure and no wildcards

## Prerequisites

Before starting, ensure you have:

✅ **RKE2 cluster deployed** with kubectl access (see [RKE2 Installation](./rke2-installation.md))

✅ **Domain name** managed by OVH DNS

✅ **OVH API credentials**:
- Application Key
- Application Secret  
- Consumer Key

> 📋 **Getting OVH API credentials**: See the [OVH API Setup](#ovh-api-credentials-setup) section below.

✅ **Helm installed** on your local machine:
```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

✅ **kubectl access** to your cluster:
```bash
# Copy kubeconfig from master node
scp -P 2222 odin@10.10.10.101:/etc/rancher/rke2/rke2.yaml ~/.kube/config

# Update server address in kubeconfig
sed -i 's/127.0.0.1/10.10.10.100/g' ~/.kube/config

# Test connection
kubectl get nodes
```

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

## Detailed Installation Guide

### Step 1: Install Traefik

Traefik is the ingress controller that handles incoming HTTP/HTTPS traffic and routes it to services.

#### 1.1 Add Helm Repository

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

#### 1.2 Review Configuration

The configuration in `helm/traefik/values.yaml`:

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
- **Automatic HTTP to HTTPS redirect**: All traffic on port 80 redirects to port 443
- **Permanent redirect (301)**: Browsers cache the redirect for better performance
- **Security**: Ensures all traffic is encrypted

**Optional: Enable Traefik Dashboard**

Uncomment these lines in `values.yaml` to enable the web UI:

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

> ⚠️ **Security Warning**: The dashboard shows all routes and configuration. Only expose it if you understand the security implications. Consider using basic auth or IP whitelisting.

#### 1.3 Install Traefik

```bash
helm install traefik traefik/traefik \
  -f helm/traefik/values.yaml \
  -n traefik --create-namespace
```

**What happens:**
- Creates `traefik` namespace
- Deploys Traefik controller as a DaemonSet or Deployment
- Exposes ports 80 (web) and 443 (websecure)
- Creates LoadBalancer service (or uses NodePort in homelab)

#### 1.4 Verify Installation

```bash
# Check pods are running
kubectl -n traefik get pods

# Check service
kubectl -n traefik get svc

# View logs
kubectl -n traefik logs -l app.kubernetes.io/name=traefik --tail=50
```

**Expected output:**
```
NAME                       READY   STATUS    RESTARTS   AGE
traefik-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### Step 2: Install cert-manager

cert-manager automates certificate issuance and renewal using Let's Encrypt.

#### 2.1 Review Configuration

The configuration in `helm/cert-manager/values.yaml`:

```yaml
namespace: "cert-manager"
crds:
  enabled: true
extraArgs:
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

**What this does:**
- **CRDs enabled**: Installs Certificate, Issuer, and ClusterIssuer resources
- **DNS-01 configuration**: Uses Cloudflare and Google DNS for validation queries
- **Recursive nameservers**: Ensures DNS propagation is properly checked

**Why these DNS servers?**
- **1.1.1.1 (Cloudflare)**: Fast, privacy-focused, reliable
- **8.8.8.8 (Google)**: Backup for redundancy
- Avoids using local DNS that might have stale records

#### 2.2 Install cert-manager

```bash
helm install cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager \
  --create-namespace \
  -f helm/cert-manager/values.yaml
```

**What happens:**
- Creates `cert-manager` namespace
- Installs Custom Resource Definitions (CRDs)
- Deploys cert-manager controller and webhook
- Sets up automatic certificate management

#### 2.3 Verify Installation

```bash
# Check all pods are running
kubectl -n cert-manager get pods

# Verify CRDs are installed
kubectl get crd | grep cert-manager

# Check cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager --tail=50
```

**Expected pods:**
- `cert-manager-xxxxxxxxxx-xxxxx` - Main controller
- `cert-manager-webhook-xxxxxxxxxx-xxxxx` - Validation webhook
- `cert-manager-cainjector-xxxxxxxxxx-xxxxx` - CA injection

### Step 3: Configure OVH API Credentials

Before installing the OVH webhook, you need API credentials.

#### 3.1 Get OVH API Credentials

1. Go to [OVH API Token Creation](https://eu.api.ovh.com/createToken/)
2. Log in with your OVH account
3. Fill in the form:
   - **Application name**: `cert-manager-homelab`
   - **Application description**: `Certificate management for Kubernetes`
   - **Validity**: `Unlimited` (or choose a duration)
   - **Rights**:
     ```
     GET    /domain/zone/*
     POST   /domain/zone/*
     DELETE /domain/zone/*
     ```

4. Click **Create keys**
5. Save the credentials:
   - **Application Key** (AK)
   - **Application Secret** (AS)
   - **Consumer Key** (CK)

> 🔐 **Security**: These credentials have access to modify your DNS. Store them securely and never commit them to Git!

#### 3.2 Update Configuration

Edit `helm/cert-manager-ovh-webhook/values.yaml`:

```yaml
# Change the group name to match your domain
groupName: "acme.your-domain.com"  # e.g., "acme.example.com"

issuers:
  - name: ovh-cluster-issuer
    create: true
    kind: ClusterIssuer
    namespace: cert-manager
    acmeServerUrl: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # ← Your email for Let's Encrypt
    ovhEndpointName: ovh-eu
    ovhAuthenticationMethod: application
    ovhAuthentication:
      applicationKey: "YOUR_APPLICATION_KEY"      # ← From OVH
      applicationSecret: "YOUR_APPLICATION_SECRET" # ← From OVH
      applicationConsumerKey: "YOUR_CONSUMER_KEY"  # ← From OVH
```

**Configuration explained:**
- **groupName**: Unique identifier for the webhook (use your domain)
- **acmeServerUrl**: Let's Encrypt production server (for real certificates)
- **email**: Receives expiration warnings (should never happen with auto-renewal!)
- **ovhEndpointName**: `ovh-eu` for Europe, `ovh-ca` for Canada, etc.
- **Credentials**: Your OVH API keys

> 🧪 **Testing first?** For testing, use Let's Encrypt staging:
> ```yaml
> acmeServerUrl: https://acme-staging-v02.api.letsencrypt.org/directory
> ```
> Staging has higher rate limits but issues untrusted certificates.

### Step 4: Install OVH Webhook

The OVH webhook enables cert-manager to create DNS records for validation.

#### 4.1 Install Webhook

```bash
# Add Helm repository
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/
helm repo update

# Install webhook
helm upgrade --install \
  --namespace cert-manager \
  -f helm/cert-manager-ovh-webhook/values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh
```

#### 4.2 Verify Installation

```bash
# Check webhook pod
kubectl -n cert-manager get pods -l app.kubernetes.io/name=cert-manager-webhook-ovh

# Verify ClusterIssuer was created
kubectl get clusterissuer

# Check ClusterIssuer status
kubectl describe clusterissuer ovh-cluster-issuer
```

**Expected output:**
```
NAME                  READY   AGE
ovh-cluster-issuer    True    1m
```

**Status should show:**
```
Status:
  Acme:
    Uri: https://acme-v02.api.letsencrypt.org/acme/acct/XXXXXXXX
  Conditions:
    Status: True
    Type:   Ready
```

> ⚠️ **Not ready?** Check logs: `kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh`

## Testing Your Setup

Now that everything is installed, let's test it with a real application!

### Deploy Test Application

The repository includes a complete test application in `helm/traefik/nginx-test.yaml`:

#### 1. Review the Test Configuration

```yaml
# Deployment - Simple nginx web server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: nginx
          image: nginx:latest

---
# Service - ClusterIP service
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  ports:
    - port: 80

---
# IngressRoute - Traefik routing
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-ingressroute
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`nginx.your-domain.com`)
      kind: Rule
      services:
        - name: nginx-service
          port: 80
  tls:
    secretName: nginx-your-domain-com-tls

---
# Certificate - Automatic TLS
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-ingressroute-certificate
spec:
  secretName: nginx-your-domain-com-tls
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - nginx.your-domain.com
```

#### 2. Customize for Your Domain

```bash
# Copy the example
cp helm/traefik/nginx-test.yaml /tmp/my-nginx-test.yaml

# Replace your-domain.com with your actual domain
sed -i 's/your-domain.com/example.com/g' /tmp/my-nginx-test.yaml
```

#### 3. Deploy

```bash
kubectl apply -f /tmp/my-nginx-test.yaml
```

#### 4. Watch Certificate Creation

```bash
# Watch certificate status
kubectl get certificate -w

# Check certificate details
kubectl describe certificate nginx-ingressroute-certificate

# Watch cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager --tail=50 -f
```

**Certificate lifecycle:**
1. **Pending**: cert-manager creates DNS record
2. **Validation**: Let's Encrypt checks DNS record
3. **Issued**: Certificate stored in Secret
4. **Ready**: Certificate active and in use

This takes 1-3 minutes depending on DNS propagation.

#### 5. Verify DNS Record

During validation, cert-manager creates a TXT record:

```bash
# Check for TXT record (while cert is pending)
dig _acme-challenge.nginx.your-domain.com TXT

# Should return something like:
# _acme-challenge.nginx.your-domain.com. 60 IN TXT "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

#### 6. Test Access

Once the certificate is ready:

```bash
# Test with curl
curl -I https://nginx.your-domain.com

# Should return:
# HTTP/2 200
# server: nginx
# ...
```

**In browser:** Visit `https://nginx.your-domain.com`
- ✅ Valid certificate (green padlock)
- ✅ Issued by "R10" (Let's Encrypt)
- ✅ Shows nginx welcome page

## Configuration Deep Dive

### Traefik Configuration Options

Beyond the basic setup, you can customize Traefik extensively:

#### Custom Entry Points

```yaml
# values.yaml
ports:
  web:
    port: 80
    redirections:
      entryPoint:
        to: websecure
  websecure:
    port: 443
    http3: true  # Enable HTTP/3
  ssh:
    port: 2222  # Custom port for SSH tunneling
```

#### Middleware

```yaml
# Create middleware for security headers
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
spec:
  headers:
    sslRedirect: true
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    frameDeny: true
```

Apply to IngressRoute:

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

#### Access Logs

```yaml
# values.yaml
logs:
  access:
    enabled: true
    format: json
```

### cert-manager Configuration Options

#### Multiple Issuers

You can have multiple issuers for different purposes:

```yaml
# Staging issuer for testing
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
    - dns01:
        webhook:
          groupName: acme.example.com
          solverName: ovh
---
# Production issuer
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
    - dns01:
        webhook:
          groupName: acme.example.com
          solverName: ovh
```

#### Wildcard Certificates

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
    - "*.example.com"  # Wildcard
```

**Benefits:**
- Single certificate for all subdomains
- Reduces Let's Encrypt rate limit impact
- Faster deployment of new services

**Considerations:**
- Broader impact if compromised
- Can't use HTTP-01 validation (requires DNS-01)

## DNS Configuration

### Point Your Domain to the Cluster

You need to configure DNS to point to your cluster's ingress.

#### Option 1: External IP (Cloud/VPS)

If your cluster is accessible from the internet:

```
# A records
nginx.example.com    A    203.0.113.10  # Your external IP
*.example.com        A    203.0.113.10  # Wildcard for all apps
```

#### Option 2: Local Network (Homelab)

If your cluster is on a local network:

```
# A records pointing to local IPs
nginx.example.com    A    10.10.10.100  # KubeVIP or master node
*.example.com        A    10.10.10.100  # Wildcard
```

**Access from outside:**
- Configure port forwarding on your router (80/443 → 10.10.10.100)
- Or use VPN (WireGuard/Tailscale) to access local services

#### Option 3: Split DNS (Recommended for Homelab)

- **External DNS**: Points to external IP with firewall rules
- **Internal DNS** (Pi-hole/AdGuard): Points to 10.10.10.100

**Benefits:**
- Internal traffic stays local (faster, no bandwidth usage)
- External access still possible
- Better security with controlled external exposure

### DNS Propagation

After creating/updating DNS records:

```bash
# Check DNS propagation
dig nginx.example.com

# Check from external DNS
dig @8.8.8.8 nginx.example.com
dig @1.1.1.1 nginx.example.com

# Watch for changes
watch -n 5 dig nginx.example.com
```

Propagation typically takes:
- **OVH nameservers**: Immediate (few seconds)
- **Other resolvers**: 5-30 minutes
- **Global propagation**: Up to 48 hours (rare)

## Troubleshooting

### Traefik Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl -n traefik get pods

# Check events
kubectl -n traefik get events --sort-by='.lastTimestamp'

# Check logs
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
```

**Common issues:**
- **Image pull errors**: Check internet connectivity
- **Resource limits**: Increase memory/CPU limits
- **Port conflicts**: Check if ports 80/443 are already in use

#### Service Not Accessible

```bash
# Check service
kubectl -n traefik get svc traefik

# Check endpoints
kubectl -n traefik get endpoints traefik

# Test from inside cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- sh
# Inside container:
curl http://traefik.traefik.svc.cluster.local
```

**Common issues:**
- **Wrong service type**: Change to NodePort for homelab
- **Firewall rules**: Check iptables/firewall on nodes
- **Network policy**: Verify no policies blocking traffic

### cert-manager Issues

#### Certificate Stuck in Pending

```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest <cert-request-name>

# Check order
kubectl get order
kubectl describe order <order-name>

# Check challenge
kubectl get challenge
kubectl describe challenge <challenge-name>
```

**Common issues:**
- **DNS propagation delay**: Wait 2-5 minutes
- **Wrong OVH credentials**: Check secret values
- **OVH API permissions**: Verify DNS zone access
- **Rate limiting**: Use staging issuer for testing

#### Failed Challenges

```bash
# Get detailed challenge info
kubectl describe challenge <challenge-name>

# Check cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager --tail=100

# Check webhook logs
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh
```

**Common issues:**
- **DNS record not created**: Check webhook logs
- **Invalid OVH endpoint**: Use correct region (ovh-eu, ovh-ca, etc.)
- **Propagation timeout**: Increase timeout in cert-manager config
- **Firewall blocking**: Let's Encrypt must reach your DNS

#### Certificate Not Renewing

cert-manager automatically renews certificates 30 days before expiry.

```bash
# Check certificate expiry
kubectl get certificate -o jsonpath='{.items[*].status.notAfter}'

# Force renewal by deleting secret
kubectl delete secret <cert-secret-name>
# cert-manager will recreate it

# Check renewal logs
kubectl -n cert-manager logs -l app=cert-manager | grep -i renewal
```

### OVH Webhook Issues

#### Webhook Not Running

```bash
# Check webhook pod
kubectl -n cert-manager get pods -l app.kubernetes.io/name=cert-manager-webhook-ovh

# Check logs
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh

# Check service
kubectl -n cert-manager get svc cert-manager-webhook-ovh
```

#### DNS Record Not Created

```bash
# Check OVH API access
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh | grep -i error

# Test OVH credentials manually
curl -X GET "https://eu.api.ovh.com/1.0/domain/zone/example.com" \
  -H "X-Ovh-Application: YOUR_APP_KEY" \
  -H "X-Ovh-Consumer: YOUR_CONSUMER_KEY" \
  -H "X-Ovh-Timestamp: $(date +%s)" \
  -H "X-Ovh-Signature: ..."  # Complex signature calculation
```

**Common issues:**
- **Invalid credentials**: Double-check all three keys
- **Wrong zone name**: Must match your domain exactly
- **Expired consumer key**: Regenerate in OVH console
- **API permissions**: Verify GET/POST/DELETE rights

### Debug Mode

Enable verbose logging:

```bash
# cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager \
  --set logLevel=6

# Traefik
helm upgrade traefik traefik/traefik \
  -n traefik \
  --set logs.general.level=DEBUG
```

## Advanced Usage

### Multiple Domains with Different DNS Providers

You can configure multiple ClusterIssuers for different DNS providers:

```yaml
# OVH issuer for example.com
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ovh-cluster-issuer
spec:
  acme:
    solvers:
    - selector:
        dnsZones:
          - 'example.com'
      dns01:
        webhook:
          groupName: acme.example.com
          solverName: ovh

# Cloudflare issuer for another-domain.com
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-cluster-issuer
spec:
  acme:
    solvers:
    - selector:
        dnsZones:
          - 'another-domain.com'
      dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

### Custom Certificate Duration

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: long-lived-cert
spec:
  duration: 2160h  # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  secretName: long-lived-cert-tls
  dnsNames:
    - app.example.com
```

### TCP/UDP Services

Traefik can route TCP/UDP traffic too:

```yaml
# values.yaml
ports:
  mysql:
    port: 3306
    expose: true
    exposedPort: 3306
    protocol: TCP

# IngressRouteTCP
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: mysql-tcp
spec:
  entryPoints:
    - mysql
  routes:
    - match: HostSNI(`*`)
      services:
        - name: mysql-service
          port: 3306
```

## Security Best Practices

### Secure Your Ingress

1. **Use strong TLS settings**:
```yaml
# Traefik middleware for TLS
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: secure-tls
spec:
  headers:
    sslRedirect: true
    stsSeconds: 63072000
    stsIncludeSubdomains: true
    stsPreload: true
```

2. **Rate limiting**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
spec:
  rateLimit:
    average: 100
    burst: 50
```

3. **IP whitelisting** for sensitive services:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: internal-only
spec:
  ipWhiteList:
    sourceRange:
      - 10.0.0.0/8
      - 192.168.0.0/16
```

### Protect OVH Credentials

```bash
# Store credentials in external secret manager (e.g., Sealed Secrets)
kubectl create secret generic ovh-credentials \
  --from-literal=application-key=... \
  --from-literal=application-secret=... \
  --from-literal=consumer-key=... \
  -n cert-manager \
  --dry-run=client -o yaml | kubeseal -o yaml > sealed-ovh-credentials.yaml
```

### Monitor Certificate Expiry

```bash
# Set up alerts with Prometheus
# Example alert rule
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < (21 * 24 * 3600)
  annotations:
    summary: "Certificate {{ $labels.name }} expires in less than 21 days"
```

## Maintenance

### Updating Components

#### Update Traefik

```bash
# Check current version
helm list -n traefik

# Update repository
helm repo update

# See available versions
helm search repo traefik/traefik --versions

# Upgrade
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f helm/traefik/values.yaml
```

#### Update cert-manager

```bash
# Check for new releases
helm search hub cert-manager --version "v1.*"

# Upgrade (will upgrade CRDs too)
helm upgrade cert-manager \
  oci://quay.io/jetstack/charts/cert-manager \
  --version v1.XX.X \
  --namespace cert-manager \
  -f helm/cert-manager/values.yaml
```

#### Update OVH Webhook

```bash
helm repo update
helm upgrade cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh \
  -n cert-manager \
  -f helm/cert-manager-ovh-webhook/values.yaml
```

### Backup Configuration

```bash
# Backup all ingress configurations
kubectl get ingressroute,middleware -A -o yaml > ingress-backup.yaml

# Backup all certificates
kubectl get certificate,clusterissuer,issuer -A -o yaml > certificates-backup.yaml

# Backup Helm values
helm get values traefik -n traefik > traefik-values-backup.yaml
helm get values cert-manager -n cert-manager > cert-manager-values-backup.yaml
```

### Monitoring

Set up monitoring to track:

```bash
# Traefik metrics
kubectl port-forward -n traefik svc/traefik 9100:9100
curl http://localhost:9100/metrics

# cert-manager metrics
kubectl port-forward -n cert-manager svc/cert-manager 9402:9402
curl http://localhost:9402/metrics
```

**Key metrics:**
- Request count and latency (Traefik)
- Certificate expiry time (cert-manager)
- Challenge success/failure rate
- HTTP status codes

## Next Steps

Now that you have ingress working:

1. **Deploy real applications**: Use the nginx-test.yaml as a template
2. **Set up monitoring**: Prometheus + Grafana for observability
3. **Configure backup**: Backup certificates and configurations
4. **Add authentication**: OAuth2 proxy or basic auth for services
5. **Optimize**: Fine-tune Traefik for your workload

## References

### Official Documentation

- **Traefik**: https://doc.traefik.io/traefik/
- **cert-manager**: https://cert-manager.io/docs/
- **OVH API**: https://docs.ovh.com/gb/en/customer/first-steps-with-ovh-api/
- **Let's Encrypt**: https://letsencrypt.org/docs/

### Related Project Documentation

- [RKE2 Installation](./rke2-installation.md) - Deploy your cluster first
- [Infrastructure](./infrastructure.md) - Architecture overview
- [Main README](../README.md) - Project overview

### Community Resources

- [Traefik Community Forum](https://community.traefik.io/)
- [cert-manager GitHub](https://github.com/cert-manager/cert-manager)
- [OVH Webhook GitHub](https://github.com/aureq/cert-manager-webhook-ovh)

### Inspiration

This setup is inspired by:
- [ChristianLempa/boilerplates](https://github.com/ChristianLempa/boilerplates) - Traefik examples
- Production Kubernetes best practices
- Real homelab deployments in the community
