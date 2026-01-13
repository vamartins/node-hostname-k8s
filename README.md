# Node Hostname - Kubernetes Platform Engineering Project

[![Azure Infrastructure](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-infrastructure.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-infrastructure.yaml)
[![Azure Deploy](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-deploy.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-deploy.yaml)
[![Docker](https://img.shields.io/docker/v/almevag/node-hostname?label=Docker)](https://hub.docker.com/r/almevag/node-hostname)

**Complete Platform Engineering solution** for containerized NodeJS applications with automated infrastructure (Terraform), CI/CD pipelines, and production-ready deployment to Azure AKS.

---

## 📖 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Security & Secrets](#security--secrets)
- [CI/CD Pipelines](#cicd-pipelines)
- [Local Development](#local-development)
- [Versioning](#versioning)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project demonstrates a **complete Platform Engineering workflow** for deploying containerized applications to Azure Kubernetes Service (AKS) with:
- Infrastructure as Code (Terraform)
- Automated CI/CD (GitHub Actions)
- Multi-environment deployment (Staging + Production in same cluster)
- Namespace isolation
- Production approval gates

---

## 🏗️ Architecture

### Infrastructure
- **1 Azure AKS Cluster** (1 node, Standard_B2s)
- **2 Namespaces**: 
  - `node-hostname-staging` - Auto-deploy from develop branch
  - `node-hostname-production` - Manual deploy with approval
- **NGINX Ingress Controller** - Single LoadBalancer for all environments
- **cert-manager** - Automatic TLS certificate management
- **ClusterIP Services** - Internal services exposed via Ingress
- **Horizontal Pod Autoscaler** - CPU-based scaling

### Deployment Flow
```
┌─────────────┐
│   develop   │ ──push──> Staging (auto)
└─────────────┘
       │
       │ manual trigger
       ▼
┌─────────────┐
│     main    │ ──approval──> Production (manual)
└─────────────┘
```

---

## ✨ Features

### Infrastructure
- 🏗️ **Terraform IaC** - Azure AKS with single cluster
- 🔐 **Namespace Isolation** - Staging & Production separated
- 🌐 **NGINX Ingress** - Single LoadBalancer with host-based routing
- 🔒 **TLS/HTTPS** - Self-signed certificates via cert-manager
- 📊 **Metrics** - HPA for auto-scaling
- 💰 **Cost-Optimized** - 1 node B2s (~$7.59/month)

### Application
- 🐳 **Containerized** - Multi-stage Docker build
- 🔒 **Secure** - Non-root user, security contexts
- 📦 **Helm Charts** - Production-ready deployment
- 🚀 **Load Balanced** - Multiple replicas
- ✅ **Health Checks** - Liveness/readiness probes
- 🏷️ **Versioned** - Semantic versioning via Dockerfile

### CI/CD
- 🛠️ **Infrastructure Pipeline** - Single cluster + 2 namespaces
- 🚢 **Deployment Pipeline** - Auto staging, manual production
- ✋ **Approvals** - GitHub environment protection
- 🔒 **Secrets Management** - GitHub Secrets for credentials

---

## 📋 Prerequisites

### Required Tools
- Azure CLI (`az`)
- Terraform 1.6+
- kubectl
- helm 3.0+
- Docker

### Required Accounts
- Azure subscription (with Contributor role)
- Docker Hub account
- GitHub account

### Local Development Only
- Docker Desktop
- Kind (for local Kubernetes)

---

## 🚀 Quick Start

### 1. Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "sp-node-hostname" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

Save the output JSON - you'll need these values:
- `clientId` → AZURE_CLIENT_ID
- `clientSecret` → AZURE_CLIENT_SECRET  
- `subscriptionId` → AZURE_SUBSCRIPTION_ID
- `tenantId` → AZURE_TENANT_ID

### 2. Configure GitHub Secrets

Navigate to: **GitHub Repository → Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | Service Principal App ID |
| `AZURE_CLIENT_SECRET` | Service Principal Password |
| `AZURE_SUBSCRIPTION_ID` | Your Azure Subscription ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token |

> ⚠️ **NEVER commit these credentials to Git!** Always use GitHub Secrets, `.env` files (Git-ignored), or Azure Key Vault.

### 3. Configure Production Approval

Navigate to: **GitHub Repository → Settings → Environments**

Create environment: `production`
- Enable "Required reviewers"
- Add yourself as reviewer

> ⚠️ **Important:** The environment name must be exactly `production` (lowercase) to match the workflow configuration.

**Verification:**
1. Go to repository Settings → Environments
2. Ensure `production` environment exists
3. Verify "Required reviewers" is enabled with at least one reviewer
4. When triggering the workflow manually, it will wait for approval before deploying

### 4. Create Infrastructure

Go to: **GitHub Actions → Azure Infrastructure Setup → Run workflow**
- **Action**: `apply`

This creates:
- Resource Group: `rg-node-hostname`
- AKS Cluster: `aks-node-hostname` (1 node, B2s)
- Namespace: `node-hostname-staging`
- Namespace: `node-hostname-production`
- NGINX Ingress Controller (with LoadBalancer)
- cert-manager v1.13.3
- ClusterIssuer (selfsigned-issuer)

### 5. Deploy to Staging (Automatic)

```bash
git checkout develop
# Make a change or empty commit
git commit --allow-empty -m "trigger staging deploy"
git push origin develop
```

Pipeline automatically:
1. Builds Docker image with `develop` tag
2. Deploys to `node-hostname-staging` namespace
3. Outputs LoadBalancer IP

### 6. Deploy to Production (Manual)

Go to: **GitHub Actions → Deploy to Azure AKS → Run workflow**
- Select branch: `main`
- Approve when prompted

Pipeline:
1. Builds Docker image with version from Dockerfile
2. Waits for manual approval
3. Deploys to `node-hostname-production` namespace
4. Outputs LoadBalancer IP

### 7. Access Applications

#### Get NGINX Ingress IP

```bash
# Get cluster credentials
az aks get-credentials --resource-group rg-node-hostname --name aks-node-hostname

# Get NGINX Ingress Controller IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP (e.g., 132.220.152.131)
```

#### Configure /etc/hosts (For Browser Access)

Add this line to your `/etc/hosts` file:

**macOS/Linux:**
```bash
echo "132.220.152.131 staging.node-hostname.local production.node-hostname.local" | sudo tee -a /etc/hosts
```

**Windows (PowerShell as Administrator):**
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "132.220.152.131 staging.node-hostname.local production.node-hostname.local"
```

> Replace `132.220.152.131` with your actual NGINX Ingress EXTERNAL-IP

#### Access via Browser

- **Staging HTTP:** http://staging.node-hostname.local
- **Staging HTTPS:** https://staging.node-hostname.local (self-signed certificate warning expected)
- **Production HTTP:** http://production.node-hostname.local
- **Production HTTPS:** https://production.node-hostname.local (self-signed certificate warning expected)

> ⚠️ **Certificate Warning:** Self-signed certificates will show a browser warning. Click "Advanced" → "Accept Risk" to proceed.

#### Access via curl (Without /etc/hosts)

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Staging HTTP
curl -H "Host: staging.node-hostname.local" http://$INGRESS_IP

# Staging HTTPS (self-signed cert)
curl -k -H "Host: staging.node-hostname.local" https://$INGRESS_IP

# Production HTTP
curl -H "Host: production.node-hostname.local" http://$INGRESS_IP

# Production HTTPS (self-signed cert)
curl -k -H "Host: production.node-hostname.local" https://$INGRESS_IP
```

#### Test Load Balancing

```bash
# 20 requests to staging
for i in {1..20}; do curl -s -H "Host: staging.node-hostname.local" http://$INGRESS_IP; done | sort | uniq -c

# Expected output shows distribution across multiple pods:
#   10 {"hostname":"node-hostname-staging-abc123","version":"1.0.0"}
#   10 {"hostname":"node-hostname-staging-xyz789","version":"1.0.0"}
```

---

## 📁 Project Structure

```
.
├── .github/workflows/
│   ├── azure-infrastructure.yaml   # Create AKS + namespaces
│   └── azure-deploy.yaml           # Deploy staging/production
├── terraform/azure/
│   ├── main.tf                     # AKS cluster (1 node)
│   ├── variables.tf                # Configuration variables
│   ├── outputs.tf                  # Cluster info outputs
│   └── provider.tf                 # Azure provider
├── helm/node-hostname/
│   ├── Chart.yaml                  # Helm chart metadata
│   ├── values.yaml                 # Default values
│   ├── values-local.yaml           # Local Kind: 2-5 replicas, HPA enabled
│   ├── values-staging.yaml         # Staging: 2 replicas, develop-<sha> tag
│   ├── values-production.yaml      # Production: 3 replicas, versioned tag
│   └── templates/                  # Kubernetes manifests
│       ├── deployment.yaml         # Deployment with health checks
│       ├── service.yaml            # ClusterIP service
│       ├── ingress.yaml            # Ingress with TLS
│       ├── hpa.yaml                # Horizontal Pod Autoscaler
│       └── serviceaccount.yaml     # Service account
├── scripts/
│   ├── create-cluster.sh           # Create local Kind cluster (3 nodes)
│   ├── deploy-local.sh             # Deploy to local Kind with Ingress
│   └── cleanup.sh                  # Delete local Kind cluster
├── app/
│   └── index.js                    # Node.js application
├── Dockerfile                      # Multi-stage build with versioning
├── .dockerignore                   # Docker build exclusions
├── .gitignore                      # Git exclusions
└── README.md                       # This file
```

---

## 🔒 Security & Secrets

### ⚠️ Never Commit These Files:
- `.env` - Local environment variables
- `*.tfstate` - Terraform state
- `kubeconfig` - Kubernetes credentials
- Service Principal secrets

### Local Development (.env)

Create `.env` file (Git-ignored):
```bash
# Azure credentials
export ARM_CLIENT_ID="your-sp-client-id"
export ARM_CLIENT_SECRET="your-sp-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Docker Hub
export DOCKER_USERNAME="your-docker-username"
export DOCKER_PASSWORD="your-docker-password"
```

Load before Terraform:
```bash
source .env
cd terraform/azure
terraform init
terraform plan
```

### GitHub Actions

Store all credentials as **GitHub Secrets** in repository settings.

### Azure Key Vault (Production Recommended)

```bash
# Create Key Vault
az keyvault create \
  --name kv-node-hostname \
  --resource-group rg-node-hostname \
  --location eastus

# Store secrets
az keyvault secret set \
  --vault-name kv-node-hostname \
  --name docker-password \
  --value "your-token"
```

---

## 🔄 CI/CD Pipelines

### Pipeline 1: Azure Infrastructure Setup

**File:** [.github/workflows/azure-infrastructure.yaml](.github/workflows/azure-infrastructure.yaml)

**Trigger:** Manual (workflow_dispatch)

**Purpose:** Create or destroy AKS infrastructure

**Actions:**
- `apply` - Create cluster + namespaces
- `destroy` - Delete all resources

**Steps:**
1. Terraform init/validate/plan
2. Terraform apply/destroy
3. Create namespaces (staging + production)
4. Install NGINX Ingress Controller
5. Install cert-manager v1.13.3
6. Create ClusterIssuer (selfsigned-issuer)
7. Label namespaces with environment tags
8. Output cluster info

**Required Secrets:** All Azure credentials

---

### Pipeline 2: Deploy to Azure AKS

**File:** [.github/workflows/azure-deploy.yaml](.github/workflows/azure-deploy.yaml)

**Triggers:**
- **Automatic**: Push to `develop` → Staging
- **Manual**: Workflow dispatch → Production (with approval)

**Jobs:**

#### 1. Lint and Test
- Lint Dockerfile (hadolint)
- Validate Helm chart

#### 2. Build and Push
- Extract version from Dockerfile
- Build multi-stage Docker image
- Push to Docker Hub with tags:
  - `develop` (staging)
  - `<version>` (production)

#### 3. Deploy Staging
- **Trigger**: Push to develop
- **Namespace**: `node-hostname-staging`
- **Replicas**: 2
- **Tag**: `develop-<sha>` (unique per commit)
- **Approval**: None (automatic)
- **Access**: http://staging.node-hostname.local

#### 4. Deploy Production
- **Trigger**: Manual workflow dispatch
- **Namespace**: `node-hostname-production`
- **Replicas**: 3
- **Tag**: `<version from Dockerfile>`
- **Approval**: Required (GitHub environment)
- **Access**: http://production.node-hostname.local
- **GitHub Release**: Automatically created with version tag

**Outputs:**
- NGINX Ingress LoadBalancer IP
- Deployment status
- Pod/service information
- Ingress configuration details

---

## 💻 Local Development

For local testing without Azure costs, using Kind cluster with full Ingress support:

### 1. Create Local Kind Cluster

```bash
./scripts/create-cluster.sh
```

Creates:
- 3-node Kind cluster (1 control-plane + 2 workers)
- Port mappings:
  - 30080 → localhost:8080 (staging)
  - 31080 → localhost:9080 (production)
  - 30443 → localhost:8443 (staging HTTPS)
  - 31443 → localhost:9443 (production HTTPS)
- metrics-server for HPA

### 2. Deploy Locally

```bash
# Staging (2 replicas)
./scripts/deploy-local.sh staging

# Production (3 replicas)
./scripts/deploy-local.sh production
```

The script automatically:
- Installs NGINX Ingress Controller (NodePort 31080/31443)
- Installs cert-manager with self-signed ClusterIssuer
- Builds and loads Docker image into Kind
- Deploys application with Helm using values-local.yaml
- Sets up Ingress with catch-all host (accessible via localhost)

### 3. Access and Test Load Balancing

```bash
# Single request
curl http://localhost:9080  # Production
curl http://localhost:8080  # Staging

# Test load balancing (see different pod hostnames)
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s http://localhost:9080; echo ""; done

# Or open in browser and refresh multiple times
open http://localhost:9080
```

**Load Balancing:** With Ingress enabled, requests are distributed across all pods. Each refresh shows a different pod hostname.

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n node-hostname

# Check ingress
kubectl get ingress -n node-hostname

# Check NGINX Ingress Controller
kubectl get svc -n ingress-nginx

# View logs
kubectl logs -f deployment/node-hostname-production -n node-hostname
```

### 5. Test HPA Auto-Scaling (Optional)

The local deployment includes Horizontal Pod Autoscaler (HPA) for testing auto-scaling behavior:

```bash
# Check current HPA status
kubectl get hpa -n node-hostname

# Generate load to trigger scaling (in one terminal)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -n node-hostname -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://node-hostname-production; done"

# Watch HPA and pods scale up (in another terminal)
kubectl get hpa -n node-hostname --watch
# Or watch pods
kubectl get pods -n node-hostname --watch
```

**Expected behavior:**
- Starts with **minReplicas: 2**
- Scales up to **maxReplicas: 5** when CPU > 70%
- Scales down automatically after load stops (takes ~5 minutes)

Press `Ctrl+C` to stop the load generator.

### 6. Cleanup

```bash
./scripts/cleanup.sh
```

Deletes the entire Kind cluster and all resources.

---

## 🏷️ Versioning

### Version Management

Version is defined **once** in Dockerfile:

```dockerfile
ARG APP_VERSION=1.0.0
```

Pipeline automatically:
1. Extracts version: `grep -m1 "ARG APP_VERSION="`
2. Tags image: `almevag/node-hostname:1.0.0`
3. Deploys with that version

### Update Version

```bash
# 1. Edit Dockerfile
sed -i '' 's/APP_VERSION=1.0.0/APP_VERSION=2.0.0/' Dockerfile

# 2. Commit and push to develop (triggers staging)
git add Dockerfile
git commit -m "chore: bump version to 2.0.0"
git push origin develop

# 3. After testing, promote to production
git checkout main
git merge develop
git push origin main

# 4. Manually trigger production deploy in GitHub Actions
```

---

## 🧪 Testing

### Verify Deployment

```bash
# Get cluster credentials
az aks get-credentials \
  --resource-group rg-node-hostname \
  --name aks-node-hostname

# Check pods
kubectl get pods -n node-hostname-staging
kubectl get pods -n node-hostname-production

# Check services
kubectl get svc -n node-hostname-staging
kubectl get svc -n node-hostname-production

# Check HPA
kubectl get hpa -A
```

### Test Application

```bash
# Get NGINX Ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test staging (HTTP)
curl -H "Host: staging.node-hostname.local" http://$INGRESS_IP
# {"hostname":"node-hostname-staging-abc123","version":"1.0.0"}

# Test staging (HTTPS with self-signed cert)
curl -k -H "Host: staging.node-hostname.local" https://$INGRESS_IP
# {"hostname":"node-hostname-staging-abc123","version":"1.0.0"}

# Test production (HTTP)
curl -H "Host: production.node-hostname.local" http://$INGRESS_IP
# {"hostname":"node-hostname-production-xyz789","version":"1.0.0"}

# Test production (HTTPS with self-signed cert)
curl -k -H "Host: production.node-hostname.local" https://$INGRESS_IP
# {"hostname":"node-hostname-production-xyz789","version":"1.0.0"}
```

### Verify TLS Certificates

```bash
# Check cert-manager is running
kubectl get pods -n cert-manager

# Check ClusterIssuer
kubectl get clusterissuer
# NAME                READY   AGE
# selfsigned-issuer   True    10m

# Check certificates
kubectl get certificate -n node-hostname-staging
kubectl get certificate -n node-hostname-production

# Describe certificate (staging)
kubectl describe certificate -n node-hostname-staging

# View TLS secret
kubectl get secret node-hostname-tls-staging -n node-hostname-staging -o yaml
```

### Load Testing

```bash
# Generate load to trigger HPA
kubectl run -it --rm load-generator --image=busybox -n node-hostname-staging /bin/sh

# Inside pod:
while true; do wget -q -O- http://node-hostname-staging.node-hostname-staging.svc.cluster.local; done

# Watch HPA scale
kubectl get hpa -n node-hostname-staging --watch
```

---

## 🌐 Networking Architecture

### NGINX Ingress Flow

```
Internet
   │
   └─► NGINX Ingress Controller (LoadBalancer)
        └─► IP: 132.220.152.131
             │
             ├─► staging.node-hostname.local ──► ClusterIP Service ──► Staging Pods (2)
             │                                    └─► TLS: node-hostname-tls-staging
             │
             └─► production.node-hostname.local ──► ClusterIP Service ──► Production Pods (3)
                                                     └─► TLS: node-hostname-tls-production
```

### Key Changes from LoadBalancer Architecture

**Before (LoadBalancer per namespace):**
- ❌ 2 Public IPs (1 per environment) = Higher cost
- ❌ No TLS/HTTPS support
- ❌ Direct Service exposure
- ✅ Simple configuration

**After (Single NGINX Ingress):**
- ✅ 1 Public IP (shared) = Lower cost
- ✅ TLS/HTTPS with cert-manager
- ✅ Host-based routing
- ✅ Advanced features (rate limiting, CORS, rewrites)
- ⚠️ Requires /etc/hosts or DNS configuration

### Service Types

| Environment | Service Type | Ingress | TLS |
|-------------|--------------|---------|-----|
| Staging | ClusterIP | ✅ Enabled | ✅ Self-signed |
| Production | ClusterIP | ✅ Enabled | ✅ Self-signed |

---

## 🔒 TLS/HTTPS Configuration

### cert-manager

Automatically manages TLS certificates:
- **Type:** Self-signed (via selfsigned-issuer)
- **Renewal:** Automatic (90 days before expiry)
- **Namespaces:** Per-environment certificates

### Certificate Details

```bash
# View certificate expiry
kubectl get certificate -n node-hostname-staging -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter

# Extract and inspect certificate
kubectl get secret node-hostname-tls-staging -n node-hostname-staging -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Browser Certificate Warning

Self-signed certificates will show:
- Chrome: "Your connection is not private" (NET::ERR_CERT_AUTHORITY_INVALID)
- Firefox: "Warning: Potential Security Risk Ahead"

**To bypass:**
1. Click "Advanced"
2. Click "Proceed to staging.node-hostname.local (unsafe)" or similar

### Production TLS (Let's Encrypt)

For production with valid certificates, replace `selfsigned-issuer` with Let's Encrypt:

```yaml
# ClusterIssuer with Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

> Requires: Real domain name + DNS pointing to Ingress IP

---

## 🔧 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### ImagePullBackOff

Check Docker Hub credentials:
```bash
kubectl get secret -n <namespace>
```

### Ingress 404 Not Found

Check Ingress configuration:
```bash
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Verify host header
curl -v -H "Host: staging.node-hostname.local" http://<INGRESS-IP>
```

### TLS Certificate Not Ready

```bash
# Check certificate status
kubectl get certificate -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer selfsigned-issuer
```

### NGINX Ingress Controller Issues

```bash
# Check NGINX controller pods
kubectl get pods -n ingress-nginx

# View NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check LoadBalancer service
kubectl get svc -n ingress-nginx
```

### /etc/hosts Not Working

Verify:
```bash
# macOS/Linux - Check hosts file
cat /etc/hosts | grep node-hostname

# Test DNS resolution
ping staging.node-hostname.local

# Bypass with curl
curl -H "Host: staging.node-hostname.local" http://<INGRESS-IP>
```

### Terraform State Lock

```bash
cd terraform/azure
terraform force-unlock <LOCK_ID>
```

### Pipeline Failures

Check GitHub Actions logs:
- Terraform errors → Azure permissions
- Docker build → Dockerfile syntax
- Helm errors → values-*.yaml syntax

---

## 🧹 Cleanup

### Delete AKS Cluster

Go to: **GitHub Actions → Azure Infrastructure Setup → Run workflow**
- **Action**: `destroy`

Or manually:
```bash
cd terraform/azure
source .env
terraform destroy -auto-approve
```

### Delete Local Cluster

```bash
./scripts/cleanup.sh
```

---

## 📚 Additional Resources

- [Azure AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

---

## 📝 License

MIT License - See LICENSE file for details

---

## 👤 Author

**Vagner Martins**
- GitHub: [@vamartins](https://github.com/vamartins)
- Docker Hub: [almevag](https://hub.docker.com/u/almevag)
