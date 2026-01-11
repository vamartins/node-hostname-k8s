#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="${1:-node-hostname}"

echo -e "${BLUE}🚀 Creating Kubernetes Cluster with Kind...${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop first.${NC}"
    exit 1
fi

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}📦 Kind not found. Installing Kind...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install kind
        else
            echo -e "${YELLOW}Installing via binary...${NC}"
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    else
        # Linux
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    echo -e "${GREEN}✅ Kind installed successfully${NC}"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}📦 kubectl not found. Installing kubectl...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install kubectl
        else
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"
            chmod +x ./kubectl
            sudo mv ./kubectl /usr/local/bin/kubectl
        fi
    else
        # Linux
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
    fi
    echo -e "${GREEN}✅ kubectl installed successfully${NC}"
fi

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Cluster '${CLUSTER_NAME}' already exists.${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Deleting existing cluster...${NC}"
        kind delete cluster --name ${CLUSTER_NAME}
    else
        echo -e "${GREEN}✅ Using existing cluster${NC}"
        kubectl cluster-info --context kind-${CLUSTER_NAME}
        exit 0
    fi
fi

# Create Kind cluster configuration
cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  # Control plane node
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    # HTTP - Staging
    - containerPort: 30080
      hostPort: 8080
      protocol: TCP
    # HTTPS - Staging
    - containerPort: 30443
      hostPort: 8443
      protocol: TCP
    # HTTP - Production
    - containerPort: 31080
      hostPort: 9080
      protocol: TCP
    # HTTPS - Production
    - containerPort: 31443
      hostPort: 9443
      protocol: TCP
  # Worker node 1
  - role: worker
  # Worker node 2
  - role: worker
EOF

echo -e "${BLUE}📝 Cluster configuration:${NC}"
echo "  - 1 Control Plane"
echo "  - 2 Worker Nodes"
echo "  - Staging ports: 8080 (HTTP), 8443 (HTTPS)"
echo "  - Production ports: 9080 (HTTP), 9443 (HTTPS)"
echo ""

# Create the cluster
echo -e "${BLUE}🔧 Creating cluster (this may take a few minutes)...${NC}"
kind create cluster --config /tmp/kind-config.yaml

# Wait for cluster to be ready
echo -e "${BLUE}⏳ Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Display cluster info
echo ""
echo -e "${GREEN}✅ Cluster created successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Cluster Information:${NC}"
kubectl cluster-info --context kind-${CLUSTER_NAME}
echo ""
kubectl get nodes
echo ""

# Install metrics-server for HPA
echo -e "${BLUE}📊 Installing metrics-server for HPA...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server to work with Kind
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

echo -e "${BLUE}⏳ Waiting for metrics-server to be ready...${NC}"
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=120s || echo -e "${YELLOW}⚠️  Metrics-server may take a few more moments to be ready${NC}"

echo ""
echo -e "${GREEN}🎉 Cluster setup complete!${NC}"
echo ""
echo -e "${BLUE}📝 Quick reference:${NC}"
echo "  Cluster name: ${CLUSTER_NAME}"
echo "  Context: kind-${CLUSTER_NAME}"
echo "  Staging access: http://localhost:8080 (HTTP) | https://localhost:8443 (HTTPS)"
echo "  Production access: http://localhost:9080 (HTTP) | https://localhost:9443 (HTTPS)"
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Run the deploy script: ./scripts/deploy-local.sh"
echo "  2. Or use the CI/CD pipeline to deploy"
echo ""
echo -e "${BLUE}🔧 Useful commands:${NC}"
echo "  View cluster: kind get clusters"
echo "  Delete cluster: kind delete cluster --name ${CLUSTER_NAME}"
echo "  Switch context: kubectl config use-context kind-${CLUSTER_NAME}"
echo "  View nodes: kubectl get nodes"
echo ""

# Save cluster info
cat > /tmp/cluster-info.txt <<EOF
Cluster Name: ${CLUSTER_NAME}
Context: kind-${CLUSTER_NAME}
Created: $(date)

Access Points:
- Staging HTTP: http://localhost:8080
- Staging HTTPS: https://localhost:8443
- Production HTTP: http://localhost:9080
- Production HTTPS: https://localhost:9443

Nodes:
$(kubectl get nodes)
EOF

echo -e "${GREEN}✅ Cluster information saved to /tmp/cluster-info.txt${NC}"
