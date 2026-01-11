# Node Hostname - Kubernetes Platform Engineering Project

[![Infrastructure](https://github.com/vamartins/node-hostname-k8s/actions/workflows/infrastructure.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/infrastructure.yaml)
[![Deploy](https://github.com/vamartins/node-hostname-k8s/actions/workflows/deploy.yaml/badge.svg)](https://github.com/vamartins/node-hostname-k8s/actions/workflows/deploy.yaml)
[![Docker](https://img.shields.io/docker/v/vamartins/node-hostname?label=Docker)](https://hub.docker.com/r/vamartins/node-hostname)

**Complete Platform Engineering solution** for containerized NodeJS applications on local Kubernetes with automated infrastructure, CI/CD pipelines, and production-ready deployment patterns.

---

## 📖 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Local Development](#-local-development)
- [CI/CD Pipelines](#-cicd-pipelines)
- [Environments](#-environments)
- [Versioning & Updates](#-versioning--updates)
- [Testing](#-testing)
- [Cleanup](#-cleanup)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Features

### Infrastructure
- 🏗️ **Local Kubernetes** - Kind cluster (1 control-plane + 2 workers)
- 🔐 **HTTPS/TLS** - cert-manager with self-signed certificates
- 🌐 **Ingress** - NGINX for HTTP routing
- 📊 **Metrics** - metrics-server for HPA
- 🔄 **Auto-scaling** - Horizontal Pod Autoscaler

### Application
- 🐳 **Containerized** - Multi-stage Docker build
- 🔒 **Secure** - Non-root user, security contexts
- 📦 **Helm** - Production-ready charts
- 🚀 **Load Balanced** - Multiple replicas
- ✅ **Health Checks** - Liveness/readiness probes

### CI/CD
- 🛠️ **Infrastructure Pipeline** - Automated setup (manual trigger)
- 🚢 **Deployment Pipeline** - Auto build/test/deploy
- 🎯 **Multi-Environment** - Staging & Production
- ✋ **Approvals** - Manual approval for production
- 🏷️ **Versioning** - Semantic version support

---

## 🚀 Quick Start

### Prerequisites
- macOS with Docker Desktop running
- 4GB+ RAM available

### 1. Create Cluster
```bash
./scripts/create-cluster.sh
```

### 2. Deploy Staging
```bash
./scripts/deploy-local.sh staging
```
Access: **http://localhost:8080**

### 3. Deploy Production
```bash
./scripts/deploy-local.sh production
```
Access: **http://localhost:9080**

### 4. Cleanup
```bash
./scripts/cleanup.sh
```

---

## 📁 Project Structure

```
.
├── .github/workflows/
│   ├── infrastructure.yaml    # Infra setup (manual)
│   └── deploy.yaml            # App deployment (auto)
├── helm/node-hostname/
│   ├── Chart.yaml
│   ├── values-staging.yaml
│   ├── values-production.yaml
│   └── templates/
├── scripts/
│   ├── create-cluster.sh      # Create cluster
│   ├── deploy-local.sh        # Local deploy
│   └── cleanup.sh             # Delete everything
├── Dockerfile
└── README.md
```

---

## 💻 Local Development

### Create Cluster

```bash
./scripts/create-cluster.sh
```

**Creates:**
- 3-node Kind cluster
- Port mappings (8080/8443, 9080/9443)
- metrics-server

### Deploy Application

```bash
# Staging
./scripts/deploy-local.sh staging

# Production
./scripts/deploy-local.sh production
```

**Installs:**
- NGINX Ingress Controller
- cert-manager
- Application with Helm

### Verify

```bash
# Pods
kubectl get pods --all-namespaces | grep node-hostname

# HPA
kubectl get hpa --all-namespaces

# Test
curl http://localhost:8080  # Staging
curl http://localhost:9080  # Production
```

---

## 🔄 CI/CD Pipelines

### Pipeline 1: Infrastructure (Manual)

**File:** `.github/workflows/infrastructure.yaml`

**Purpose:** Setup Kubernetes infrastructure

**Trigger:** Manual via GitHub Actions

**Steps:**
1. Create Kind cluster
2. Install NGINX Ingress
3. Install cert-manager
4. Install metrics-server
5. Create namespaces

**Usage:**
1. GitHub → **Actions** → **Infrastructure Setup**
2. **Run workflow**
3. Select environment
4. Confirm

### Pipeline 2: Application Deployment (Auto)

**File:** `.github/workflows/deploy.yaml`

**Triggers:**
- `develop` branch → Staging (auto)
- `main` branch → Production (requires approval)
- Manual trigger

**Jobs:**
1. **lint-and-test** - Validate code
2. **build-and-push** - Build & push Docker image
3. **deploy-staging** - Deploy to staging
4. **deploy-production** - Deploy to prod (approval required)
5. **notify** - Send summary

### GitHub Setup

**1. Create Secrets:**
- Go to **Settings** → **Secrets and variables** → **Actions**
- Add:
  - `DOCKER_USERNAME` (Docker Hub username)
  - `DOCKER_PASSWORD` (Docker Hub token)

**2. Configure Production Approval:**
- Go to **Settings** → **Environments**
- Create `production` environment
- Enable **Required reviewers**
- Add reviewers
- Save

Now production deploys require approval! ✅

---

## 🌍 Environments

| Property | Staging | Production |
|----------|---------|------------|
| **Namespace** | `node-hostname-staging` | `node-hostname` |
| **HTTP Port** | 8080 | 9080 |
| **HTTPS Port** | 8443 | 9443 |
| **Replicas** | 2 | 3 |
| **Image Tag** | `develop` | `latest` |
| **HPA Min/Max** | 2-10 | 3-10 |
| **URL** | http://localhost:8080 | http://localhost:9080 |

---

## 🏷️ Versioning & Updates

### Creating a New Version

**Example: Deploy version 2.0.0**

**1. Update Dockerfile** (if needed)
```dockerfile
# Make your changes
LABEL version="2.0.0"
```

**2. Build & Push Image**
```bash
# Build
docker build -t vamartins/node-hostname:2.0.0 .
docker build -t vamartins/node-hostname:latest .

# Push
docker push vamartins/node-hostname:2.0.0
docker push vamartins/node-hostname:latest
```

**3. Deploy to Staging**
```bash
# Load to Kind
kind load docker-image vamartins/node-hostname:2.0.0 --name node-hostname

# Deploy
helm upgrade --install node-hostname-staging ./helm/node-hostname \
  --namespace node-hostname-staging \
  --values ./helm/node-hostname/values-staging.yaml \
  --set image.tag=2.0.0 \
  --wait
```

**4. Test Staging**
```bash
curl http://localhost:8080
```

**5. Deploy to Production**
```bash
# Load to Kind
kind load docker-image vamartins/node-hostname:2.0.0 --name node-hostname

# Deploy
helm upgrade --install node-hostname-production ./helm/node-hostname \
  --namespace node-hostname \
  --values ./helm/node-hostname/values-production.yaml \
  --set image.tag=2.0.0 \
  --wait
```

**6. Verify Production**
```bash
curl http://localhost:9080

# Check version
kubectl describe pod -n node-hostname | grep Image:
```

### Version via CI/CD

**1. Create Git Tag**
```bash
git tag -a v2.0.0 -m "Release 2.0.0"
git push origin v2.0.0
```

**2. Update values files**
```yaml
# helm/node-hostname/values-production.yaml
image:
  tag: "2.0.0"
```

**3. Commit & Push**
```bash
git add .
git commit -m "chore: bump version to 2.0.0"
git push origin main
```

Pipeline automatically deploys after approval!

---

## 🧪 Testing

### Basic Test
```bash
curl http://localhost:8080  # Staging
curl http://localhost:9080  # Production
```

### Load Balancing
```bash
for i in {1..10}; do
  curl -s http://localhost:9080 && echo ""
done
```

### Auto-scaling Test
```bash
# Monitor HPA
watch kubectl get hpa --all-namespaces

# Generate load (new terminal)
kubectl run load-generator -i --tty --rm --image=busybox --restart=Never -- /bin/sh

# Inside pod:
while true; do wget -q -O- http://node-hostname-production.node-hostname.svc.cluster.local; done
```

### Health Checks
```bash
kubectl get pods -n node-hostname
kubectl describe pod <pod-name> -n node-hostname
kubectl logs -f <pod-name> -n node-hostname
```

---

## 🗑️ Cleanup

### Delete Everything
```bash
./scripts/cleanup.sh
```

### Delete Specific Deployment
```bash
# Staging
helm uninstall node-hostname-staging -n node-hostname-staging

# Production
helm uninstall node-hostname-production -n node-hostname
```

### Keep Cluster, Remove Apps
```bash
helm uninstall node-hostname-staging -n node-hostname-staging
helm uninstall node-hostname-production -n node-hostname
```

---

## 🐛 Troubleshooting

### Pods Not Starting
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Image Pull Errors
```bash
# Verify image in cluster
docker exec node-hostname-control-plane crictl images | grep node-hostname

# Ensure pullPolicy is IfNotPresent
cat helm/node-hostname/values-*.yaml | grep pullPolicy
```

### Port Already in Use
```bash
lsof -i :8080
lsof -i :9080

# Kill process or restart Docker Desktop
```

### HPA Not Working
```bash
# Check metrics-server (wait 2 min after deploy)
kubectl top nodes
kubectl top pods -n <namespace>
```

### Full Reset
```bash
./scripts/cleanup.sh
./scripts/create-cluster.sh
./scripts/deploy-local.sh staging
./scripts/deploy-local.sh production
```

---

## 📚 Resources

- **Kubernetes:** https://kubernetes.io/docs/
- **Kind:** https://kind.sigs.k8s.io/
- **Helm:** https://helm.sh/docs/
- **Base App:** https://github.com/cristiklein/node-hostname

---

## 👤 Author

**Vagner Martins**
- GitHub: [@vamartins](https://github.com/vamartins)
- Docker Hub: [vamartins](https://hub.docker.com/u/vamartins)

---

## 📝 License

MIT License
