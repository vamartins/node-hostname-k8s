#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="${1:-production}"
CLUSTER_NAME="${2:-node-hostname}"

echo -e "${BLUE}🚀 Deploying node-hostname to ${ENVIRONMENT}...${NC}"
echo ""

# Check if cluster exists
if ! kubectl cluster-info --context kind-${CLUSTER_NAME} &> /dev/null; then
    echo -e "${RED}❌ Cluster '${CLUSTER_NAME}' not found.${NC}"
    echo -e "${YELLOW}💡 Run './scripts/create-cluster.sh' first to create the cluster.${NC}"
    exit 1
fi

# Switch to the cluster context
kubectl config use-context kind-${CLUSTER_NAME}

# Install Helm if not present
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}📦 Helm not found. Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo -e "${GREEN}✅ Helm installed successfully${NC}"
fi

# Set environment-specific values
if [ "$ENVIRONMENT" == "staging" ]; then
    NAMESPACE="node-hostname-staging"
    IMAGE_TAG="develop"
    REPLICAS="2"
    NODE_PORT="30080"
    VALUES_FILE="./helm/node-hostname/values-local.yaml"
else
    NAMESPACE="node-hostname"
    IMAGE_TAG="latest"
    REPLICAS="3"
    NODE_PORT="31080"
    VALUES_FILE="./helm/node-hostname/values-local.yaml"
fi

echo -e "${BLUE}📝 Deployment configuration:${NC}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Namespace: ${NAMESPACE}"
echo "  Node Port: ${NODE_PORT}"
echo "  Image Tag: ${IMAGE_TAG}"
echo "  Replicas: ${REPLICAS}"
echo "  Values File: ${VALUES_FILE}"
echo ""

# Create namespace
echo -e "${BLUE}📦 Creating namespace...${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install NGINX Ingress Controller if not present
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo -e "${BLUE}📦 Installing NGINX Ingress Controller...${NC}"
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.service.nodePorts.http=31080 \
        --set controller.service.nodePorts.https=31443 \
        --wait \
        --timeout 5m
    
    echo -e "${GREEN}✅ NGINX Ingress Controller installed${NC}"
else
    echo -e "${GREEN}✅ NGINX Ingress Controller already installed${NC}"
fi

# Install cert-manager if not present (for self-signed certs)
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${BLUE}📦 Installing cert-manager...${NC}"
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --wait \
        --timeout 5m
    
    echo -e "${GREEN}✅ cert-manager installed${NC}"
else
    echo -e "${GREEN}✅ cert-manager already installed${NC}"
fi

# Wait for cert-manager to be ready
echo -e "${BLUE}⏳ Waiting for cert-manager to be ready...${NC}"
kubectl wait --namespace cert-manager \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/instance=cert-manager \
    --timeout=120s

# Create self-signed ClusterIssuer for local development
echo -e "${BLUE}🔐 Creating self-signed certificate issuer...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

# Build Docker image
echo -e "${BLUE}🐳 Building Docker image...${NC}"
cd "$(dirname "$0")/.."
docker build -t almevag/node-hostname:${IMAGE_TAG} .

# Load image into Kind cluster
echo -e "${BLUE}📥 Loading image into Kind cluster...${NC}"
kind load docker-image almevag/node-hostname:${IMAGE_TAG} --name ${CLUSTER_NAME}

# Verify image is loaded
echo -e "${BLUE}🔍 Verifying image in cluster...${NC}"
docker exec ${CLUSTER_NAME}-control-plane crictl images | grep node-hostname || true

# Deploy with Helm
echo -e "${BLUE}🚀 Deploying application with Helm...${NC}"
helm upgrade --install node-hostname-${ENVIRONMENT} ./helm/node-hostname \
    --namespace ${NAMESPACE} \
    --values ${VALUES_FILE} \
    --set image.tag=${IMAGE_TAG} \
    --set replicaCount=${REPLICAS} \
    --set service.nodePort=${NODE_PORT}

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Wait for pods to be ready (with better selector)
echo -e "${BLUE}⏳ Waiting for pods to be ready...${NC}"
kubectl wait --namespace ${NAMESPACE} \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=node-hostname \
    --timeout=300s || {
        echo -e "${YELLOW}⚠️  Timeout waiting for pods. Checking status...${NC}"
        kubectl get pods -n ${NAMESPACE}
        kubectl describe pod -n ${NAMESPACE} | tail -50
    }

# Display deployment status
echo ""
echo -e "${BLUE}📊 Deployment Status:${NC}"
kubectl get all -n ${NAMESPACE}
echo ""

# Get access information
# With Ingress enabled in values-local.yaml, access via localhost (Kind port mapping)
if [ "$ENVIRONMENT" == "staging" ]; then
    HTTP_ACCESS="http://localhost:8080"
else
    HTTP_ACCESS="http://localhost:9080"
fi

echo -e "${GREEN}🎉 Application deployed successfully!${NC}"
echo ""
echo -e "${BLUE}🌐 Access URL:${NC}"
echo "  HTTP: ${HTTP_ACCESS}"
echo ""
echo -e "${BLUE}🔧 Useful commands:${NC}"
echo "  View pods: kubectl get pods -n ${NAMESPACE}"
echo "  View logs: kubectl logs -f deployment/node-hostname-${ENVIRONMENT} -n ${NAMESPACE}"
echo "  View service: kubectl get svc -n ${NAMESPACE}"
echo "  View ingress: kubectl get ingress -n ${NAMESPACE}"
echo "  Test HTTP: curl ${HTTP_ACCESS}"
echo "  Test load balancing: for i in {1..20}; do curl -s ${HTTP_ACCESS}; done | sort | uniq -c"
echo ""

# Test the application
echo -e "${BLUE}🧪 Testing application...${NC}"
sleep 2
if curl -s -o /dev/null -w "%{http_code}" ${HTTP_ACCESS} | grep -q "200"; then
    echo -e "${GREEN}✅ HTTP endpoint is responding!${NC}"
    echo ""
    echo -e "${BLUE}Response:${NC}"
    curl -s ${HTTP_ACCESS}
    echo ""
    echo ""
    echo -e "${BLUE}Testing load balancing (5 requests):${NC}"
    for i in {1..5}; do curl -s ${HTTP_ACCESS}; echo ""; done
else
    echo -e "${YELLOW}⚠️  Application may still be starting up. Try accessing manually.${NC}"
fi

echo ""
echo -e "${GREEN}💡 Tip: Access via browser at ${HTTP_ACCESS} and refresh to see different pod hostnames!${NC}"