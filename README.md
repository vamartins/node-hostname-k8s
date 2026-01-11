# Node Hostname - Kubernetes Platform Engineering Project

[![Azure Infrastructure](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-infrastructure.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-infrastructure.yaml)
[![Azure Deploy](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-deploy.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/azure-deploy.yaml)
[![Docker](https://img.shields.io/docker/v/almevag/node-hostname?label=Docker)](https://hub.docker.com/r/almevag/node-hostname)

**Complete Platform Engineering solution** for containerized NodeJS applications with automated infrastructure (Terraform), CI/CD pipelines, and production-ready deployment to Azure AKS.

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Security & Secrets](#-security--secrets)
- [CI/CD Pipelines](#-cicd-pipelines)
- [Local Development](#-local-development)
- [Versioning](#-versioning)
- [Troubleshooting](#-troubleshooting)

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
- **LoadBalancer Services** - Public IPs for each environment
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
- 🌐 **LoadBalancer** - Public IP per environment
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

### 4. Create Infrastructure

Go to: **GitHub Actions → Azure Infrastructure Setup → Run workflow**
- **Action**: `apply`

This creates:
- Resource Group: `rg-node-hostname`
- AKS Cluster: `aks-node-hostname` (1 node, B2s)
- Namespace: `node-hostname-staging`
- Namespace: `node-hostname-production`

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

```bash
# Get cluster credentials
az aks get-credentials --resource-group rg-node-hostname --name aks-node-hostname

# Get staging IP
kubectl get svc -n node-hostname-staging

# Get production IP
kubectl get svc -n node-hostname-production

# Test
curl http://<STAGING_IP>
curl http://<PRODUCTION_IP>
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
│   ├── values-staging.yaml         # Staging: 2 replicas, develop tag
│   ├── values-production.yaml      # Production: 3 replicas, latest tag
│   └── templates/                  # Kubernetes manifests
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── hpa.yaml
│       └── ...
├── scripts/
│   ├── create-cluster.sh           # Local Kind cluster (dev only)
│   ├── deploy-local.sh             # Local deployment (dev only)
│   └── cleanup.sh                  # Delete local cluster
├── Dockerfile                      # Multi-stage build with versioning
├── .env.example                    # Environment variables template
└── README.md
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
4. Label namespaces with environment tags
5. Output cluster info

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
- **Tag**: `develop`
- **Approval**: None (automatic)

#### 4. Deploy Production
- **Trigger**: Manual workflow dispatch
- **Namespace**: `node-hostname-production`
- **Replicas**: 3
- **Tag**: `<version from Dockerfile>`
- **Approval**: Required (GitHub environment)

**Outputs:**
- LoadBalancer public IP
- Deployment status
- Pod/service information

---

## 💻 Local Development

For local testing without Azure costs:

### 1. Create Local Kind Cluster

```bash
./scripts/create-cluster.sh
```

Creates:
- 3-node Kind cluster (1 control-plane + 2 workers)
- Port mappings: 8080 (staging), 9080 (production)
- metrics-server

### 2. Deploy Locally

```bash
# Staging
./scripts/deploy-local.sh staging

# Production
./scripts/deploy-local.sh production
```

### 3. Access

```bash
curl http://localhost:8080  # Staging
curl http://localhost:9080  # Production
```

### 4. Cleanup

```bash
./scripts/cleanup.sh
```

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
# Get LoadBalancer IPs
STAGING_IP=$(kubectl get svc node-hostname-staging -n node-hostname-staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
PROD_IP=$(kubectl get svc node-hostname-production -n node-hostname-production -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test staging
curl http://$STAGING_IP
# {"hostname":"node-hostname-staging-abc123","version":"develop"}

# Test production
curl http://$PROD_IP
# {"hostname":"node-hostname-production-xyz789","version":"1.0.0"}
```

### Load Testing

```bash
# Generate load to trigger HPA
kubectl run -it --rm load-generator --image=busybox /bin/sh

# Inside pod:
while true; do wget -q -O- http://node-hostname-staging.node-hostname-staging.svc.cluster.local; done

# Watch HPA scale
kubectl get hpa -n node-hostname-staging --watch
```

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

### LoadBalancer Pending

Azure may take 2-3 minutes to provision public IP:
```bash
kubectl get svc -n <namespace> --watch
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

---

## 📝 License

MIT License - See LICENSE file for details

---

## 👤 Author

**Vagner Martins**
- GitHub: [@vamartins](https://github.com/vamartins)
- Docker Hub: [vamartins](https://hub.docker.com/u/vamartins)
