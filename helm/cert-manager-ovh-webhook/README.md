# cert-manager OVH Webhook

## Overview

The OVH webhook enables cert-manager to perform DNS-01 ACME challenges using OVH DNS. This allows you to obtain wildcard certificates and certificates for services that aren't publicly accessible via HTTP.

## Why DNS-01 with OVH?

**DNS-01 Challenges Enable:**
- **Wildcard certificates**: `*.example.com` - one certificate for all subdomains
- **Internal services**: No need to expose services to the internet
- **Behind firewall**: Works even if port 80/443 aren't publicly accessible
- **Private networks**: Perfect for homelab setups

**Why OVH?**
- **European provider**: GDPR-compliant DNS hosting
- **Free DNS hosting**: Included with domains registered at OVH
- **Full API access**: Complete automation support
- **Reliable**: Stable infrastructure with good uptime
- **Affordable**: Competitive domain pricing

**Alternatives:**
- **Cloudflare**: Excellent but US-based
- **Route53**: AWS service, costly for small setups
- **DigitalOcean**: Good but requires paid account
- **HTTP-01**: Simpler but requires public HTTP access and no wildcards

## Files in This Directory

### `values.yaml`

OVH webhook configuration with ClusterIssuer:

```yaml
configVersion: 0.0.2
groupName: "acme.your-domain.com"

issuers:
  - name: ovh-cluster-issuer
    create: true
    kind: ClusterIssuer
    acmeServerUrl: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    ovhEndpointName: ovh-eu
    ovhAuthenticationMethod: application
    ovhAuthentication:
      applicationKey: "YOUR_APPLICATION_KEY"
      applicationSecret: "YOUR_APPLICATION_SECRET"
      applicationConsumerKey: "YOUR_CONSUMER_KEY"
```

**Configuration fields:**
- **groupName**: Unique identifier for this webhook (use your domain)
- **acmeServerUrl**: Let's Encrypt server (production or staging)
- **email**: Your email for Let's Encrypt notifications
- **ovhEndpointName**: OVH API endpoint (see [Endpoints](#ovh-api-endpoints))
- **Credentials**: Your OVH API keys (see [Getting Credentials](#getting-ovh-api-credentials))

## Prerequisites

Before installing, you need:

✅ **cert-manager installed** (see [cert-manager README](../cert-manager/README.md))

✅ **Domain at OVH**: Your domain must be managed by OVH DNS

✅ **OVH API credentials**: Application Key, Secret, and Consumer Key

✅ **kubectl access**: To your RKE2 cluster

## Getting OVH API Credentials

### Step 1: Create OVH Application

1. Go to [OVH API Token Creation](https://eu.api.ovh.com/createToken/)
2. Log in with your OVH account
3. Fill in the form:

**Application Details:**
- **Application name**: `cert-manager-homelab`
- **Application description**: `Certificate management for Kubernetes cluster`
- **Validity**: `Unlimited` (recommended for automation)

**Rights (Permissions):**

For your domain zone:
```
GET    /domain/zone/*
POST   /domain/zone/*
DELETE /domain/zone/*
```

Or specifically for your domain:
```
GET    /domain/zone/example.com/*
POST   /domain/zone/example.com/*
DELETE /domain/zone/example.com/*
```

> 💡 **Tip**: Use wildcard `*` if you have multiple domains, or specify exact domain for least privilege.

4. Click **Create keys**

### Step 2: Save Credentials

You'll receive three credentials:

```
Application Key (AK):       xxxxxxxxxxxxxxxxxxxx
Application Secret (AS):    yyyyyyyyyyyyyyyyyyyy
Consumer Key (CK):          zzzzzzzzzzzzzzzzzzzz
```

> 🔐 **Security Warning**: These credentials provide DNS control. Store them securely and **never commit them to Git!**

**Secure storage options:**
- Password manager (1Password, Bitwarden, etc.)
- Kubernetes Secret (if cluster is secured)
- Sealed Secrets / External Secrets Operator
- HashiCorp Vault

### Step 3: Update Configuration

Edit `values.yaml` with your credentials:

```bash
# Make a backup first
cp values.yaml values.yaml.backup

# Edit the file
vi values.yaml
```

Update these fields:
```yaml
groupName: "acme.example.com"  # Your domain

issuers:
  - name: ovh-cluster-issuer
    email: admin@example.com  # Your email
    ovhAuthentication:
      applicationKey: "YOUR_APPLICATION_KEY_HERE"
      applicationSecret: "YOUR_APPLICATION_SECRET_HERE"
      applicationConsumerKey: "YOUR_CONSUMER_KEY_HERE"
```

## OVH API Endpoints

Choose the endpoint based on your account region:

| Region | Endpoint Name | API URL |
|--------|---------------|---------|
| Europe | `ovh-eu` | `https://eu.api.ovh.com/1.0` |
| Canada | `ovh-ca` | `https://ca.api.ovh.com/1.0` |
| United States | `ovh-us` | `https://api.us.ovhcloud.com/1.0` |

**Check your endpoint:**
```bash
# Test API access
curl https://eu.api.ovh.com/1.0/domain/zone/example.com
```

## Installation

### Step 1: Verify Prerequisites

```bash
# Check cert-manager is running
kubectl -n cert-manager get pods

# Verify cert-manager CRDs
kubectl get crd | grep cert-manager
```

### Step 2: Add Helm Repository

```bash
# Add OVH webhook repository
helm repo add cert-manager-webhook-ovh-charts \
  https://aureq.github.io/cert-manager-webhook-ovh/

# Update repositories
helm repo update
```

### Step 3: Install Webhook

```bash
# Install with your customized values
helm upgrade --install \
  --namespace cert-manager \
  -f values.yaml \
  cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh
```

**What this does:**
- Deploys webhook pod in cert-manager namespace
- Creates OVH DNS solver for cert-manager
- Creates ClusterIssuer (if configured in values)
- Stores OVH credentials as Secret

### Step 4: Verify Installation

```bash
# Check webhook pod is running
kubectl -n cert-manager get pods -l app.kubernetes.io/name=cert-manager-webhook-ovh

# Verify ClusterIssuer was created
kubectl get clusterissuer

# Check ClusterIssuer status
kubectl describe clusterissuer ovh-cluster-issuer
```

**Expected ClusterIssuer status:**
```yaml
Status:
  Acme:
    Uri: https://acme-v02.api.letsencrypt.org/acme/acct/XXXXXXXX
  Conditions:
    Status: True
    Type:   Ready
```

If `Ready: True`, you're all set! ✅

If `Ready: False`, see [Troubleshooting](#troubleshooting).

## Testing the Setup

### Create a Test Certificate

```yaml
# test-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: default
spec:
  secretName: test-certificate-tls
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - test.example.com  # Change to your domain
```

Deploy and watch:

```bash
# Create certificate
kubectl apply -f test-certificate.yaml

# Watch status (this takes 1-3 minutes)
kubectl get certificate test-certificate -w

# Check detailed status
kubectl describe certificate test-certificate
```

**Certificate lifecycle:**

1. **Pending** (0-10s): cert-manager starts ACME challenge
2. **DNS record creation** (10-30s): Webhook creates TXT record at OVH
3. **Validation** (30s-2m): Let's Encrypt validates DNS record
4. **Issued** (2-3m): Certificate stored in Secret
5. **Ready** (3m): Certificate active

### Verify DNS Record

While the certificate is pending, the webhook creates a validation record:

```bash
# Check for ACME challenge TXT record
dig _acme-challenge.test.example.com TXT

# Or using online tools
# https://dnschecker.org/#TXT/_acme-challenge.test.example.com
```

**Expected output:**
```
_acme-challenge.test.example.com. 60 IN TXT "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

This record is automatically deleted after validation completes.

### Check Certificate Secret

Once issued:

```bash
# View certificate secret
kubectl get secret test-certificate-tls

# Inspect certificate details
kubectl get secret test-certificate-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

**Look for:**
- **Issuer**: R10 (Let's Encrypt)
- **Valid dates**: Check start and expiry
- **DNS names**: Should match your dnsNames

## Creating Wildcard Certificates

Wildcard certificates cover all subdomains: `*.example.com`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-example-com
  namespace: default
spec:
  secretName: wildcard-example-com-tls
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - example.com       # Root domain
    - "*.example.com"   # All subdomains
```

**Use cases:**
- Multiple apps on subdomains: `app1.example.com`, `app2.example.com`
- Staging environments: `*.staging.example.com`
- Development: `*.dev.example.com`

**Limitations:**
- Doesn't cover second-level: `*.example.com` ≠ `sub.app.example.com`
- For that, you need: `*.app.example.com`

## Using Certificates in IngressRoutes

### Traefik IngressRoute Example

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: default
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
    secretName: app-example-com-tls  # Certificate secret name
```

### Automatic Certificate Creation

You can create IngressRoute and Certificate together:

```yaml
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
    - port: 80

---
# Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-cert
spec:
  secretName: my-app-tls
  issuerRef:
    name: ovh-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - app.example.com

---
# IngressRoute
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
        - name: my-app
          port: 80
  tls:
    secretName: my-app-tls
```

## Configuration Options

### Use Let's Encrypt Staging

For testing (issues untrusted certificates but has higher rate limits):

```yaml
issuers:
  - name: ovh-cluster-issuer-staging
    acmeServerUrl: https://acme-staging-v02.api.letsencrypt.org/directory
    # ... rest of config
```

**When to use staging:**
- Initial setup and testing
- Developing new IngressRoutes
- Frequent certificate recreation
- Avoiding rate limits (50 certs/week on production)

### Multiple Domains

Create separate issuers for different domains:

```yaml
issuers:
  # First domain
  - name: example-com-issuer
    email: admin@example.com
    # ... OVH credentials for example.com

  # Second domain
  - name: another-com-issuer
    email: admin@another.com
    # ... OVH credentials for another.com
```

### Custom Certificate Duration

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-cert
spec:
  duration: 2160h        # 90 days (Let's Encrypt max)
  renewBefore: 720h      # Renew 30 days before expiry
  # ... rest of spec
```

**cert-manager renewal behavior:**
- Checks certificates daily
- Renews when `renewBefore` threshold is reached
- Retries on failure with exponential backoff

## Troubleshooting

### ClusterIssuer Not Ready

```bash
# Check ClusterIssuer status
kubectl describe clusterissuer ovh-cluster-issuer

# Look for error conditions
kubectl get clusterissuer ovh-cluster-issuer -o yaml
```

**Common issues:**

1. **Invalid credentials**
   - Error: `Failed to register ACME account`
   - Fix: Verify applicationKey, applicationSecret, and consumerKey

2. **Wrong endpoint**
   - Error: `HTTP 404` or connection errors
   - Fix: Check `ovhEndpointName` matches your region

3. **Insufficient permissions**
   - Error: `403 Forbidden`
   - Fix: Recreate OVH API token with proper rights

### Certificate Stuck in Pending

```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>

# Check ACME order
kubectl get order
kubectl describe order <order-name>

# Check challenge
kubectl get challenge
kubectl describe challenge <challenge-name>
```

**Challenge states:**

- **Pending**: DNS record being created
- **Processing**: Let's Encrypt validating
- **Valid**: Challenge succeeded
- **Invalid**: Challenge failed

### DNS Record Not Created

```bash
# Check webhook logs
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh

# Look for OVH API errors
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager-webhook-ovh | grep -i error
```

**Common issues:**

1. **DNS zone not found**
   - Error: `Zone not found`
   - Fix: Ensure domain is managed by OVH

2. **API rate limiting**
   - Error: `Too many requests`
   - Fix: Wait and retry, or contact OVH support

3. **Expired consumer key**
   - Error: `Invalid signature` or `401 Unauthorized`
   - Fix: Generate new consumer key

### DNS Propagation Timeout

```bash
# Check cert-manager logs for propagation errors
kubectl -n cert-manager logs -l app=cert-manager | grep -i propagation

# Manually check DNS
dig @8.8.8.8 _acme-challenge.example.com TXT
```

**Fixes:**

1. **Increase timeout** (in cert-manager config):
```yaml
extraArgs:
  - --dns01-check-retry-period=30s  # Default is 10s
```

2. **Use different nameservers**:
```yaml
extraArgs:
  - --dns01-recursive-nameservers=9.9.9.9:53,1.1.1.1:53
```

### Certificate Failed

```bash
# Check why it failed
kubectl describe certificate <cert-name>

# Check cert-manager logs
kubectl -n cert-manager logs -l app=cert-manager --tail=100
```

**Common failures:**

1. **Rate limit exceeded**
   - Error: `too many certificates already issued`
   - Fix: Use staging issuer, or wait (limits reset weekly)

2. **CAA records**
   - Error: `CAA record forbids issuance`
   - Fix: Add CAA record allowing Let's Encrypt

3. **Invalid DNS name**
   - Error: `DNS name does not match`
   - Fix: Verify dnsNames are correct

## Debug Mode

Enable verbose logging:

```bash
# For cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager \
  --set logLevel=6

# For webhook (reinstall with debug)
helm upgrade --install cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh \
  -n cert-manager \
  -f values.yaml \
  --set logLevel=debug
```

## Updating

```bash
# Update repository
helm repo update

# Upgrade webhook
helm upgrade cm-webhook-ovh \
  cert-manager-webhook-ovh-charts/cert-manager-webhook-ovh \
  -n cert-manager \
  -f values.yaml

# Verify upgrade
kubectl -n cert-manager get pods -l app.kubernetes.io/name=cert-manager-webhook-ovh
```

## Uninstalling

```bash
# Delete all certificates using this issuer first
kubectl delete certificate -l issuer=ovh-cluster-issuer -A

# Uninstall webhook
helm uninstall cm-webhook-ovh -n cert-manager

# Delete ClusterIssuer
kubectl delete clusterissuer ovh-cluster-issuer

# Delete secrets (optional)
kubectl -n cert-manager delete secret ovh-credentials
```

## Security Best Practices

### Credential Management

1. **Use Sealed Secrets**:
```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal your secret
kubectl create secret generic ovh-credentials \
  --from-literal=applicationKey=xxx \
  --from-literal=applicationSecret=yyy \
  --from-literal=consumerKey=zzz \
  -n cert-manager \
  --dry-run=client -o yaml | \
kubeseal -o yaml > sealed-ovh-credentials.yaml

# Apply sealed secret (safe to commit to Git)
kubectl apply -f sealed-ovh-credentials.yaml
```

2. **Use External Secrets Operator**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: cert-manager
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      # ... vault config
```

3. **Rotate keys regularly**:
   - Generate new OVH API keys every 6-12 months
   - Update Secret and rollout webhook

### Network Security

1. **Restrict webhook access**:
```yaml
# NetworkPolicy for webhook
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cert-manager-webhook-ovh
  namespace: cert-manager
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: cert-manager-webhook-ovh
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: cert-manager
```

2. **Use least privilege**:
   - Grant OVH API access only to specific zones
   - Use separate credentials per cluster

## Monitoring

### Watch Certificate Status

```bash
# List all certificates
kubectl get certificate -A

# Check expiry dates
kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.notAfter}{"\n"}{end}'

# Monitor renewals
kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.renewalTime}{"\n"}{end}'
```

### Prometheus Alerts

```yaml
# Alert on certificate expiring soon
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < (21 * 24 * 3600)
  for: 1h
  annotations:
    summary: "Certificate {{ $labels.name }} expires in less than 21 days"

# Alert on certificate not ready
- alert: CertificateNotReady
  expr: certmanager_certificate_ready_status == 0
  for: 15m
  annotations:
    summary: "Certificate {{ $labels.name }} is not ready"
```

## Next Steps

1. **Create production certificates**: Issue certificates for your services
2. **Set up wildcard cert**: Cover all subdomains with one certificate
3. **Configure monitoring**: Alert on certificate issues
4. **Document your domains**: Keep track of what certificates you have
5. **Plan for disaster recovery**: Backup important certificates

## References

- **OVH Webhook GitHub**: https://github.com/aureq/cert-manager-webhook-ovh
- **OVH API Documentation**: https://docs.ovh.com/gb/en/customer/first-steps-with-ovh-api/
- **cert-manager DNS-01**: https://cert-manager.io/docs/configuration/acme/dns01/
- **Let's Encrypt Rate Limits**: https://letsencrypt.org/docs/rate-limits/
- **Complete Setup Guide**: [../../docs/ingress-controller.md](../../docs/ingress-controller.md)

## Support

For issues specific to this homelab setup, see the main [ingress controller documentation](../../docs/ingress-controller.md#troubleshooting).

For OVH webhook issues, check the [GitHub repository](https://github.com/aureq/cert-manager-webhook-ovh/issues).
