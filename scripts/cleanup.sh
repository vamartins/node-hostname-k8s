#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="${1:-node-hostname}"

echo -e "${YELLOW}⚠️  WARNING: This will delete the entire Kubernetes cluster and all resources!${NC}"
echo -e "${BLUE}Cluster name: ${CLUSTER_NAME}${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${BLUE}ℹ️  Cleanup cancelled.${NC}"
    exit 0
fi

# Check if cluster exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Cluster '${CLUSTER_NAME}' not found.${NC}"
    exit 0
fi

echo -e "${BLUE}🗑️  Deleting Kind cluster...${NC}"
kind delete cluster --name ${CLUSTER_NAME}

echo -e "${GREEN}✅ Cluster deleted successfully!${NC}"
echo ""
echo -e "${BLUE}ℹ️  To recreate the cluster, run:${NC}"
echo "   ./scripts/create-cluster.sh"
